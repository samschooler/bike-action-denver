# Veo scooter reporting — design

**Date:** 2026-06-30
**Status:** Approved (pending spec review)

## Goal

Add a second, independent reporting destination to Bike Action Denver: reporting
improperly parked **scooters/bikes** to **Veo (VeoRide)**. Veo has no public API —
reports go through their Zendesk Help Center form (see `docs/veo-report-api.md`).

**Hard requirement:** PocketGov (Denver 311) sign-in must **never** be a prerequisite
for reporting a scooter to Veo. The Veo flow is anonymous (email-based) and must be
fully usable while signed out.

## Non-goals

- No changes to the existing Denver 311 car-reporting flow beyond relocating the
  chooser/welcome banner (see Navigation).
- No server-side tracking of Veo tickets (anonymous submissions return only a 302).
- No car ML (plate detection, plate OCR, color, car classification) in the Veo flow.

## User-facing behavior

### Navigation / entry
The Report tab root becomes a new **`ReportHomeView`**:

```
Report tab (root = ReportHomeView)
├─ OnboardingBanner                     ← "Welcome to Bike Action" card (moved here)
└─ "What are you reporting?" chooser    ← renders BELOW the welcome card
   ├─ [ Car in a bike lane → Denver 311 ]  → pushes existing ReportView
   └─ [ Scooter or bike → Veo ]            → pushes new VeoReportView
```

- The chooser renders regardless of PocketGov auth state (it sits above any gate).
- `OnboardingBanner` moves out of `ReportView` into `ReportHomeView` so the welcome
  card shows once, above the chooser.
- Selecting "Car" pushes the existing `ReportView` (unchanged; keeps its own sign-in
  gate internally). Selecting "Scooter/bike" pushes `VeoReportView`.
- History tab stays 311-only. Veo reporting is **fire-and-forget**: a success
  confirmation screen, no local record.

### Veo report form (`VeoReportView`)
Fields, in order:
1. **Photo** — reuse `PhotoCard` / `CameraPicker` / `PhotoSourcePanel`.
2. **Location** — auto-filled from EXIF GPS via **`CLGeocoder` reverse-geocoding**
   (Apple, not Denver's address-search API) to a display string
   (e.g. `1300 Knox Ct, Denver, CO`); editable. If the photo has no GPS, the user
   enters the address manually. The existing `GeocodeService` (Denver-API-coupled) is
   **not** reused here; the Veo flow uses a small standalone `CLGeocoder` call.
3. **Vehicle type** — pill selector (`QuickPickRow`); default `Scooter`.
4. **Vehicle number** — text field with a trailing **scan button**. Scan supports
   both live camera QR/barcode scanning and scan-from-photo. Decoded payload is
   parsed to a vehicle number and shown for confirmation. Defaults to
   `(Didn't find it)` if left blank.
5. **On private property / blocking a walkway, street or parking spot?** — yes/no.
6. **Blocking an accessibility ramp?** — yes/no.
7. **Notes** — free text → sent as the HTML description.
8. **Submit** — reuse `SubmitButton`; disabled until the draft is submittable.

### Reporter identity
A **Veo reporter profile** (name, email, phone) is entered once in a new
**Settings → "Veo reporter"** section and reused for every report (editable there).
This section is independent of PocketGov auth — available signed in or out. If the
profile is unset when the user tries to submit, prompt them to fill it in Settings.

## Architecture

New code is isolated from the Denver 311 pipeline. Shared dependencies only:
`ExifService`, reverse-geocoding, `Multipart.swift`, and several `Views/Report/*`
subviews.

### Models (`Models/`)
- **`VeoReportDraft`**: `photoURL`, `coordinates`, `addressText`, `vehicleType:
  VeoVehicleType`, `vehicleNumber: String`, `onPrivateOrBlocking: Bool?`,
  `blockingRamp: Bool?`, `notes: String?`, `observedAt: Date?`.
  - `isSubmittable`: photo present AND `addressText` non-empty AND `vehicleType` set
    AND `onPrivateOrBlocking != nil` AND `blockingRamp != nil`. (Vehicle number is
    optional — defaults to `(Didn't find it)`.)
- **`VeoVehicleType`** enum with wire tags:
  `bike` → `bike`, `eBike` → `e-bike`, `scooter` → `scooter`, `trike` → `trike`,
  `cosmo` → `cosmo`, `apollo` → `apollo`, `notApplicable` → `not_applicable`.
  Default `scooter`.
- **`VeoProfile`**: `name`, `email`, `phone`. Persisted (UserDefaults; email/phone
  are not secrets). `isComplete` = name + email present.

### Services (`Services/VeoAPI/`)
- **`VeoEndpoints`** — base `https://veoride.zendesk.com`; constants:
  `ticketFormId = 24858990499988`, `market = den_denver_-_co`,
  `subject = "A vehicle is parked where it doesn't belong"`, and the custom-field IDs.
- **`VeoSubmitting`** protocol + **`VeoReportClient`** implementation:
  - Owns a `URLSession` with its own `HTTPCookieStorage` so the
    `_help_center_session` cookie persists across the 3 calls.
  - `fetchCSRFToken() async throws -> String` — `GET /hc/api/internal/csrf_token.json`
    (also establishes the session cookie).
  - `uploadAttachment(filename:mimeType:data:) async throws -> VeoAttachment` —
    `POST /hc/en-us/request_uploads` (multipart, reuses `Multipart.swift`,
    `X-Requested-With: XMLHttpRequest`). Returns the decoded attachment JSON.
  - `submitRequest(_ submission: VeoSubmission) async throws` — `POST /hc/en-us/requests`
    (form-urlencoded). **HTTP 302 = success**; any other status throws.
  - `VeoAttachment` = the JSON object from the upload (`id`, `file_name`, `url`,
    `delete_url`), re-encoded verbatim into `request[attachments][]`.
- **No reference to `AuthService` anywhere in `Services/VeoAPI/`.**

### Barcode scanning (`Services/VeoAPI/` or `Views/Veo/`)
- **`VeoCodeScanner`**:
  - Live: `AVCaptureSession` + `AVCaptureMetadataOutput` (QR + common 1D/2D types),
    wrapped in a SwiftUI `UIViewControllerRepresentable`.
  - From photo: `VNDetectBarcodesRequest` on a picked image.
  - `parseVehicleNumber(from payload: String) -> String`: if payload is a URL, extract
    the vehicle id (path/query); otherwise return the trimmed raw string. Raw value is
    surfaced in the UI for user confirmation before it fills the field.

### ViewModel (`ViewModels/`)
- **`VeoReportViewModel`** (`@MainActor @Observable`):
  - Deps injected: `ExifService`, geocoder, `VeoSubmitting`, `VeoProfile` store.
    **No `AuthService`.**
  - `load(photoURL:)` — reset draft, read EXIF (coords + observedAt), reverse-geocode
    to `addressText`.
  - `submit()` — guard `VeoProfile.isComplete` (else surface "set up Veo profile"),
    then `fetchCSRFToken` → `uploadAttachment` → build `VeoSubmission` → `submitRequest`
    → set success state, reset draft. Exposes `isSubmitting`, `lastError`, success flag.

### Views (`Views/Veo/`)
- **`ReportHomeView`** — new Report tab root: `OnboardingBanner` + chooser cards +
  `NavigationLink`s to `ReportView` and `VeoReportView`. Settings gear stays in toolbar.
- **`VeoReportView`** — the form described above; reuses `PhotoCard`, `CameraPicker`,
  `PhotoSourcePanel`, `FieldRow`, `QuickPickRow`, `SubmitButton`; adds the
  vehicle-number-with-scan row, two yes/no toggles, notes, and a success view.
- **Settings** — add a "Veo reporter" section bound to `VeoProfile`.
- `OnboardingBanner` removed from `ReportView` (now shown by `ReportHomeView`).

### DI (`App/AppContainers.swift`)
Register `VeoReportClient`, a `VeoProfile` store, and a `VeoReportViewModel` factory.

## Data flow (Veo submit)

1. User picks photo → `load`: EXIF → coords/observedAt; reverse-geocode → `addressText`.
2. User fills vehicle type, vehicle number (type or scan), the two yes/no answers, notes.
3. Submit:
   a. `GET csrf_token.json` (session cookie established) → token.
   b. `POST request_uploads` (multipart photo) → `VeoAttachment`.
   c. `POST requests` (form-urlencoded: `ticket_form_id`, `anonymous_requester_email`
      = profile email, `subject`, `description` = `<p>notes</p>`,
      `description_mimetype=text/html`, phone (`360037999772`), vehicle number
      (`360038000552`), vehicle type tag (`360029446151`), market (`360029389292`),
      full name (`360038288771`), location (`24861449413652`),
      illegal-parking tag (`24862782037652`), block-ramp tag (`24862819814548`),
      `attachments[]` = attachment JSON, `authenticity_token`) → **expect 302**.
   d. Success screen; reset draft. Fire-and-forget (no persistence).

## Error handling

- Submit disabled until `isSubmittable`.
- Missing EXIF GPS → manual address entry (address field editable).
- Missing/incomplete Veo profile → prompt to complete it in Settings; block submit.
- Non-302 response or network error → inline error message; draft preserved for retry.
- Camera permission denied for live scan → fall back to scan-from-photo / manual entry.

## Testing (TDD)

- **Form-body encoding**: build a `VeoSubmission` from a known draft/profile and assert
  the urlencoded body matches the HAR field-for-field (custom-field IDs, enum tags,
  yes/no tags, constants).
- **`VeoReportClient`** against a stubbed `URLProtocol`: verify the 3-call sequence,
  cookie reuse across calls, 302-as-success, and error on non-302.
- **Barcode parsing**: `parseVehicleNumber` over URL and raw-string payloads.
- **`VeoReportDraft.isSubmittable`** logic.
- **Auth-isolation regression test**: a Veo report is buildable and submittable with
  `auth = nil` / signed out — guards against reintroducing a PocketGov gate.

## Open questions

None outstanding.
