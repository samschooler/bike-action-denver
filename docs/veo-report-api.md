# Veo (VeoRide) improperly-parked-vehicle report API

Reverse-engineered from `veoride.zendesk.com` HAR (2026-06-30). Veo has **no public
REST API** for this — reports go through their **Zendesk Help Center** "submit a
request" form (`ticket_form_id = 24858990499988`, "A vehicle is parked where it
doesn't belong"). We replicate the exact 3-call browser flow.

Base host: `https://veoride.zendesk.com`

## Flow (3 calls, in order)

### 1. Get CSRF token
```
GET /hc/api/internal/csrf_token.json
```
Response:
```json
{"current_session":{"csrf_token":"hc:requests:client:...."}}
```
The token is also required as a cookie/session pair — the browser sends the Zendesk
`_help_center_session` cookie alongside. A fresh `GET /hc/en-us/requests/new?ticket_form_id=24858990499988`
establishes that session cookie; reuse the same cookie jar for all three calls.

### 2. Upload the photo → get an attachment token
```
POST /hc/en-us/request_uploads
Content-Type: multipart/form-data
X-Requested-With: XMLHttpRequest
(body: file part with the image, e.g. IMG.jpg / .heic)
```
Response:
```json
{
  "id": "fodCAzNwQ2Ks2OWdOptKubf3K",
  "file_name": "IMG_3622.HEIC",
  "url": "https://veoride.zendesk.com/attachments/token/eXccnSRxoNx9845JyYvYlAxqF/?name=IMG_3622.HEIC",
  "delete_url": "/hc/en-us/request_uploads/fodCAzNwQ2Ks2OWdOptKubf3K"
}
```
No CSRF needed on this call. Keep the whole JSON object — it goes verbatim into
`request[attachments][]` in step 3.

### 3. Submit the request
```
POST /hc/en-us/requests
Content-Type: application/x-www-form-urlencoded
```
Success = **HTTP 302** redirect to `/hc/en-us?return_to=%2Fhc%2Frequests`.

Body params (URL-encoded `request[...]` Rails-style):

| Param | Field | Example / notes |
|---|---|---|
| `utf8` | — | `✓` |
| `request[ticket_form_id]` | form id | `24858990499988` (constant) |
| `request[anonymous_requester_email]` | reporter email | `veo@sam.ink` |
| `request[subject]` | subject | `A vehicle is parked where it doesn't belong` (constant) |
| `request[description]` | free text | HTML, e.g. `<p>Bike parked on the sidewalk.</p>` |
| `request[description_mimetype]` | — | `text/html` |
| `request[custom_fields][360037999772]` | **Phone number** | `9526883507` (optional) |
| `request[custom_fields][360038000552]` | **Vehicle number** (under QR on handlebars) | free text; `(Didn't find it)` if unknown |
| `request[custom_fields][360029446151]` | **Vehicle type** | tag — see enum below |
| `request[custom_fields][360029389292]` | **Market** | tag — `den_denver_-_co` for Denver |
| `request[custom_fields][360038288771]` | **Full name** | `Sam Schooler` |
| `request[custom_fields][24861449413652]` | **Location** (address / cross streets) | `1300 Knox Ct, Denver, CO` |
| `request[custom_fields][24862782037652]` | **On private property / blocking walkway/street/parking?** | `illegal_parking_yes` \| `illegal_parking_no` |
| `request[custom_fields][24862819814548]` | **Blocking accessibility ramp?** | `block_ramp_yes` \| `block_ramp_no` |
| `request[attachments][]` | photo | the full JSON object returned by step 2 |
| `authenticity_token` | CSRF | value from step 1 |

## Enums

**Vehicle type** (`360029446151`): `apollo`, `bike`, `cosmo`, `e-bike`, `scooter`,
`trike`, `not_applicable`.

**On private property / blocking?** (`24862782037652`): `illegal_parking_yes` | `illegal_parking_no`.

**Blocking accessibility ramp?** (`24862819814548`): `block_ramp_yes` | `block_ramp_no`.

**Market** (`360029389292`): 60+ tags; Denver = `den_denver_-_co`. Full list in the HAR
`data-tagger` attributes if other cities are ever needed.

## Notes for the app
- This is a **different pipeline from the Denver 311 (PocketGov) flow** — no auth
  account, just an email + CSRF-protected form post. Much simpler.
- The two required yes/no fields and Vehicle number are the only fields not already
  captured by the existing report flow; everything else (photo, address, category)
  maps to data the app already produces.
- `e-bike`/`scooter`/`bike` vehicle-type maps naturally onto our ML category output.
