# Bike Action Denver

[**Download on the App Store →**](https://apps.apple.com/us/app/bike-action-denver/id6763114300)

A public iOS app that reports cars illegally parked in Denver bike lanes to Denver's PocketGov 311 system.

Photograph a vehicle parked in a bike lane, and the app auto-reads the license plate, identifies the car's color and category, and pulls the street address from the photo's GPS — then files a real Denver 311 case under your PocketGov account.

> Not affiliated with, endorsed by, or operated by the City and County of Denver. Uses Denver's public PocketGov 311 API.

## What it does

- **On-device ML pipeline.** YOLOv11n car detection, a plate-detection YOLO fine-tune, Apple Vision text recognition for plate OCR, and Core Image CIAreaAverage + HSV-bucketed color mapping — all run locally, no photos leave your phone until you tap Submit.
- **EXIF-driven location.** Reads the photo's GPS and heading, reverse-geocodes via CLGeocoder, and resolves to a Denver addressId via the `/api/locations/Addresses/search` endpoint.
- **Azure AD B2C sign-in.** WKWebView-based OAuth2 + PKCE flow against Denver's `denverresidents.b2clogin.com` tenant. Tokens live in the iOS Keychain; refresh tokens rotate on each refresh and silent SSO via the persisted B2C session cookie keeps the user signed in indefinitely between app launches.
- **Server-driven case history.** The History tab fetches `/api/cases?$top=100&$orderby=Created desc` for the signed-in user, with pull-to-refresh and per-case detail fetches. No local case state — the server is the source of truth.

## Repo layout

```
BikeLanes/                          # Xcode project (XcodeGen-managed)
├─ project.yml                      # source of truth for the Xcode project
├─ BikeLanes/                       # app target
│  ├─ App/                          # @main, DI containers
│  ├─ Models/                       # ReportDraft, RemoteCase, UserProfile, etc.
│  ├─ Services/                     # API clients, ML, EXIF, auth, keychain
│  │  ├─ Auth/                      # AuthService, PKCE, TokenStore, silent-SSO
│  │  └─ DenverAPI/                 # DenverAPIClient, CaseStatusService, DTOs
│  ├─ ViewModels/                   # ReportViewModel, HistoryViewModel (@Observable)
│  ├─ Views/
│  │  ├─ Report/                    # main photo + form flow
│  │  ├─ History/                   # cases list + detail
│  │  ├─ Edit/                      # per-field sheets (address, plate, …)
│  │  └─ Auth/                      # login WebView + sheet
│  └─ Resources/
│     ├─ Assets.xcassets/           # app icon + launch
│     └─ MLModels/                  # YOLOv11nCar.mlpackage, PlateDetectorModel.mlpackage
├─ BikeLanesTests/                  # XCTest unit + snapshot tests
└─ BikeLanesUITests/
```

## Building locally

Prerequisites:

- macOS 15 or later, Xcode 26
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- An Apple Developer account for code signing (free tier is fine for device install)

```sh
git clone https://github.com/<your-account>/bike-action-denver.git
cd bike-action-denver/BikeLanes
xcodegen generate
open BikeLanes.xcodeproj
```

In Xcode, select the BikeLanes target → Signing & Capabilities → set your Team. Then ⌘-R to run on a physical iPhone (the camera and Core ML paths don't work well in the simulator).

### Dry-run mode

Set the environment variable `BIKE_LANES_DRY_RUN=1` in the scheme to use a fake `CaseSubmitting` that canned-returns fake case IDs. Useful for UI iteration without hitting the real Denver API.

## How the Denver flow works

The app reverse-engineers Denver's PocketGov SPA flow, which uses:

1. **Azure AD B2C auth** — tenant `denverresidents.b2clogin.com`, policy `B2C_1A_DenverGov_SignUpOrSignin`, auth code + PKCE. We drive this through an embedded WKWebView and intercept the redirect to extract the auth code.
2. **Anonymous attachment upload** — `POST /api/cases/attachments/{clientGeneratedUUID}` with multipart form-data, no auth header required.
3. **Authenticated case submit** — `POST /api/cases` with the full case payload (menu/question metadata, contact from profile, address lookup result). Signed-in submissions carry `contact.b2cId = <id_token.sub>` so Denver attributes the report to your PocketGov account.
4. **Case list + status** — `GET /api/cases?$top=100&$orderby=Created desc` returns the user's full case history with per-case status (`caseStatus`, `resolutionNotes`, `closed`, etc.). Detail is `GET /api/cases/{id}`.

Menu metadata (category ids, per-question field names, Salesforce mappings) comes from `GET /api/forms/Menus` + `/api/forms/MenuQuestions?$filter=MenuId eq 10`.

## Releasing

App Store distribution is automated via [Fastlane](https://fastlane.tools/).
Full setup + lane reference in [`fastlane/README.md`](./fastlane/README.md).
Short version:

```sh
brew install fastlane                   # one-time: ships with its own Ruby
fastlane ios beta                       # → TestFlight
fastlane ios release                    # → App Store Connect (manual review trigger)
```

Requires App Store Connect API key env vars (`ASC_KEY_ID`, `ASC_ISSUER_ID`,
`ASC_KEY_FILEPATH`) so no Apple-ID password or 2FA prompts are ever needed.

## Machine learning models

Two Core ML models ship in `BikeLanes/BikeLanes/Resources/MLModels/`; plate OCR uses Apple Vision built in to iOS.

- **Car detector** — [YOLOv11n](https://github.com/ultralytics/ultralytics) (COCO class 2 "car") from Ultralytics.
- **License plate detector** — [morsetechlab/Yolov11-License-Plate-Detection](https://github.com/morsetechlab/Yolov11-License-Plate-Detection) (also on [Hugging Face](https://huggingface.co/morsetechlab/yolov11-license-plate-detection)), a YOLOv11n variant fine-tuned on a [Roboflow Universe license-plate dataset](https://universe.roboflow.com/). Exported to Core ML with `nms=False` so the app picks the highest-confidence anchor itself.
- **Plate OCR** — Apple Vision's `VNRecognizeTextRequest`.

Attribution per the plate detector's license: thanks to [Ultralytics](https://github.com/ultralytics/ultralytics), [Roboflow](https://roboflow.com/), and [MorseTech Lab](https://github.com/morsetechlab).

## Contributing

PRs welcome for bug fixes and non-commercial improvements. This is a community project, not a commercial product.

## License

[MIT](./LICENSE) — use it however you want, commercial or non-commercial, just keep the copyright notice.

---

© Sam Schooler · [sam.ink](https://sam.ink)
