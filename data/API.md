# Denver PocketGov API — Reverse-Engineered Reference

Derived from a Firefox HAR capture of a user logging in and filing an **Illegal Parking** report (`REQ_ILLEGALPARKING`) on `www.denvergov.org/myprofile/home/cases/...` on 2026-04-20.

> **Security note:** the source HAR contains the captured user's plaintext password (posted to `SelfAsserted`) and both an `id_token` and `refresh_token`. Treat the file as a secret; rotate the password and do not commit the HAR. The tokens here are the user's, not API keys — any public service must let each user authenticate themselves or file anonymously.

---

## 1. System topology

| Hostname | Role |
|---|---|
| `www.denvergov.org` | Angular SPA. Only legal browser `Origin` — CORS on the API rejects all others. |
| `den.denvergov.org` | Main JSON API gateway. Paths: `/api/forms`, `/api/cases`, `/api/locations`, `/api/profiles`. |
| `denverresidents.b2clogin.com` | Azure AD B2C tenant for end-user auth. |
| `denvergov.org/api/utilities/applogs` | Front-end telemetry/logging sink (not needed to file a case). |
| Salesforce (server-side) | Downstream system. Cases are queued (`internalCaseStatus: "queuedForCRM"`) and pushed asynchronously. `sfIssueTemplateId` / `sfAnswerField` values reference Salesforce objects. |
| `prod.citibot.net` | Third-party chatbot widget, irrelevant to reporting. |

Important for a public app: the case API is open to `Origin: https://www.denvergov.org` only. A public client must proxy through a server, or spoof origin server-side.

---

## 2. Authentication — Azure AD B2C (OIDC, auth-code + PKCE)

Required for: `GET /api/profiles` (personalized case history). **Not required** for filing a case; the case endpoint accepts anonymous POSTs and uses the `contact.b2cId` field in the body as the user identifier.

### Endpoints (from OpenID discovery)

```
Tenant ID  : d8a278b1-6e69-429a-9e51-b2ba11f5703d
Tenant host: denverresidents.b2clogin.com
Policy     : B2C_1A_DenverGov_SignUpOrSignin
Client ID  : 684aed88-0697-479e-a565-f5ed62c6ea3f   (the SPA app registration)
Redirect   : https://www.denvergov.org/appservices/global-auth-handler/
MSAL       : msal.js.browser 2.36.0
```

Discovery: `GET https://denverresidents.b2clogin.com/{tenant}/b2c_1a_denvergov_signuporsignin/v2.0/.well-known/openid-configuration`

Key endpoints returned:
- `authorize`: `https://denverresidents.b2clogin.com/{tenant}/b2c_1a_denvergov_signuporsignin/oauth2/v2.0/authorize`
- `token`:     `https://denverresidents.b2clogin.com/{tenant}/b2c_1a_denvergov_signuporsignin/oauth2/v2.0/token`
- `jwks_uri`:  `https://denverresidents.b2clogin.com/{tenant}/b2c_1a_denvergov_signuporsignin/discovery/v2.0/keys`
- `logout`:    `.../oauth2/v2.0/logout`

### Grant: Authorization Code + PKCE

The SPA uses MSAL.js. Scope requested:

```
openid profile offline_access
https://graph.microsoft.com/User.Read
https://graph.microsoft.com/Directory.Read
```

### Login (SelfAsserted)

The B2C "unified.html" page posts credentials to `SelfAsserted`:

```
POST https://denverresidents.b2clogin.com/{tenant}/B2C_1A_DenverGov_SignUpOrSignin/SelfAsserted
     ?tx=StateProperties=<b64-json>&p=B2C_1A_DenverGov_SignUpOrSignin
Content-Type: application/x-www-form-urlencoded

request_type=RESPONSE
signInName=<email>
password=<password>
```

Response: `{"status":"200"}`. Control then redirects to the `authorize` endpoint with the embedded transaction ID, which issues an auth code; MSAL exchanges it at `token`.

### Token exchange

```
POST /oauth2/v2.0/token
Content-Type: application/x-www-form-urlencoded

client_id=684aed88-0697-479e-a565-f5ed62c6ea3f
grant_type=authorization_code
redirect_uri=https://www.denvergov.org/appservices/global-auth-handler/
scope=https://graph.microsoft.com/User.Read https://graph.microsoft.com/Directory.Read openid profile offline_access
code=<authorization_code>
code_verifier=<PKCE_verifier>
client_info=1
```

Response:

```json
{
  "id_token": "<JWT>",
  "token_type": "Bearer",
  "not_before": 1776739755,
  "client_info": "<b64>",
  "scope": "",
  "refresh_token": "<encrypted>",
  "refresh_token_expires_in": 86400
}
```

Note: the `id_token` is what gets sent as `Authorization: Bearer <id_token>` to `den.denvergov.org`. Access token is not used — the SPA treats the id_token as the API token (common B2C pattern when API and app share the same app registration).

### id_token claims (decoded)

```
iss      : https://denverresidents.b2clogin.com/{tenant}/v2.0/
aud      : 684aed88-0697-479e-a565-f5ed62c6ea3f     (client_id)
sub      : 4d7f021d-eb74-4d37-ba74-bef0df38f565     (B2C object id == contact.b2cId)
tid      : {tenant}
tfp      : B2C_1A_DenverGov_SignUpOrSignin          (the policy / trust framework policy)
name     : samschooler
given_name / family_name
emails   : ["pocketgov.com@accounts.sam.ink"]
ccd_uuid : "+qBRv0NyWHJLxFKHDJBc9GvgkKzKgH5IDosje9QbK4M="   (opaque CCD identifier)
pgov_sub : "204685:<email>"                         (PocketGov internal subject — numeric id prefix)
role     : []
exp / iat / auth_time / nonce
```

Token lifetime observed: `exp - iat = 3600` s (1h). Refresh token 24h.

---

## 3. Core API — `https://den.denvergov.org`

All JSON. CORS: only allows `Origin: https://www.denvergov.org`, credentials-allowed, methods `GET/PUT/POST/DELETE/OPTIONS`, headers `Content-Type, Authorization, Origin, Accept, Access-Control-Allow-Origin, Accept-Encoding, x-requested-with`.

Every response has `x-correlation-id: <uuid>` — useful for server-side logging and issue reports.

### 3.1 `GET /api/forms/apistatus` → 200

Health check. Response is a single word/short body. No auth.

### 3.2 `GET /api/forms/Menus` → 200, JSON array

Lists every report category ("menu"). No auth. Called on page load.

Each entry:

```ts
{
  id: number,                 // menu id — key referenced by everything else
  menuType: "Report an Issue" | "Ask Question",
  title: string,              // user-facing name, e.g. "Illegal Parking"
  caseType: string,           // enum, e.g. "REQ_ILLEGALPARKING"
  active: boolean,
  sfIssueTemplateId: string,  // Salesforce template id
  configuration: string,      // JSON string — see below
  menuQuestions: null         // always null here; fetched separately
}
```

`configuration` (after `JSON.parse`) looks like:

```json
{
  "contact":  { "anonymousAllowed": true | false },
  "locationRequired": true | false,
  "location": { "required": true, "disabledModes": ["coordinates","current-location"] },
  "helpfulLinks": [{ "url": "...", "description": "..." }],
  "comments":  { "required": true, "description": "HTML blurb" }
}
```

Full active list captured (id → caseType → title):

| id | caseType | title |
|---|---|---|
| 1 | REP_GRAFFITI | Graffiti |
| 2 | REP_POTHOLE | Pothole |
| 3 | REP_ANIMALCOMPLAINT | Animal Complaint |
| 4 | REP_WEED | Weeds & Vegetation |
| 6 | REP_NEIGHBOR | Neighborhood Issue |
| 7 | REQ_OTHER | Other |
| 8 | REQ_SNOWREMOVAL | Snow on Sidewalk |
| 9 | REP_ABANDONEDVEHICLE | Abandoned Vehicle |
| **10** | **REQ_ILLEGALPARKING** | **Illegal Parking** ← the target |
| 11 | REP_DMGDTREE | Damaged/Fallen Tree |
| 12 | REP_POLICE | Police: Non-emergency |
| 13 | REP_ENCAMPMENT | Encampment / Street Engagement |
| 14 | REP_FIREWORKS | Fireworks |
| 15 | REP_DUMPING | Illegal Dumping |
| 16–30 | ASK_QUESTION | various "Ask Question" topics |
| 31 | REP_MOBILITY | Shared Micromobility |
| 32 | REP_NOHEAT | No Heat / No Water / No Electricity |
| 34 | REP_MISSEDTRASH | Missed Trash Pickup |
| 35 | REP_SIDEWALK | Major Sidewalk Damage |
| 38 | REP_SANDREQUEST | Sand Request / Icy Road |
| 39 | REP_SIDEWALK | Damaged Curb/Gutter |

For **Illegal Parking** (menu id 10):

```json
{
  "contact": { "anonymousAllowed": true },
  "locationRequired": true,
  "location": { "required": true,
                "disabledModes": ["coordinates","current-location"] },
  "helpfulLinks": [
    { "url": ".../Parking-Division/Tickets-and-Towing/Parking-Ordinances",
      "description": "Parking Ordinances" },
    { "url": ".../Parking-Division/Tickets-and-Towing",
      "description": "Tickets and Towing" }
  ],
  "comments": { "required": true,
                "description": "Please describe the vehicle, and include make/model and type if possible." }
}
```

`disabledModes: ["coordinates","current-location"]` means the SPA forces users to type an address — they cannot drop a pin or use GPS. This is likely the single biggest UX wart the new app should fix.

### 3.3 `GET /api/forms/MenuQuestions` (OData-flavoured)

Dynamic form questions. The API speaks a subset of OData — the SPA sends:

```
GET /api/forms/MenuQuestions
    ?$filter=MenuId eq 10 AND Active
    &$orderby=Group ASC, Order ASC
```

Response is a JSON array of questions. Schema:

```ts
{
  id: number,                 // question id, used as caseQuestions[].id in POST
  menuId: number,             // parent menu
  question: string,           // label shown to user
  questionType: "radioGroup" | "textInput" | ... ,
  active: boolean,
  required: boolean,
  order: number,              // within a group
  group: string,              // ordered rendering group ("1","2",...)
  options: string,            // JSON string describing widget
  sfAnswerField: string,      // Salesforce column, e.g. "Issue_Question_1__c"
  menu: null
}
```

`options` varies by `questionType`:
- `radioGroup` → `{"choices":[{"label":"...","value":"..."}], "allowEmptySelection": false}`
- `textInput`  → `{"maxLength":10}` or `{"inputType":"date"}`

**Captured questions for Illegal Parking (menuId=10):**

| id | order/group | required | type | question | options |
|---|---|---|---|---|---|
| 20 | 0 / "1" | ✓ | radioGroup | Is the vehicle blocking a driveway? | Yes / No |
| 21 | 1 / "2" | — | textInput (date) | How long has vehicle been parked? | — |
| 22 | 2 / "3" | ✓ | textInput | Plate Number | maxLength 10 |
| 46 | 3 / "3" | ✓ | textInput | Plate State | maxLength 2 |
| 47 | 4 / "4" | ✓ | textInput | Color, make & style of vehicle | maxLength 100 |
| 48 | 5 / "4" | ✓ | radioGroup | Type of vehicle | Coupe / Sedan / Utility / Pickup / SUV / Van / Other |
| 49 | 6 / "5" | ✓ | radioGroup | Location of vehicle | Private Property / Public Property |

Each `sfAnswerField` maps onto a Salesforce custom field `Issue_Question_N__c`.

### 3.4 `GET /api/locations/Addresses/search/denver/{query}` → 200/204

Type-ahead address lookup. **Text-prefix search on `addressLine1` only — NOT a reverse-geocoder.** Verified empirically (probes on 2026-04-20):

| Probe | Top match | Notes |
|---|---|---|
| `39.73627,-105.0215005` (near 2744 W 13th Ave) | `39 W 1st Ave` | Matched leading digits "39" as street number — ignored lat/lng semantics |
| `40.0,-105.0` | `40 W 2nd Ave` | Matched "40" |
| `(39.73627,-105.02150)` | `39 W 1st Ave` | Parens don't help |
| `lat:39.736,lng:-105.021` | `39 W 1st Ave` | Prefix qualifiers don't help |
| `2744` (number alone) | `204 No Content` | Needs address-like text; bare number is rejected |

Implication: to go from pin → `addressId`, the public app must pipe through an **external reverse-geocoder** first (Mapbox / Google / Nominatim / US Census), then feed the resulting "NNN Street Name, Denver, CO" into this endpoint.

No auth. `{query}` is URL-encoded, typed progressively. Semantics observed:

| Status | Meaning |
|---|---|
| `200` | Candidate(s) found — JSON array |
| `204` | Query valid but no match (empty body) |
| `0`   | Request aborted mid-typing (browser cancelled) |

Response array element:

```ts
{
  addressId: number,        // use this as location.address.id in POST /api/cases
  addressLine1: string,     // "2744 W 13th Ave"
  city: string,             // "Denver"
  state: string,            // "CO"
  zip: string,              // "80204-2882" or "-" if unknown
  latitude: number,
  longitude: number,
  schedule: null,
  isValidated: boolean,
  isInDenver: boolean,
  lastUpdated: string,      // ISO8601
  userLocations: null,
  id: "00000000-0000-0000-0000-000000000000"
}
```

Second hop: Google Maps JS (`maps.googleapis.com/.../GetViewportInfo`) renders the picked address on a map. Not part of Denver's API surface.

### 3.5 `GET /api/profiles` → 200

Signed-in user's resident profile. **Requires** `Authorization: Bearer <id_token>`.

```json
{
  "id": "<b2cId = id_token.sub>",
  "firstName": "Sam",
  "lastName": "Schooler",
  "displayName": "samschooler",
  "email": "...",
  "profileType": "resident",
  "userComponentMeta": null,
  "phone": null,
  "preferredLanguage": null,
  "identities": [
    { "issuer":"denverresidents.onmicrosoft.com",
      "issuerAssignedId":"<email>",
      "signInType":"emailAddress" },
    { "issuer":"denverresidents.onmicrosoft.com",
      "issuerAssignedId":"<b2cId>@denverresidents.onmicrosoft.com",
      "signInType":"userPrincipalName" }
  ],
  "isDeleted": false,
  "isFromCache": false
}
```

A subsequent `GET /api/profiles/apistatus` is a health ping after hydration.

Use profile fields to prefill the `contact` block on case submit.

### 3.6 Attachment upload — two steps

**Step A** (optional pre-check): `GET /api/cases/attachments/thumbnail/{guid}` — SPA probes the thumbnail endpoint with a client-generated GUID; returns 404 until a file is uploaded. This is purely to establish placeholder state.

**Step B — upload:**

```
POST https://den.denvergov.org/api/cases/attachments/{attachmentId}
Content-Type: multipart/form-data; boundary=...

file=<binary>        (form field "file", original filename preserved)
```

- `{attachmentId}` is a **client-generated UUID v4**. The SPA invents it before upload and reuses it when creating the case.
- **No `Authorization` header** on upload — fully anonymous.
- Max observed body size: 1 MB (1048576 bytes). Could be server-enforced or browser-enforced — untested.
- Accepts raw phone-camera formats (captured upload was `image/heic`).

Response `201`:

```json
{
  "caseHistoryId": 0,
  "caseNumber": null,
  "mimeType": "image/heic",
  "pathToFiles": "2026/4/20/ec3e203a-149e-4fe5-9e2e-528b227c5f2a",
  "created": "2026-04-21T02:50:37.679Z",
  "id": "ec3e203a-149e-4fe5-9e2e-528b227c5f2a"
}
```

Thumbnail is then served from `GET /api/cases/attachments/thumbnail/{guid}` — no auth, cacheable.

> Only one `attachmentId` appears in the case body — the flow as captured supports **one attachment per case**. If the UI allows multiple, each would need its own GUID; the case schema would need a list field instead of the singular `attachmentId`. Not verified.

### 3.7 `POST /api/cases` → 201  ← the target

**No Authorization header.** Contact identity comes from the body (`contact.b2cId`, `contact.email`, …). `anonymous: true` is accepted when the menu's `configuration.contact.anonymousAllowed` is true.

```
POST https://den.denvergov.org/api/cases
Content-Type: application/json
Origin:       https://www.denvergov.org
Referer:      https://www.denvergov.org/
```

**Request body** (captured, verbatim shape):

```json
{
  "comments": "Parked in bike lane",
  "attachmentId": "ec3e203a-149e-4fe5-9e2e-528b227c5f2a",

  "caseType": {
    "menuType": "Report an Issue",
    "menuId": 10,
    "title": "Illegal Parking",
    "name": "REQ_ILLEGALPARKING",
    "sfIssueTemplateId": "a3Gi000000375ai",
    "caseQuestions": [
      { "id": 20, "question": "Is the vehicle blocking a driveway?",
        "sfAnswerField": "Issue_Question_1__c", "answer": "No" },
      { "id": 21, "question": "How long has vehicle been parked?",
        "sfAnswerField": "Issue_Question_2__c", "answer": "2026-04-20" },
      { "id": 22, "question": "Plate Number",
        "sfAnswerField": "Issue_Question_3__c", "answer": "DHKQ98" },
      { "id": 46, "question": "Plate State",
        "sfAnswerField": "Issue_Question_4__c", "answer": "CO" },
      { "id": 47, "question": "Color, make & style of vehicle",
        "sfAnswerField": "Issue_Question_5__c", "answer": "Blue BMW" },
      { "id": 48, "question": "Type of vehicle",
        "sfAnswerField": "Issue_Question_6__c", "answer": "Sedan (4 Door)" },
      { "id": 49, "question": "Location of vehicle",
        "sfAnswerField": "Issue_Question_7__c", "answer": "Public Property" }
    ]
  },

  "contact": {
    "b2cId": "4d7f021d-eb74-4d37-ba74-bef0df38f565",
    "firstName": "Sam",
    "lastName":  "Schooler",
    "email":     "pocketgov.com@accounts.sam.ink",
    "phone":     null,
    "anonymous": false,
    "languagePreference": "en"
  },

  "location": {
    "address": {
      "id": 70424,                       // addressId from /api/locations/Addresses/search
      "streetAddress": "2744 W 13th Ave",
      "city": "Denver",
      "state": "CO",
      "zip": "-"
    },
    "coordinates": { "latitude": 39.73627364, "longitude": -105.0215005 },
    "addressFromReverseGeocode": false
  }
}
```

Notes on shape:
- `caseType` is fully denormalised — client re-sends `menuType`/`title`/`name`/`sfIssueTemplateId` rather than just sending `menuId`. Server seems to trust them (not verified). A public client can probably get away with just `menuId` + the `caseQuestions` array, but safest path is to fetch `/api/forms/Menus`, carry the fields, and echo them back.
- `attachmentId` is optional — omit or set `null` if no photo.
- `contact.anonymous=true` omits identity. `anonymousId` in the response becomes non-zero in that case (observed `00000000-...` because user was signed in).
- **Address vs coordinates — which is authoritative?** Both are sent. Evidence points to **address being primary**:
  - `address.id` (here `70424`) is a **Denver-internal primary key** from `/api/locations/Addresses/search` — the kind of id a downstream routing/dispatch system would key off.
  - The captured coordinates came *from* the address-search response, not from user input. So the flow was `address → addressId → coords-as-byproduct`.
  - The `addressFromReverseGeocode` flag only makes sense if there's a second mode (`true` = "I picked coords, address was synthesized"). Its existence implies the server treats the two modes differently.
  - Menu 10 has `configuration.location.disabledModes = ["coordinates","current-location"]` — the official SPA **forbids** coord-first entry for parking. The API field is still present in the body, but no coord-first case submit was observed in this capture.
  - Unverified: whether `address.id` is validated server-side, or whether submitting `coordinates` alone (with a synthesized/empty `address`) is accepted.
  - **Recommended path for a public app**: if the user drops a pin, reverse-geocode the coords to a Denver `addressId` via `/api/locations/Addresses/search/denver/{derived-line}`, then submit both — byte-for-byte matching the captured shape. Lowest risk of server-side rejection, and dispatch routing still works.
- Observed interstitial `sfIssueTemplateId` `a3Gi000000375ai` in the POST vs `a3Gi000000375ai` — the value in `/api/forms/Menus` was different (`a3Gi000000375ai` for menu id=10, but the Menus response actually carried a different template id for each menu; the client mirrors whatever `/Menus` gives it).

**Response 201:**

```json
{
  "inputRecordId": 266859,
  "attachmentId":  "ec3e203a-149e-4fe5-9e2e-528b227c5f2a",
  "menuId": 10,
  "title": "Illegal Parking",
  "email": "pocketgov.com@accounts.sam.ink",
  "b2CId": "4d7f021d-eb74-4d37-ba74-bef0df38f565",
  "anonymousId": "00000000-0000-0000-0000-000000000000",
  "created": "2026-04-21T02:52:30.094Z",
  "closed": null,
  "internalCaseStatus": "queuedForCRM",
  "caseStatus": "New",
  "caseId":     null,   // Salesforce case id — filled in later
  "caseNumber": null,   // Salesforce case number — filled in later
  "resolutionNotes": null,
  "sentStatus": "notSent",
  "sfError": null,
  "attempts": 0,
  "inputRecord": {
    "userInput": "<stringified version of the request body, PascalCased>",
    "salesForceInput": null,
    "created": "...",
    "caseHistory": null,
    "id": 266859
  },
  "id": 266869        // ← primary key; the SPA navigates to /myprofile/home/cases/266869
}
```

Key fields for client UX:
- `id` (here `266869`) is the Denver case PK — show this to the user immediately and use it in any case-detail links.
- `caseNumber` / `caseId` populate later as a background worker pushes the case to Salesforce. A public app should poll the case endpoint or just display `internalCaseStatus` / `sentStatus` until they flip.
- `sentStatus` transitions: `notSent` → (presumably `sent` / `failed`). `attempts` counter suggests retry logic.

### 3.8 Case fetch (not observed — inferred)

The page URL is `/myprofile/home/cases/266869`. That implies `GET /api/cases/{id}` exists, likely returning the same shape as the POST response, progressively enriched. Unverified in this HAR.

---

## 4. End-to-end flow — filing an Illegal Parking report

```
┌─────────────────────────────────────────────────────────────────────┐
│ (optional) Sign in via Azure B2C                                    │
│   GET  /.well-known/openid-configuration                            │
│   POST /SelfAsserted              (email+password)                  │
│   → redirect to /authorize        (gets auth code)                  │
│   POST /oauth2/v2.0/token         (code + PKCE verifier)            │
│   ← id_token, refresh_token                                         │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Bootstrap                                                           │
│   GET  /api/forms/Menus                  (full catalogue)           │
│   GET  /api/profiles          [auth]    (prefill contact)           │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Pick "Illegal Parking" (menuId=10)                                  │
│   GET  /api/forms/MenuQuestions?$filter=MenuId eq 10 AND Active     │
│        &$orderby=Group ASC, Order ASC                               │
│        → array of questions, rendered as dynamic form               │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ User fills form                                                     │
│                                                                     │
│   (a) Pick address — type-ahead                                     │
│        GET /api/locations/Addresses/search/denver/{query}           │
│        → { addressId, lat, lon, ... }                               │
│                                                                     │
│   (b) Attach photo                                                  │
│        let id = crypto.randomUUID()                                 │
│        POST /api/cases/attachments/{id}  (multipart form-data)      │
│        → { id, mimeType, pathToFiles, ... }                         │
│                                                                     │
│   (c) Answer the 7 caseQuestions                                    │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Submit the case                                                     │
│   POST /api/cases                                                   │
│     body: { comments, attachmentId, caseType{menuId,caseQuestions}, │
│             contact{b2cId,email,firstName,...,anonymous},           │
│             location{address{id},coordinates} }                     │
│   → 201 { id: 266869, internalCaseStatus: "queuedForCRM", ... }     │
│                                                                     │
│   (background: backend pushes to Salesforce; caseNumber fills in)   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 5. Implications for a public bike-lane reporting app

### What's nice about the Denver API
- POST `/api/cases` accepts **anonymous** submissions (`anonymous: true`) for Illegal Parking. No auth needed to file.
- Attachment upload is unauthenticated and pre-issues its own URL (client-side UUID), so it's straightforward to pipeline.
- Address search is fast and returns lat/lng directly.

### What will bite a public client
1. **CORS lockdown.** `Access-Control-Allow-Origin: https://www.denvergov.org` only. A browser SPA on another domain cannot call this API directly — **you need a server-side proxy** (or server-to-server from your backend). The API has no published keys; it trusts origin.
2. **The Menus endpoint is the source of truth for catalogue + `sfIssueTemplateId`.** Re-fetch on startup; do not hard-code `sfIssueTemplateId` — it's rotated per Salesforce configuration.
3. **`disabledModes: ["coordinates","current-location"]` for Illegal Parking** means the official site forces street-typed addresses. The server accepts `coordinates` in the body anyway (captured submission included them), so a better app can let users drop a pin and reverse-geocode to Denver's address dataset via `/api/locations/Addresses/search/denver/{reverse-looked-up-address}` — use the returned `addressId` + pass the real coordinates. This is likely a major UX win over the official app.
4. **Single photo per case** (observed). If you want multi-photo, concatenate into the server-side proxy and upload them against one case, or lobby for a schema change.
5. **Anonymous is nicer than auth** for a public app — skip B2C entirely unless your product wants to show "my reports". Anonymous submissions still route into Salesforce.
6. **Rate limiting / abuse controls** are unknown. CAPTCHA/WAF likely live in front of `den.denvergov.org` (AWSALB cookies in responses) — expect to hit them from a bot.
7. **No published SLA / change notice.** Treat this API as undocumented and unstable. Pin schema assertions in your proxy and fail loudly on drift.

### Zero-typing UX: use photo EXIF to auto-locate

iPhone photos of the parked vehicle carry GPS EXIF. Verified against the captured HEIC (`IMG_3239.HEIC`, iPhone 15 Pro):

```
GPSLatitude/Longitude    → decimal coords (± GPSHPositioningError, typically 10–15 m)
GPSImgDirection          → compass bearing the camera was facing
GPSAltitude              → elevation
DateTimeOriginal / GPSTimeStamp → when the photo was taken (≠ submit time)
Make / Model / Software  → device identification
```

Pipeline: **photo upload → extract EXIF → Nominatim reverse-geocode → Denver address search → `addressId`**. Tested end-to-end.

Caveats:
- **Photo GPS ≠ incident location.** In the captured session, the EXIF coords and the filed case location were ~53 m apart — the photographer stood on the sidewalk while the car was a few houses down. Present the EXIF coords as a suggested pin, let the user drag it.
- **Normalise Nominatim's "Avenue"/"Street"/"West" to "Ave"/"St"/"W"** before handing to Denver's search. The endpoint is prefix-based and tolerant, but canonical forms reduce false matches.
- **Heading (`GPSImgDirection`)** can auto-fill "what side of the street" info in the vehicle-location question.
- **Timestamp** could prefill the "how long has vehicle been parked" question's initial value (the captured report used the filing date).
- **Fallback if EXIF is stripped/missing.** iOS' share sheet and some messaging apps remove EXIF. If GPS is absent, fall back to a map-picker — do not block the report.
- **Don't forward EXIF to Denver.** Their endpoint takes a plain street string; strip metadata from the photo before upload if you don't want to leak user location metadata into Salesforce.

### Minimal server-proxy contract to build first

A tiny Node/Go/Rust service that:

```
POST /report-parking
  body: {
    comments, plate, plateState, color, type, blockingDriveway,
    parkedDuration, privateOrPublic,
    lat, lon, address?,   // either lat/lon (reverse-geocode here) or typed address
    photoBytes?           // base64 or multipart
  }

  → 1. (optional) reverse-geocode lat/lon via /api/locations/Addresses/search
    2. (optional) upload photo: crypto.randomUUID() + POST /api/cases/attachments/{id}
    3. POST /api/cases  with the canonical shape above
    4. return { denverCaseId, status }
```

Keep the upstream request shape exactly as captured — matching the SPA's payload byte-for-byte minimises the chance of server-side validation surprises.

---

## 6. Evidence pointers (HAR entries)

| Subject | HAR entry selector |
|---|---|
| OIDC discovery | `.log.entries[] \| select(.request.url \| test("openid-configuration"))` |
| Password login | `.log.entries[] \| select(.request.url \| test("SelfAsserted"))` |
| Token exchange | `.log.entries[] \| select(.request.url \| test("oauth2/v2.0/token"))` |
| Menu catalogue | `.log.entries[] \| select(.request.url \| endswith("forms/Menus"))` |
| Dynamic questions | `.log.entries[] \| select(.request.url \| test("MenuQuestions"))` |
| Address search | `.log.entries[] \| select(.request.url \| test("locations/Addresses/search"))` |
| Profile (bearer) | `.log.entries[] \| select(.request.url == "https://den.denvergov.org/api/profiles")` |
| Attachment upload | `.log.entries[] \| select(.request.url \| test("cases/attachments/[^/]+$")) \| select(.request.method == "POST")` |
| **Case submit**   | `.log.entries[] \| select(.request.url == "https://den.denvergov.org/api/cases" and .request.method == "POST")` |
