# Bike Lanes — Design Spec

**Date:** 2026-04-20
**Scope:** v0.1 (iOS, public App Store)
**Companion artifacts:**
- `data/API.md` — reverse-engineered Denver PocketGov API
- Paper file "Bike Lanes" — artboards: *Scope Map*, *Approaches*, *ReportView — default*

---

## 1. Problem

Denver's official civic-reporting SPA (`denvergov.org/myprofile/home/cases/...`) routes illegal-parking reports to a Salesforce-backed 311 queue. Filing one requires ~7 fields of manual data entry, forces typed addresses (GPS and pin-drop are explicitly disabled for parking reports), and buries the flow inside a multi-step wizard.

The goal is a one-photo iOS app that lets a resident report a car parked in a bike lane in under ten seconds, by replacing all the manual steps with on-device ML and EXIF extraction.

## 2. What we're building (v0.1)

A native SwiftUI iOS app that:

1. Accepts a photo (camera or library picker).
2. Runs on-device pipelines that auto-fill every field Denver's API requires.
3. Presents a single-page review with tap-to-edit on any field.
4. Submits anonymously to Denver's case endpoint with the photo as attachment.
5. Stores a local history of submitted cases.

Out of scope for v0.1 (see §12 for the deferred list): sign-in, cross-platform, case-status polling, other case types, server proxy.

## 3. Key decisions

| Decision | Choice | Reasoning |
|---|---|---|
| Platform | iOS only, SwiftUI | Every "magic" feature is a direct framework call; Android doubles the ML work for marginal v0.1 value. |
| Distribution | Public App Store | User wants public use, not personal-only. |
| Backend | None (direct-to-Denver) | iOS doesn't enforce CORS. Denver API accepts anonymous cases. |
| Auth | Anonymous (`contact.anonymous=true`) | Denver accepts it for `REQ_ILLEGALPARKING`. Avoids Azure B2C integration. |
| Reverse geocoder | `CLGeocoder` | Free, keyless, on-device caching, no rate-limit policy to navigate. |
| Address resolver | Denver `/api/locations/Addresses/search` | Only way to obtain the `addressId` Denver needs. |
| UX pattern | A + C blend | Full-auto default, inline tap-to-edit. Single scrollable page. |
| History | Local SwiftData store | No account, no sync. |
| Third-party deps | None | Clean privacy label, smaller attack surface. |

## 4. Architecture

### 4.1 Layering

```
┌────────────────────────────────────────┐
│ Views (SwiftUI)                        │
│ ReportView · HistoryView · CaseDetail  │
│ SettingsView · Edit sheets             │
└──────────────┬─────────────────────────┘
               │
┌──────────────▼─────────────────────────┐
│ ViewModels (@Observable)               │
│ ReportViewModel · HistoryViewModel     │
└──────────────┬─────────────────────────┘
               │
┌──────────────▼─────────────────────────┐
│ Services                               │
│ PhotoService · ExifService             │
│ GeocodeService · PlateOCRService       │
│ VehicleDetector · VehicleClassifier    │
│ ColorService · DenverAPI               │
│ CaseRepository                         │
└────────────────────────────────────────┘
```

**Dependency rule:** views depend on view-models; view-models depend on services; services do not depend on each other, with the deliberate exception of `GeocodeService` composing `CLGeocoder` and `DenverAPI.addressSearch` (one responsibility: "pin → `addressId`").

### 4.2 Service responsibilities

| Service | Responsibility | Apple frameworks |
|---|---|---|
| `PhotoService` | Camera + PhotosPicker, returns `UIImage` + original-file `URL` | `PhotosUI`, `AVFoundation` |
| `ExifService` | Parse GPS, timestamp, heading from image file | `ImageIO`, `CoreLocation` |
| `GeocodeService` | Reverse-geocode coords → `Placemark`; normalize → Denver `addressId` | `CoreLocation` |
| `PlateOCRService` | Recognize text within vehicle bbox; filter to plate shape | `Vision` |
| `VehicleDetector` | YOLOv11n Core ML; return bounding box of highest-confidence car | `CoreML`, `Vision` |
| `VehicleClassifier` | Core ML body-type classifier (Sedan/SUV/Pickup/Van/Coupe/Utility/Other) | `CoreML` |
| `ColorService` | Dominant color on car crop; map RGB → named color from Denver's vocabulary | `Vision`, `CoreImage` |
| `DenverAPI` | Typed client for `/api/forms/Menus`, `/api/forms/MenuQuestions`, `/api/locations/Addresses/search`, `/api/cases/attachments/{id}`, `/api/cases` | `URLSession` |
| `CaseRepository` | SwiftData store for history | `SwiftData` |

### 4.3 Bundled ML models

| Model | Size | Origin |
|---|---|---|
| YOLOv11n (car class from COCO) | ~6 MB | Ultralytics export → Core ML |
| Vehicle type classifier (7 classes) | ~15 MB | MobileNetV3 fine-tuned on CompCars body-type labels |

**Plate state detection in v0.1:** text-based only. `PlateOCRService` scans the plate region for the embossed state name (e.g. "COLORADO", "CALIFORNIA") and maps to a 2-letter code. No classifier ships in v0.1. A state-plate-design classifier is a v0.1.x enhancement if text-only recognition proves unreliable in testing.

Total bundle footprint: ~20 MB (detector + type classifier only). On-demand resources available if initial download size becomes an App Store concern later.

## 5. Screens

### 5.1 ReportView (primary)

Single scrollable screen. Top-to-bottom:

1. **Status bar + header.** "Report" title in Fraunces serif. ⊕ (gear) opens settings.
2. **Photo preview card.** Full-width, rounded, shows selected photo with the YOLO bounding box overlaid and a "CAR DETECTED · 0.94" confidence chip. Heading chip (e.g. "96% heading E") shown if EXIF has it. "Retake" pill in bottom-right.
3. **Form card** with rows (all tap-to-edit):
   - Where — address + `±Nm` accuracy caption
   - Plate — plate number + state (plate state shown as colored badge mirroring the real plate design)
   - Vehicle — `{color} {bodyType}, {doors}` + details caption ("Public property · not blocking driveway")
   - Observed — human-friendly timestamp from EXIF ("Today, 6:53 PM")
   - Notes — optional free text
4. **Submit button.** Primary green, sticky-feeling at bottom. Caption: "Files an anonymous case with Denver 311. No account required."
5. **Home indicator** spacer.

Visual reference: artboard *ReportView — default* in the Paper file.

### 5.2 Secondary screens

- **HistoryView** — vertically scrolling list. Each row: thumbnail, address, date, Denver case ID, sync-status dot.
- **CaseDetailView** — read-only rendering of a stored case. Same field layout as ReportView, no Edit affordances, plus a "View on Denvergov" link to `https://www.denvergov.org/myprofile/home/cases/{id}`.
- **SettingsView** — permissions summary (camera, photos, location), "Delete all local reports," privacy policy link, app version.
- **Edit sheets** — modal per field type: plate+state (single sheet with two inputs), vehicle (color + type + location-on-property + blocking-driveway in one sheet), address (address search with map preview), date/time, notes (plain text).
- **Degraded ReportView** — same screen; ML-unfilled rows render with red italics and "Add this" placeholders; if EXIF has no coords, a banner at the top: "No location in this photo — tap to add." Submit button stays enabled but greys until all required fields (per Denver's `MenuQuestions`) are filled.

## 6. Data models

```swift
struct ReportDraft {
    var photoURL: URL?
    var detectedCarBBox: CGRect?

    // Location
    var coordinates: CLLocationCoordinate2D?
    var horizontalAccuracy: Double?
    var heading: CLLocationDirection?
    var resolvedAddress: DenverAddress?   // carries addressId

    // Vehicle
    var plate: String?
    var plateState: USState?
    var plateConfidence: Double?
    var vehicleColor: DenverColor?
    var vehicleType: DenverVehicleType?   // enum matching Q48 options
    var locationOfVehicle: PropertyType?  // public / private
    var blockingDriveway: Bool?

    // Timing
    var observedAt: Date?

    // User notes
    var notes: String?
}

struct DenverAddress { addressId: Int; line1: String; city: String; state: String; zip: String; lat: Double; lng: Double }
enum DenverVehicleType: String { case coupe = "Coupe (2 door)", sedan = "Sedan (4 Door)", utility = "Utility Vehicle", pickup = "Pickup", suv = "SUV", van = "Van", other = "Other" }
enum PropertyType: String { case `public` = "Public Property", `private` = "Private Property" }

struct StoredCase {
    let localId: UUID
    let denverInputRecordId: Int    // response.id
    let denverCaseId: String?       // filled later (null at submit time)
    let denverCaseNumber: String?
    let submittedAt: Date
    let thumbnailPath: String
    let snapshot: ReportDraft       // frozen at submit
    let internalStatus: String      // initially "queuedForCRM"
}
```

## 7. Pipelines

### 7.1 On-photo-selected (parallel)

```
UIImage ┬─ ExifService.gps ────────→ CLGeocoder ───→ DenverAPI.addressSearch ──→ draft.resolvedAddress
        ├─ ExifService.timestamp ──────────────────────────────────────────────→ draft.observedAt
        └─ VehicleDetector → bbox → crop ┬─→ PlateOCRService ───────→ draft.plate, plateState
                                          ├─→ VehicleClassifier ─────→ draft.vehicleType
                                          └─→ ColorService ──────────→ draft.vehicleColor
```

Each leg writes into `draft` via its own setter; `ReportView` observes and re-renders fields progressively.

**Timing budget** on A17/A18 (target):
- Vehicle detection: ~50 ms
- Plate OCR on crop: ~150 ms
- Classifier + color: ~100 ms combined
- CLGeocoder: 800–1500 ms (network + Apple roundtrip)
- Denver address search: 200–400 ms

Net: ML pipeline completes in ~300 ms; location pipeline in ~1.5 s. User sees vehicle fields fill first, then location.

### 7.2 On-submit (sequential)

```
1. client generates UUID
2. POST /api/cases/attachments/{UUID}  (multipart; field "file"; Content-Type=image/heic|image/jpeg)
   → 201 { id: UUID, pathToFiles, mimeType }
3. POST /api/cases  (JSON body per §7.3)
   → 201 { id: denverInputRecordId, internalCaseStatus: "queuedForCRM", ... }
4. CaseRepository.save(StoredCase(...))
5. Navigate to CaseDetailView
```

### 7.3 Case submit body

See `data/API.md §3.7` for the captured canonical shape. The app constructs:

```json
{
  "comments": "<notes or empty string>",
  "attachmentId": "<UUID or null>",
  "caseType": {
    "menuType": "Report an Issue",
    "menuId": 10,
    "title": "Illegal Parking",
    "name": "REQ_ILLEGALPARKING",
    "sfIssueTemplateId": "<from /api/forms/Menus, menu.id=10>",
    "caseQuestions": [
      { "id": 20, "question": "Is the vehicle blocking a driveway?",   "sfAnswerField": "Issue_Question_1__c", "answer": "<Yes|No>" },
      { "id": 21, "question": "How long has vehicle been parked?",      "sfAnswerField": "Issue_Question_2__c", "answer": "<ISO date>" },
      { "id": 22, "question": "Plate Number",                           "sfAnswerField": "Issue_Question_3__c", "answer": "<plate>" },
      { "id": 46, "question": "Plate State",                            "sfAnswerField": "Issue_Question_4__c", "answer": "<2-letter>" },
      { "id": 47, "question": "Color, make & style of vehicle",         "sfAnswerField": "Issue_Question_5__c", "answer": "<free text>" },
      { "id": 48, "question": "Type of vehicle",                        "sfAnswerField": "Issue_Question_6__c", "answer": "<enum>" },
      { "id": 49, "question": "Location of vehicle",                    "sfAnswerField": "Issue_Question_7__c", "answer": "<Public|Private>" }
    ]
  },
  "contact": {
    "anonymous": true,
    "languagePreference": "en",
    "firstName": "",
    "lastName": "",
    "email": "",
    "phone": null
  },
  "location": {
    "address": {
      "id": <addressId>,
      "streetAddress": "<line1>",
      "city": "Denver",
      "state": "CO",
      "zip": "<zip>"
    },
    "coordinates": { "latitude": <exif lat>, "longitude": <exif lng> },
    "addressFromReverseGeocode": true
  }
}
```

The app caches `/api/forms/Menus` and `/api/forms/MenuQuestions?$filter=MenuId eq 10 AND Active` on first launch (or when older than 24 hours) to stay current with Denver-side changes to `sfIssueTemplateId` and question field mappings.

**Unverified: anonymous contact shape.** The HAR captured an authenticated submission with `b2cId`, `firstName`, `lastName`, `email`, `phone`, `anonymous: false`. Whether the server accepts `anonymous: true` with `firstName`/`lastName`/`email` as empty strings vs `null` vs omitted is untested. First implementation spike must probe all three variants against the live API and freeze the accepted shape in the `DenverAPI` client. Capture the working variant in an updated `data/API.md §3.7` note.

## 8. Error handling & edge cases

| Scenario | Behavior |
|---|---|
| Photo has no EXIF GPS | Banner: "No location in photo — tap to add." Edit row opens address picker. |
| CLGeocoder returns nothing | Skip it; show raw coordinates; address field shows "Enter address". |
| Denver address search → 204 | Present top candidates from CLGeocoder result; allow free-type. |
| Denver address search → 200 with multiple matches | Show picker with first 5 results. |
| Plate OCR low confidence (<0.7) | Row displays value in red italic with "Check this" subtext. |
| No car detected | Skip all vehicle ML; blank vehicle fields; do not block submit. |
| Photo attachment upload fails | Retry once w/ 500 ms backoff; on second failure, offer "submit without photo". |
| Case POST fails (network) | Retry up to 3 times with exponential backoff; draft persisted locally. |
| Case POST fails (4xx) | Show error with Denver `x-correlation-id`; "copy details" button. |
| App backgrounded mid-submit | `ReportDraft` persisted as `pending`; on relaunch, resume prompt. |
| User denies camera | Fall back to PhotosPicker. |
| User denies photo library | Offer camera-only mode with explainer. |
| User denies location (app location, not EXIF) | EXIF reads still work; explainer surfaces if the user later wants "report from my current location" (post-v0.1). |

## 9. Privacy

- All ML runs on-device.
- EXIF is read locally; photo is uploaded to Denver **unmodified** (Denver expects original file bytes). A Settings toggle "Strip metadata before upload" can be added later if demand emerges.
- `CLGeocoder` sends coordinates to Apple; disclosed in privacy policy.
- No third-party analytics or SDKs.
- Crash reports only via Apple TestFlight/App Store Connect (first-party).

**App Store privacy nutrition label:**
- Data collected: Photos (linked to user-submitted reports), Coarse Location (linked to reports).
- Data used for tracking: none.
- Data not collected: identifiers, contact info, usage data, diagnostics.

## 10. Testing

- **Unit**: `ExifService` (HEIC fixtures w/ and w/o GPS), `DenverAPI` request construction + response decode, plate-shape regex, address normalizer (Avenue→Ave, West→W, etc.).
- **Integration**: end-to-end submit against Denver's live API, gated by env var `BIKE_LANES_LIVE_API=1` so CI skips by default.
- **Snapshot**: `ReportView` in five states — default, degraded-no-GPS, degraded-no-car, submitting, submit-error.
- **Manual test matrix** pre-release:
  - Real iPhone photo with GPS → submit → confirm case appears in Denver
  - Photo with no GPS → manual address → submit
  - Photo with no car visible → manual form → submit
  - Airplane mode at submit time → retry → recovery
  - App killed during upload → resume
- **Golden fixtures**: captured `IMG_3239.HEIC` as the happy-path reference; synthetic no-GPS variant.

## 11. Dependencies & build

- Xcode 16+, Swift 6, iOS 17 deployment target (SwiftData, `@Observable`).
- No SPM packages. Every framework is first-party.
- Core ML models committed under `MLModels/` as `.mlpackage`.
- Build size budget: <50 MB over-the-air download.

## 12. Explicitly out of scope (deferred)

| Feature | Rationale for deferral |
|---|---|
| Azure B2C sign-in | Not needed; Denver accepts anonymous. Adds OIDC + token refresh complexity. |
| Case status polling | `GET /api/cases/{id}` behavior anonymously is unverified; likely auth-gated. |
| Android app | Would double ML pipeline work. Ship iOS first, validate demand. |
| Heatmap of reports | Requires backend + aggregation; build only if there's signal. |
| Make/model classifier | Long-tail accuracy drift; the form accepts free-text "color, make & style" already. |
| Other case types (graffiti, pothole, …) | Each needs its own MenuQuestions flow; focus on bike lanes first. |
| Push notifications on case update | Requires backend + APNs + Denver webhook (does not exist); infeasible v0.1. |
| Open data publishing | Out of scope for an app. |
| Server proxy | Unnecessary for iOS; revisit if Android is added. |

## 13. Open questions (resolved inline; none TBD)

- *Address vs coordinates authoritative?* Both sent; `address.id` is primary (Denver PK). Confirmed in `data/API.md §3.7`.
- *Photo required?* No — Denver's API accepts case without attachment. UX nudges toward photo but never blocks.
- *Review step before submit?* No separate review screen; the single-page form *is* the review. The primary button label is the review — "Submit to Denver."
- *Hold-to-submit vs tap?* Single tap, with a one-tap undo toast for 3 s after submit? — Deferred. Tap-submit for v0.1; Denver's API has no cancel endpoint anyway.

## 14. Success criteria for v0.1

- A user can go from "I see an illegally parked car" → opened app → photo taken → submitted → Denver case ID displayed, in under 10 seconds, with **zero typing** in the happy path.
- The app submits exactly the same payload shape as the official SPA, accepted on first POST.
- Clean App Store review on first submission.
- No third-party network calls except Apple's CLGeocoder.

## 15. References

- `data/API.md` — reverse-engineered Denver API (auth, endpoints, payload shapes, evidence pointers)
- `data/www.denvergov.org_Archive [26-04-20 20-52-49].har` — source HAR (contains user's plaintext password; treat as secret; do not commit)
- Paper file "Bike Lanes" — artboards *Scope Map*, *Approaches*, *ReportView — default*
