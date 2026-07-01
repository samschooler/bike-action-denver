# Veo Scooter Reporting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an independent, anonymous flow to report improperly parked scooters/bikes to Veo (VeoRide) via their Zendesk Help Center form, reachable without any PocketGov sign-in.

**Architecture:** A separate Veo pipeline (`Services/VeoAPI/`, `ViewModels/VeoReportViewModel`, `Views/Veo/`) that shares only `ExifService`, a standalone `CLGeocoder` reverse-geocode, `Multipart`, and some `Views/Report/*` subviews. The Report tab root becomes a chooser (`ReportHomeView`) with the welcome banner on top; it pushes the existing `ReportView` (311) or the new `VeoReportView`. Submission is a 3-call flow: CSRF → attachment upload → form POST (302 = success).

**Tech Stack:** Swift 6, SwiftUI, `@Observable`, URLSession, AVFoundation (live QR), Vision (`VNDetectBarcodesRequest`, photo QR), CoreLocation, XCTest.

## Global Constraints

- iOS deployment target 17.0; Swift 6.0 (from `project.yml`). All new types `Sendable` where they cross concurrency boundaries; view models `@MainActor @Observable`.
- Sources are folder-based in `project.yml`; new files under `BikeLanes/BikeLanes/**` and `BikeLanes/BikeLanesTests/**` are picked up automatically after `xcodegen generate` from `BikeLanes/`. No `.pbxproj` editing.
- **The Veo flow must never reference `AuthService` or gate on PocketGov sign-in.** No file under `Services/VeoAPI/`, `ViewModels/VeoReportViewModel.swift`, or `Views/Veo/` may import/use `AuthService`.
- Veo API constants (verbatim, from `docs/veo-report-api.md`): base `https://veoride.zendesk.com`; `ticket_form_id = 24858990499988`; market tag `den_denver_-_co`; subject `A vehicle is parked where it doesn’t belong` (note the curly apostrophe U+2019); `description_mimetype = text/html`.
- Custom-field IDs: phone `360037999772`, vehicle number `360038000552`, vehicle type `360029446151`, market `360029389292`, full name `360038288771`, location `24861449413652`, private/blocking `24862782037652`, blocking ramp `24862819814548`.
- Submit success is **HTTP 302**; disable auto-redirect and treat any non-302 as an error.
- Vehicle number defaults to `(Didn't find it)` (straight apostrophe, matching the HAR) when blank.
- Phone is sent digits-only. The attachment JSON is passed to `request[attachments][]` **verbatim** as returned by the upload call.
- Run tests with:
  `cd BikeLanes && xcodegen generate && xcodebuild test -project BikeLanes.xcodeproj -scheme BikeLanes -destination 'platform=iOS Simulator,id=48C6CFB0-C3E2-4EDD-B7CB-097B53BCE275' -only-testing:BikeLanesTests/<Class>`

---

## File Structure

**Create (source):**
- `BikeLanes/BikeLanes/Models/VeoVehicleType.swift` — vehicle-type enum + wire tags
- `BikeLanes/BikeLanes/Models/VeoReportDraft.swift` — draft model + `isSubmittable`
- `BikeLanes/BikeLanes/Models/VeoProfile.swift` — reporter profile + `VeoProfileStore`
- `BikeLanes/BikeLanes/Services/VeoAPI/VeoEndpoints.swift` — URLs + constants
- `BikeLanes/BikeLanes/Services/VeoAPI/VeoModels.swift` — `VeoAttachment`, `VeoSubmission` + form encoding
- `BikeLanes/BikeLanes/Services/VeoAPI/VeoReportClient.swift` — `VeoSubmitting` protocol + client
- `BikeLanes/BikeLanes/Services/VeoAPI/VeoAddressResolver.swift` — `CLGeocoder` reverse-geocode
- `BikeLanes/BikeLanes/Services/VeoAPI/VeoCodeParser.swift` — pure `parseVehicleNumber`
- `BikeLanes/BikeLanes/Views/Veo/VeoScannerView.swift` — live camera QR + photo QR
- `BikeLanes/BikeLanes/ViewModels/VeoReportViewModel.swift` — orchestration
- `BikeLanes/BikeLanes/Views/Veo/ReportHomeView.swift` — chooser root
- `BikeLanes/BikeLanes/Views/Veo/VeoReportView.swift` — the form + success

**Modify:**
- `BikeLanes/BikeLanes/Views/Report/ReportView.swift` — remove `OnboardingBanner()` (moves to `ReportHomeView`)
- `BikeLanes/BikeLanes/Views/SettingsView.swift` — add "Veo reporter" section
- `BikeLanes/BikeLanes/App/BikeLanesApp.swift` — root = `ReportHomeView`; build `VeoReportViewModel`

**Create (tests):**
- `BikeLanes/BikeLanesTests/VeoVehicleTypeTests.swift`
- `BikeLanes/BikeLanesTests/VeoReportDraftTests.swift`
- `BikeLanes/BikeLanesTests/VeoProfileTests.swift`
- `BikeLanes/BikeLanesTests/VeoEndpointsTests.swift`
- `BikeLanes/BikeLanesTests/VeoSubmissionEncodingTests.swift`
- `BikeLanes/BikeLanesTests/VeoReportClientTests.swift`
- `BikeLanes/BikeLanesTests/VeoCodeParserTests.swift`
- `BikeLanes/BikeLanesTests/VeoReportViewModelTests.swift`

Reuse the existing `MockURLProtocol` (defined at the bottom of `BikeLanesTests/DenverAPIClientTests.swift`) for client tests.

## Execution Waves (for parallelization)

- **Wave A (independent, run in parallel):** Task 1, 2, 3, 4, 5, 6
- **Wave B (needs A):** Task 7 (needs 1,3,4), Task 8 (needs 2,6)
- **Wave C (needs B):** Task 9 (needs 2,6,8)
- **Wave D (needs C):** Task 10 (needs 7,8,9), Task 11 (needs 5)
- **Wave E (UI, needs D):** Task 12 (needs 10,11), Task 13 (needs 4), Task 14 (chooser; needs 12)
- **Wave F (wiring + integration):** Task 15 (needs 4,10,12,14), Task 16 (build/run)

---

### Task 1: `VeoVehicleType`

**Files:**
- Create: `BikeLanes/BikeLanes/Models/VeoVehicleType.swift`
- Test: `BikeLanes/BikeLanesTests/VeoVehicleTypeTests.swift`

**Interfaces:**
- Produces: `enum VeoVehicleType: String, CaseIterable, Codable, Sendable` with cases `bike, eBike, scooter, trike, cosmo, apollo, notApplicable`; `var wireValue: String`; `var display: String`.

- [ ] **Step 1: Write the failing test**

```swift
// BikeLanesTests/VeoVehicleTypeTests.swift
import XCTest
@testable import BikeLanes

final class VeoVehicleTypeTests: XCTestCase {
    func testWireValues() {
        XCTAssertEqual(VeoVehicleType.bike.wireValue, "bike")
        XCTAssertEqual(VeoVehicleType.eBike.wireValue, "e-bike")
        XCTAssertEqual(VeoVehicleType.scooter.wireValue, "scooter")
        XCTAssertEqual(VeoVehicleType.trike.wireValue, "trike")
        XCTAssertEqual(VeoVehicleType.cosmo.wireValue, "cosmo")
        XCTAssertEqual(VeoVehicleType.apollo.wireValue, "apollo")
        XCTAssertEqual(VeoVehicleType.notApplicable.wireValue, "not_applicable")
    }

    func testDisplayIsHumanReadable() {
        XCTAssertEqual(VeoVehicleType.eBike.display, "E-Bike")
        XCTAssertEqual(VeoVehicleType.scooter.display, "Scooter")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BikeLanes && xcodegen generate && xcodebuild test -project BikeLanes.xcodeproj -scheme BikeLanes -destination 'platform=iOS Simulator,id=48C6CFB0-C3E2-4EDD-B7CB-097B53BCE275' -only-testing:BikeLanesTests/VeoVehicleTypeTests`
Expected: FAIL — `cannot find 'VeoVehicleType' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// BikeLanes/Models/VeoVehicleType.swift
import Foundation

/// Vehicle taxonomy for Veo reports. `wireValue` is the Zendesk tagger tag for
/// custom field 360029446151.
enum VeoVehicleType: String, CaseIterable, Codable, Sendable {
    case bike, eBike, scooter, trike, cosmo, apollo, notApplicable

    var wireValue: String {
        switch self {
        case .bike:          return "bike"
        case .eBike:         return "e-bike"
        case .scooter:       return "scooter"
        case .trike:         return "trike"
        case .cosmo:         return "cosmo"
        case .apollo:        return "apollo"
        case .notApplicable: return "not_applicable"
        }
    }

    var display: String {
        switch self {
        case .bike:          return "Bike"
        case .eBike:         return "E-Bike"
        case .scooter:       return "Scooter"
        case .trike:         return "Trike"
        case .cosmo:         return "Cosmo"
        case .apollo:        return "Apollo"
        case .notApplicable: return "Not Applicable"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2 (without `xcodegen generate` if project already regenerated).
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Models/VeoVehicleType.swift BikeLanes/BikeLanesTests/VeoVehicleTypeTests.swift
git commit -m "feat(veo): add VeoVehicleType enum with Zendesk wire tags"
```

---

### Task 2: `VeoEndpoints`

**Files:**
- Create: `BikeLanes/BikeLanes/Services/VeoAPI/VeoEndpoints.swift`
- Test: `BikeLanes/BikeLanesTests/VeoEndpointsTests.swift`

**Interfaces:**
- Produces: `enum VeoEndpoints` with `static let base`, `csrfToken`, `requestUploads`, `requests: URL`; constants `ticketFormID`, `market`, `subject`, `descriptionMimeType: String`; `enum Field { static let phone/vehicleNumber/vehicleType/market/fullName/location/privateBlocking/blockingRamp: String }`.

- [ ] **Step 1: Write the failing test**

```swift
// BikeLanesTests/VeoEndpointsTests.swift
import XCTest
@testable import BikeLanes

final class VeoEndpointsTests: XCTestCase {
    func testURLs() {
        XCTAssertEqual(VeoEndpoints.csrfToken.absoluteString,
                       "https://veoride.zendesk.com/hc/api/internal/csrf_token.json")
        XCTAssertEqual(VeoEndpoints.requestUploads.absoluteString,
                       "https://veoride.zendesk.com/hc/en-us/request_uploads")
        XCTAssertEqual(VeoEndpoints.requests.absoluteString,
                       "https://veoride.zendesk.com/hc/en-us/requests")
    }

    func testConstants() {
        XCTAssertEqual(VeoEndpoints.ticketFormID, "24858990499988")
        XCTAssertEqual(VeoEndpoints.market, "den_denver_-_co")
        XCTAssertEqual(VeoEndpoints.subject, "A vehicle is parked where it doesn\u{2019}t belong")
        XCTAssertEqual(VeoEndpoints.Field.blockingRamp, "24862819814548")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BikeLanes && xcodegen generate && xcodebuild test -project BikeLanes.xcodeproj -scheme BikeLanes -destination 'platform=iOS Simulator,id=48C6CFB0-C3E2-4EDD-B7CB-097B53BCE275' -only-testing:BikeLanesTests/VeoEndpointsTests`
Expected: FAIL — `cannot find 'VeoEndpoints' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// BikeLanes/Services/VeoAPI/VeoEndpoints.swift
import Foundation

/// Veo (VeoRide) Zendesk Help Center endpoints + form constants.
/// See docs/veo-report-api.md.
enum VeoEndpoints {
    static let base = URL(string: "https://veoride.zendesk.com")!

    static let csrfToken     = base.appending(path: "hc/api/internal/csrf_token.json")
    static let requestUploads = base.appending(path: "hc/en-us/request_uploads")
    static let requests       = base.appending(path: "hc/en-us/requests")

    static let ticketFormID = "24858990499988"
    static let market       = "den_denver_-_co"
    static let subject      = "A vehicle is parked where it doesn\u{2019}t belong"
    static let descriptionMimeType = "text/html"

    /// Zendesk custom-field IDs for this ticket form.
    enum Field {
        static let phone           = "360037999772"
        static let vehicleNumber   = "360038000552"
        static let vehicleType     = "360029446151"
        static let market          = "360029389292"
        static let fullName        = "360038288771"
        static let location        = "24861449413652"
        static let privateBlocking = "24862782037652"
        static let blockingRamp    = "24862819814548"
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Services/VeoAPI/VeoEndpoints.swift BikeLanes/BikeLanesTests/VeoEndpointsTests.swift
git commit -m "feat(veo): add VeoEndpoints URLs and Zendesk form constants"
```

---

### Task 3: `VeoReportDraft`

**Files:**
- Create: `BikeLanes/BikeLanes/Models/VeoReportDraft.swift`
- Test: `BikeLanes/BikeLanesTests/VeoReportDraftTests.swift`

**Interfaces:**
- Consumes: `VeoVehicleType` (Task 1).
- Produces: `struct VeoReportDraft: Equatable, Sendable` with fields `photoURL: URL?`, `coordinates: CLLocationCoordinate2D?`, `addressText: String`, `vehicleType: VeoVehicleType?`, `vehicleNumber: String`, `onPrivateOrBlocking: Bool?`, `blockingRamp: Bool?`, `notes: String`, `observedAt: Date?`; computed `var isSubmittable: Bool`; `static let vehicleNumberFallback = "(Didn't find it)"`.

- [ ] **Step 1: Write the failing test**

```swift
// BikeLanesTests/VeoReportDraftTests.swift
import XCTest
import CoreLocation
@testable import BikeLanes

final class VeoReportDraftTests: XCTestCase {
    private func filled() -> VeoReportDraft {
        var d = VeoReportDraft()
        d.photoURL = URL(fileURLWithPath: "/tmp/x.jpg")
        d.addressText = "1300 Knox Ct, Denver, CO"
        d.vehicleType = .scooter
        d.onPrivateOrBlocking = false
        d.blockingRamp = false
        return d
    }

    func testFilledDraftIsSubmittable() {
        XCTAssertTrue(filled().isSubmittable)
    }

    func testMissingPhotoNotSubmittable() {
        var d = filled(); d.photoURL = nil
        XCTAssertFalse(d.isSubmittable)
    }

    func testMissingAddressNotSubmittable() {
        var d = filled(); d.addressText = "   "
        XCTAssertFalse(d.isSubmittable)
    }

    func testMissingYesNoNotSubmittable() {
        var d = filled(); d.blockingRamp = nil
        XCTAssertFalse(d.isSubmittable)
    }

    func testVehicleNumberOptional() {
        XCTAssertTrue(filled().isSubmittable) // vehicleNumber empty by default
        XCTAssertEqual(VeoReportDraft.vehicleNumberFallback, "(Didn't find it)")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BikeLanes && xcodegen generate && xcodebuild test -project BikeLanes.xcodeproj -scheme BikeLanes -destination 'platform=iOS Simulator,id=48C6CFB0-C3E2-4EDD-B7CB-097B53BCE275' -only-testing:BikeLanesTests/VeoReportDraftTests`
Expected: FAIL — `cannot find 'VeoReportDraft' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// BikeLanes/Models/VeoReportDraft.swift
import Foundation
import CoreLocation

struct VeoReportDraft: Equatable, Sendable {
    static let vehicleNumberFallback = "(Didn't find it)"

    var photoURL: URL?
    var coordinates: CLLocationCoordinate2D?
    var addressText: String = ""
    var vehicleType: VeoVehicleType?
    var vehicleNumber: String = ""
    var onPrivateOrBlocking: Bool?
    var blockingRamp: Bool?
    var notes: String = ""
    var observedAt: Date?

    var isSubmittable: Bool {
        photoURL != nil
            && !addressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && vehicleType != nil
            && onPrivateOrBlocking != nil
            && blockingRamp != nil
    }

    static func == (a: VeoReportDraft, b: VeoReportDraft) -> Bool {
        a.photoURL == b.photoURL
            && a.addressText == b.addressText
            && a.vehicleType == b.vehicleType
            && a.vehicleNumber == b.vehicleNumber
            && a.onPrivateOrBlocking == b.onPrivateOrBlocking
            && a.blockingRamp == b.blockingRamp
            && a.notes == b.notes
            && a.observedAt == b.observedAt
            && a.coordinates?.latitude == b.coordinates?.latitude
            && a.coordinates?.longitude == b.coordinates?.longitude
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Models/VeoReportDraft.swift BikeLanes/BikeLanesTests/VeoReportDraftTests.swift
git commit -m "feat(veo): add VeoReportDraft model with isSubmittable"
```

---

### Task 4: `VeoProfile` + `VeoProfileStore`

**Files:**
- Create: `BikeLanes/BikeLanes/Models/VeoProfile.swift`
- Test: `BikeLanes/BikeLanesTests/VeoProfileTests.swift`

**Interfaces:**
- Produces:
  - `struct VeoProfile: Codable, Equatable, Sendable` with `name, email, phone: String`; `var isComplete: Bool` (name & email non-empty); `var phoneDigits: String`.
  - `@MainActor @Observable final class VeoProfileStore` with `var profile: VeoProfile` (persisted to `UserDefaults`), `init(defaults: UserDefaults = .standard)`.

- [ ] **Step 1: Write the failing test**

```swift
// BikeLanesTests/VeoProfileTests.swift
import XCTest
@testable import BikeLanes

@MainActor
final class VeoProfileTests: XCTestCase {
    func testIsCompleteAndPhoneDigits() {
        var p = VeoProfile(name: "", email: "", phone: "")
        XCTAssertFalse(p.isComplete)
        p = VeoProfile(name: "Sam Schooler", email: "veo@sam.ink", phone: "(952) 688-3507")
        XCTAssertTrue(p.isComplete)
        XCTAssertEqual(p.phoneDigits, "9526883507")
    }

    func testStorePersistsAcrossInstances() {
        let suite = "veo.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = VeoProfileStore(defaults: defaults)
        store.profile = VeoProfile(name: "A B", email: "a@b.co", phone: "1234567890")
        let reloaded = VeoProfileStore(defaults: defaults)
        XCTAssertEqual(reloaded.profile.email, "a@b.co")
        defaults.removePersistentDomain(forName: suite)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BikeLanes && xcodegen generate && xcodebuild test -project BikeLanes.xcodeproj -scheme BikeLanes -destination 'platform=iOS Simulator,id=48C6CFB0-C3E2-4EDD-B7CB-097B53BCE275' -only-testing:BikeLanesTests/VeoProfileTests`
Expected: FAIL — `cannot find 'VeoProfile' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// BikeLanes/Models/VeoProfile.swift
import Foundation
import Observation

struct VeoProfile: Codable, Equatable, Sendable {
    var name: String = ""
    var email: String = ""
    var phone: String = ""

    var isComplete: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var phoneDigits: String { phone.filter(\.isNumber) }
}

@MainActor
@Observable
final class VeoProfileStore {
    private let defaults: UserDefaults
    private let key = "veoReporterProfile"

    var profile: VeoProfile {
        didSet { persist() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(VeoProfile.self, from: data) {
            self.profile = decoded
        } else {
            self.profile = VeoProfile()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: key)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Models/VeoProfile.swift BikeLanes/BikeLanesTests/VeoProfileTests.swift
git commit -m "feat(veo): add VeoProfile + persisted VeoProfileStore"
```

---

### Task 5: `VeoCodeParser.parseVehicleNumber`

**Files:**
- Create: `BikeLanes/BikeLanes/Services/VeoAPI/VeoCodeParser.swift`
- Test: `BikeLanes/BikeLanesTests/VeoCodeParserTests.swift`

**Interfaces:**
- Produces: `enum VeoCodeParser { static func parseVehicleNumber(from payload: String) -> String }`.

- [ ] **Step 1: Write the failing test**

```swift
// BikeLanesTests/VeoCodeParserTests.swift
import XCTest
@testable import BikeLanes

final class VeoCodeParserTests: XCTestCase {
    func testPlainCode() {
        XCTAssertEqual(VeoCodeParser.parseVehicleNumber(from: "  ABC123 "), "ABC123")
    }

    func testURLLastPathComponent() {
        XCTAssertEqual(
            VeoCodeParser.parseVehicleNumber(from: "https://www.veoride.com/qr/8891234"),
            "8891234")
    }

    func testURLQueryParam() {
        XCTAssertEqual(
            VeoCodeParser.parseVehicleNumber(from: "https://veoride.com/s?code=VN-42&x=1"),
            "VN-42")
    }

    func testEmpty() {
        XCTAssertEqual(VeoCodeParser.parseVehicleNumber(from: "   "), "")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BikeLanes && xcodegen generate && xcodebuild test -project BikeLanes.xcodeproj -scheme BikeLanes -destination 'platform=iOS Simulator,id=48C6CFB0-C3E2-4EDD-B7CB-097B53BCE275' -only-testing:BikeLanesTests/VeoCodeParserTests`
Expected: FAIL — `cannot find 'VeoCodeParser' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// BikeLanes/Services/VeoAPI/VeoCodeParser.swift
import Foundation

/// Extracts a Veo vehicle number from a scanned QR/barcode payload.
/// Veo handlebar QRs may encode a bare id or a URL; this normalizes both.
enum VeoCodeParser {
    private static let idQueryKeys = ["code", "id", "vehicle", "number", "qr"]

    static func parseVehicleNumber(from payload: String) -> String {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let comps = URLComponents(string: trimmed),
              let scheme = comps.scheme, scheme.hasPrefix("http") else {
            return trimmed
        }
        // Prefer a recognizable query param, else the last non-empty path component.
        if let item = comps.queryItems?.first(where: { idQueryKeys.contains($0.name.lowercased()) }),
           let value = item.value, !value.isEmpty {
            return value
        }
        let last = comps.path.split(separator: "/").last.map(String.init)
        return last ?? trimmed
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Services/VeoAPI/VeoCodeParser.swift BikeLanes/BikeLanesTests/VeoCodeParserTests.swift
git commit -m "feat(veo): add VeoCodeParser for QR payload -> vehicle number"
```

---

### Task 6: `VeoAddressResolver`

**Files:**
- Create: `BikeLanes/BikeLanes/Services/VeoAPI/VeoAddressResolver.swift`
- Test: none (thin `CLGeocoder` wrapper; formatting covered indirectly). The protocol enables a fake in Task 8.

**Interfaces:**
- Produces:
  - `protocol VeoAddressResolving: Sendable { func addressText(for coordinate: CLLocationCoordinate2D) async -> String? }`
  - `struct VeoAddressResolver: VeoAddressResolving` using `CLGeocoder`.
  - `static func format(_ placemark: CLPlacemark) -> String` (internal) building `"<subThoroughfare> <thoroughfare>, <locality>, <administrativeArea>"`, skipping nil parts.

- [ ] **Step 1: Write implementation (no unit test — CLGeocoder hits the network)**

```swift
// BikeLanes/Services/VeoAPI/VeoAddressResolver.swift
import Foundation
import CoreLocation

protocol VeoAddressResolving: Sendable {
    func addressText(for coordinate: CLLocationCoordinate2D) async -> String?
}

struct VeoAddressResolver: VeoAddressResolving {
    func addressText(for coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        guard let p = placemarks?.first else { return nil }
        return Self.format(p)
    }

    static func format(_ p: CLPlacemark) -> String {
        let street = [p.subThoroughfare, p.thoroughfare]
            .compactMap { $0 }.joined(separator: " ")
        let parts = [street, p.locality, p.administrativeArea]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd BikeLanes && xcodegen generate && xcodebuild build -project BikeLanes.xcodeproj -scheme BikeLanes -destination 'platform=iOS Simulator,id=48C6CFB0-C3E2-4EDD-B7CB-097B53BCE275' -quiet`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add BikeLanes/BikeLanes/Services/VeoAPI/VeoAddressResolver.swift
git commit -m "feat(veo): add CLGeocoder-based VeoAddressResolver"
```

---

### Task 7: `VeoModels` — attachment + submission form encoding

**Files:**
- Create: `BikeLanes/BikeLanes/Services/VeoAPI/VeoModels.swift`
- Test: `BikeLanes/BikeLanesTests/VeoSubmissionEncodingTests.swift`

**Interfaces:**
- Consumes: `VeoVehicleType` (1), `VeoReportDraft` (3), `VeoProfile` (4), `VeoEndpoints` (2).
- Produces:
  - `struct VeoAttachment: Decodable, Sendable { let id, fileName, url, deleteURL: String; let rawJSON: String }` (CodingKeys map `file_name`, `delete_url`; `rawJSON` is set by the client, not decoded — see Task 8).
  - `struct VeoSubmission: Sendable` built via `init(draft:profile:attachmentJSON:csrfToken:)`; `func formURLEncodedBody() -> String`.
  - Free function `veoFormEncode(_ s: String) -> String` (percent-encodes for `application/x-www-form-urlencoded`; alphanumerics + `-._~` unreserved, everything else percent-encoded; spaces as `%20`).

Note: `VeoAttachment.rawJSON` cannot be `Decodable`-populated; declare it `var rawJSON: String = ""` and have the client fill it. Keep the decodable fields separate.

- [ ] **Step 1: Write the failing test**

```swift
// BikeLanesTests/VeoSubmissionEncodingTests.swift
import XCTest
import CoreLocation
@testable import BikeLanes

final class VeoSubmissionEncodingTests: XCTestCase {
    private func sampleSubmission() -> VeoSubmission {
        var draft = VeoReportDraft()
        draft.photoURL = URL(fileURLWithPath: "/tmp/IMG.jpg")
        draft.addressText = "1300 Knox Ct, Denver, CO"
        draft.vehicleType = .eBike
        draft.vehicleNumber = ""            // -> fallback
        draft.onPrivateOrBlocking = false
        draft.blockingRamp = false
        draft.notes = "Bike parked on the sidewalk."
        let profile = VeoProfile(name: "Sam Schooler", email: "veo@sam.ink", phone: "(952) 688-3507")
        let attachment = #"{"id":"fodCAz","file_name":"IMG.jpg","url":"u","delete_url":"d"}"#
        return VeoSubmission(draft: draft, profile: profile,
                             attachmentJSON: attachment, csrfToken: "TOK")
    }

    func testEncodeUnreserved() {
        XCTAssertEqual(veoFormEncode("a b&c"), "a%20b%26c")
        XCTAssertEqual(veoFormEncode("Sam Schooler"), "Sam%20Schooler")
    }

    func testBodyContainsAllFields() {
        let body = sampleSubmission().formURLEncodedBody()
        XCTAssertTrue(body.contains("request%5Bticket_form_id%5D=24858990499988"))
        XCTAssertTrue(body.contains("request%5Banonymous_requester_email%5D=veo%40sam.ink"))
        XCTAssertTrue(body.contains("request%5Bsubject%5D="))
        XCTAssertTrue(body.contains("request%5Bdescription%5D=%3Cp%3EBike%20parked%20on%20the%20sidewalk.%3C%2Fp%3E"))
        XCTAssertTrue(body.contains("request%5Bdescription_mimetype%5D=text%2Fhtml"))
        XCTAssertTrue(body.contains("request%5Bcustom_fields%5D%5B360037999772%5D=9526883507")) // phone digits
        XCTAssertTrue(body.contains("request%5Bcustom_fields%5D%5B360038000552%5D=" +
            veoFormEncode("(Didn't find it)")))                                                   // vehicle number fallback
        XCTAssertTrue(body.contains("request%5Bcustom_fields%5D%5B360029446151%5D=e-bike"))       // vehicle type
        XCTAssertTrue(body.contains("request%5Bcustom_fields%5D%5B360029389292%5D=den_denver_-_co"))
        XCTAssertTrue(body.contains("request%5Bcustom_fields%5D%5B24862782037652%5D=illegal_parking_no"))
        XCTAssertTrue(body.contains("request%5Bcustom_fields%5D%5B24862819814548%5D=block_ramp_no"))
        XCTAssertTrue(body.contains("authenticity_token=TOK"))
        XCTAssertTrue(body.contains("request%5Battachments%5D%5B%5D="))
    }

    func testYesTags() {
        var draft = VeoReportDraft()
        draft.photoURL = URL(fileURLWithPath: "/tmp/x.jpg"); draft.addressText = "A"
        draft.vehicleType = .scooter
        draft.onPrivateOrBlocking = true; draft.blockingRamp = true
        let body = VeoSubmission(draft: draft, profile: VeoProfile(),
                                 attachmentJSON: "{}", csrfToken: "T").formURLEncodedBody()
        XCTAssertTrue(body.contains("360029446151%5D=scooter"))
        XCTAssertTrue(body.contains("24862782037652%5D=illegal_parking_yes"))
        XCTAssertTrue(body.contains("24862819814548%5D=block_ramp_yes"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BikeLanes && xcodegen generate && xcodebuild test -project BikeLanes.xcodeproj -scheme BikeLanes -destination 'platform=iOS Simulator,id=48C6CFB0-C3E2-4EDD-B7CB-097B53BCE275' -only-testing:BikeLanesTests/VeoSubmissionEncodingTests`
Expected: FAIL — `cannot find 'VeoSubmission' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// BikeLanes/Services/VeoAPI/VeoModels.swift
import Foundation

/// Percent-encodes a string for application/x-www-form-urlencoded bodies.
/// Only RFC 3986 unreserved characters pass through; everything else (incl.
/// space -> %20) is percent-encoded. Rails/Zendesk decode %20 as space.
func veoFormEncode(_ s: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
}

struct VeoAttachment: Decodable, Sendable {
    let id: String
    let fileName: String
    let url: String
    let deleteURL: String
    /// Raw JSON body as returned by the upload call; set by the client after decode.
    var rawJSON: String = ""

    enum CodingKeys: String, CodingKey {
        case id
        case fileName = "file_name"
        case url
        case deleteURL = "delete_url"
    }
}

struct VeoSubmission: Sendable {
    let draft: VeoReportDraft
    let profile: VeoProfile
    let attachmentJSON: String
    let csrfToken: String

    /// Builds the exact `request[...]` form body per docs/veo-report-api.md.
    func formURLEncodedBody() -> String {
        let vehicleNumber = draft.vehicleNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty ? VeoReportDraft.vehicleNumberFallback : draft.vehicleNumber
        let privateTag = (draft.onPrivateOrBlocking ?? false) ? "illegal_parking_yes" : "illegal_parking_no"
        let rampTag    = (draft.blockingRamp ?? false) ? "block_ramp_yes" : "block_ramp_no"
        let descriptionHTML = "<p>\(draft.notes)</p>"

        func cf(_ id: String) -> String { "request[custom_fields][\(id)]" }

        let pairs: [(String, String)] = [
            ("utf8", "\u{2713}"),
            ("request[ticket_form_id]", VeoEndpoints.ticketFormID),
            ("request[anonymous_requester_email]", profile.email),
            ("request[subject]", VeoEndpoints.subject),
            ("request[description]", descriptionHTML),
            ("request[description_mimetype]", VeoEndpoints.descriptionMimeType),
            (cf(VeoEndpoints.Field.phone), profile.phoneDigits),
            (cf(VeoEndpoints.Field.vehicleNumber), vehicleNumber),
            (cf(VeoEndpoints.Field.vehicleType), draft.vehicleType?.wireValue ?? ""),
            (cf(VeoEndpoints.Field.market), VeoEndpoints.market),
            (cf(VeoEndpoints.Field.fullName), profile.name),
            (cf(VeoEndpoints.Field.location), draft.addressText),
            (cf(VeoEndpoints.Field.privateBlocking), privateTag),
            (cf(VeoEndpoints.Field.blockingRamp), rampTag),
            ("request[attachments][]", attachmentJSON),
            ("authenticity_token", csrfToken),
        ]
        return pairs
            .map { "\(veoFormEncode($0.0))=\(veoFormEncode($0.1))" }
            .joined(separator: "&")
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Services/VeoAPI/VeoModels.swift BikeLanes/BikeLanesTests/VeoSubmissionEncodingTests.swift
git commit -m "feat(veo): add VeoSubmission form encoding + VeoAttachment"
```

---

### Task 8: `VeoReportClient` — 3-call flow

**Files:**
- Create: `BikeLanes/BikeLanes/Services/VeoAPI/VeoReportClient.swift`
- Test: `BikeLanes/BikeLanesTests/VeoReportClientTests.swift`

**Interfaces:**
- Consumes: `VeoEndpoints` (2), `VeoModels` (7), `Multipart` (existing).
- Produces:
  - `protocol VeoSubmitting: Sendable { func fetchCSRFToken() async throws -> String; func uploadAttachment(filename: String, mimeType: String, data: Data) async throws -> VeoAttachment; func submit(_ submission: VeoSubmission) async throws }`
  - `struct VeoReportClient: VeoSubmitting` with `init(session: URLSession = VeoReportClient.makeSession())`; `static func makeSession() -> URLSession` (own cookie storage, `.always` accept policy).
  - `enum VeoError: Error { case http(status: Int, body: Data); case badResponse; case csrfMissing }`.
- **Must not reference `AuthService`.**

Implementation notes:
- Redirects must NOT be auto-followed (302 = success). Pass a `NoRedirect` delegate to `session.data(for:delegate:)`.
- `submit` builds the body, sets `Content-Type: application/x-www-form-urlencoded`, `X-Requested-With: XMLHttpRequest`, `Origin`/`Referer` to the Zendesk form, sends, and succeeds only on status 302.
- `uploadAttachment` captures the raw response string into `VeoAttachment.rawJSON`.

- [ ] **Step 1: Write the failing test**

```swift
// BikeLanesTests/VeoReportClientTests.swift
import XCTest
@testable import BikeLanes

final class VeoReportClientTests: XCTestCase {
    override func setUp() {
        MockURLProtocol.responders.removeAll()
        MockURLProtocol.recordedRequests.removeAll()
    }

    func testFetchCSRFToken() async throws {
        MockURLProtocol.responders[VeoEndpoints.csrfToken] = .json(
            #"{"current_session":{"csrf_token":"hc:abc"}}"#, status: 200)
        let client = VeoReportClient(session: MockURLProtocol.session)
        let token = try await client.fetchCSRFToken()
        XCTAssertEqual(token, "hc:abc")
    }

    func testUploadAttachmentCapturesRawJSON() async throws {
        let raw = #"{"id":"XYZ","file_name":"IMG.jpg","url":"u","delete_url":"d"}"#
        MockURLProtocol.responders[VeoEndpoints.requestUploads] = .json(raw, status: 200)
        let client = VeoReportClient(session: MockURLProtocol.session)
        let att = try await client.uploadAttachment(filename: "IMG.jpg",
                                                     mimeType: "image/jpeg", data: Data([1,2,3]))
        XCTAssertEqual(att.id, "XYZ")
        XCTAssertEqual(att.rawJSON, raw)
        let recorded = MockURLProtocol.recordedRequests.first!
        XCTAssertTrue(recorded.value(forHTTPHeaderField: "Content-Type")?
            .hasPrefix("multipart/form-data;") ?? false)
        XCTAssertEqual(recorded.value(forHTTPHeaderField: "X-Requested-With"), "XMLHttpRequest")
    }

    func testSubmitSucceedsOn302() async throws {
        MockURLProtocol.responders[VeoEndpoints.requests] = .status(302)
        let client = VeoReportClient(session: MockURLProtocol.session)
        var draft = VeoReportDraft()
        draft.vehicleType = .scooter
        let sub = VeoSubmission(draft: draft, profile: VeoProfile(),
                                attachmentJSON: "{}", csrfToken: "T")
        try await client.submit(sub) // must not throw
        let recorded = MockURLProtocol.recordedRequests.last!
        XCTAssertEqual(recorded.httpMethod, "POST")
        XCTAssertEqual(recorded.value(forHTTPHeaderField: "Content-Type"),
                       "application/x-www-form-urlencoded")
    }

    func testSubmitThrowsOnNon302() async {
        MockURLProtocol.responders[VeoEndpoints.requests] = .status(200)
        let client = VeoReportClient(session: MockURLProtocol.session)
        var draft = VeoReportDraft(); draft.vehicleType = .scooter
        let sub = VeoSubmission(draft: draft, profile: VeoProfile(),
                                attachmentJSON: "{}", csrfToken: "T")
        do { try await client.submit(sub); XCTFail("expected throw") }
        catch { /* expected */ }
    }
}
```

Note: the shared `MockURLProtocol` currently emits `.status(...)` with no `Location` header, so a 302 will not be auto-followed even by the default session — but the production `NoRedirect` delegate is still required and covered by manual/simulator testing.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BikeLanes && xcodegen generate && xcodebuild test -project BikeLanes.xcodeproj -scheme BikeLanes -destination 'platform=iOS Simulator,id=48C6CFB0-C3E2-4EDD-B7CB-097B53BCE275' -only-testing:BikeLanesTests/VeoReportClientTests`
Expected: FAIL — `cannot find 'VeoReportClient' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// BikeLanes/Services/VeoAPI/VeoReportClient.swift
import Foundation

protocol VeoSubmitting: Sendable {
    func fetchCSRFToken() async throws -> String
    func uploadAttachment(filename: String, mimeType: String, data: Data) async throws -> VeoAttachment
    func submit(_ submission: VeoSubmission) async throws
}

struct VeoReportClient: VeoSubmitting {
    let session: URLSession

    init(session: URLSession = VeoReportClient.makeSession()) {
        self.session = session
    }

    /// Session with its own cookie jar so the _help_center_session cookie set by
    /// the CSRF GET is sent on the subsequent upload + submit POSTs.
    static func makeSession() -> URLSession {
        let cfg = URLSessionConfiguration.default
        cfg.httpCookieStorage = HTTPCookieStorage()
        cfg.httpCookieAcceptPolicy = .always
        cfg.httpShouldSetCookies = true
        return URLSession(configuration: cfg)
    }

    private struct CSRFEnvelope: Decodable {
        struct Session: Decodable { let csrf_token: String }
        let current_session: Session
    }

    func fetchCSRFToken() async throws -> String {
        var req = URLRequest(url: VeoEndpoints.csrfToken)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: req, delegate: NoRedirect())
        try Self.ensure2xx(response, data)
        return try JSONDecoder().decode(CSRFEnvelope.self, from: data).current_session.csrf_token
    }

    func uploadAttachment(filename: String, mimeType: String, data fileData: Data) async throws -> VeoAttachment {
        var req = URLRequest(url: VeoEndpoints.requestUploads)
        req.httpMethod = "POST"
        req.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        req.setValue(VeoEndpoints.base.absoluteString, forHTTPHeaderField: "Origin")
        req.setValue(VeoEndpoints.requests.absoluteString + "/new", forHTTPHeaderField: "Referer")
        let boundary = Multipart.newBoundary()
        req.setValue(Multipart.contentType(boundary: boundary), forHTTPHeaderField: "Content-Type")
        req.httpBody = Multipart.body(boundary: "----" + boundary, fileField: "file",
                                      filename: filename, mimeType: mimeType, data: fileData)
        let (data, response) = try await session.data(for: req, delegate: NoRedirect())
        try Self.ensure2xx(response, data)
        var att = try JSONDecoder().decode(VeoAttachment.self, from: data)
        att.rawJSON = String(data: data, encoding: .utf8) ?? ""
        return att
    }

    func submit(_ submission: VeoSubmission) async throws {
        var req = URLRequest(url: VeoEndpoints.requests)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(VeoEndpoints.base.absoluteString, forHTTPHeaderField: "Origin")
        req.setValue(VeoEndpoints.requests.absoluteString + "/new", forHTTPHeaderField: "Referer")
        req.httpBody = submission.formURLEncodedBody().data(using: .utf8)
        let (data, response) = try await session.data(for: req, delegate: NoRedirect())
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 302 else { throw VeoError.http(status: status, body: data) }
    }

    private static func ensure2xx(_ response: URLResponse, _ data: Data) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else { throw VeoError.http(status: status, body: data) }
    }
}

/// Prevents URLSession from auto-following the 302 that signals a successful
/// Zendesk submit, so we can observe the redirect status directly.
private final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        nil
    }
}

enum VeoError: Error, CustomStringConvertible {
    case http(status: Int, body: Data)
    case badResponse
    case csrfMissing

    var description: String {
        switch self {
        case .http(let s, let b):
            return "Veo HTTP \(s): \(String(data: b, encoding: .utf8) ?? "<non-utf8>")"
        case .badResponse: return "Unexpected response from Veo."
        case .csrfMissing: return "Could not obtain a Veo session token."
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Services/VeoAPI/VeoReportClient.swift BikeLanes/BikeLanesTests/VeoReportClientTests.swift
git commit -m "feat(veo): add VeoReportClient 3-call submit flow (302=success)"
```

---

### Task 9: `VeoReportViewModel`

**Files:**
- Create: `BikeLanes/BikeLanes/ViewModels/VeoReportViewModel.swift`
- Test: `BikeLanes/BikeLanesTests/VeoReportViewModelTests.swift`

**Interfaces:**
- Consumes: `VeoReportDraft` (3), `VeoProfile`/`VeoProfileStore` (4), `VeoSubmitting`/`VeoAttachment`/`VeoSubmission` (7,8), `VeoAddressResolving` (6), `ExifService` (existing).
- Produces: `@MainActor @Observable final class VeoReportViewModel` with `var draft`, `var isSubmitting`, `var lastError: String?`, `var didSubmit: Bool`; `init(exif:resolver:client:profileStore:)`; `func load(photoURL:) async`; `func submit() async`.
- **No `AuthService`.**

Behavior:
- `load`: reset draft, set `photoURL`, read EXIF (coords, observedAt), and if coords present resolve `addressText` via resolver.
- `submit`: guard `profileStore.profile.isComplete` (else `lastError = "Add your name and email in Settings → Veo reporter first."`); read photo `Data`; `fetchCSRFToken` → `uploadAttachment` → `VeoSubmission(...)` with `att.rawJSON` → `client.submit`; on success set `didSubmit = true`; on throw set `lastError`.

- [ ] **Step 1: Write the failing test**

```swift
// BikeLanesTests/VeoReportViewModelTests.swift
import XCTest
import CoreLocation
@testable import BikeLanes

@MainActor
final class VeoReportViewModelTests: XCTestCase {
    final class FakeClient: VeoSubmitting, @unchecked Sendable {
        var submitted: VeoSubmission?
        var tokenCalls = 0, uploadCalls = 0
        func fetchCSRFToken() async throws -> String { tokenCalls += 1; return "TOK" }
        func uploadAttachment(filename: String, mimeType: String, data: Data) async throws -> VeoAttachment {
            uploadCalls += 1
            var a = VeoAttachment(id: "I", fileName: filename, url: "u", deleteURL: "d")
            a.rawJSON = "{\"id\":\"I\"}"; return a
        }
        func submit(_ submission: VeoSubmission) async throws { submitted = submission }
    }
    struct FakeResolver: VeoAddressResolving {
        func addressText(for coordinate: CLLocationCoordinate2D) async -> String? { "1 Main St, Denver, CO" }
    }

    private func tempPhoto() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("veo-\(UUID()).jpg")
        try Data([0xFF, 0xD8, 0xFF]).write(to: url)
        return url
    }

    private func makeVM(_ client: FakeClient, profile: VeoProfile) -> VeoReportViewModel {
        let store = VeoProfileStore(defaults: UserDefaults(suiteName: "veo.vm.\(UUID())")!)
        store.profile = profile
        return VeoReportViewModel(exif: ExifService(), resolver: FakeResolver(),
                                  client: client, profileStore: store)
    }

    func testSubmitBuildsAndSendsWithoutAuth() async throws {
        let client = FakeClient()
        let vm = makeVM(client, profile: VeoProfile(name: "Sam", email: "veo@sam.ink", phone: "1234567890"))
        vm.draft.photoURL = try tempPhoto()
        vm.draft.addressText = "1 Main St, Denver, CO"
        vm.draft.vehicleType = .scooter
        vm.draft.onPrivateOrBlocking = false
        vm.draft.blockingRamp = false
        await vm.submit()
        XCTAssertNil(vm.lastError)
        XCTAssertTrue(vm.didSubmit)
        XCTAssertEqual(client.tokenCalls, 1)
        XCTAssertEqual(client.uploadCalls, 1)
        XCTAssertNotNil(client.submitted)
    }

    func testSubmitBlockedWhenProfileIncomplete() async throws {
        let client = FakeClient()
        let vm = makeVM(client, profile: VeoProfile())
        vm.draft.photoURL = try tempPhoto()
        vm.draft.vehicleType = .scooter
        await vm.submit()
        XCTAssertNotNil(vm.lastError)
        XCTAssertFalse(vm.didSubmit)
        XCTAssertNil(client.submitted)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BikeLanes && xcodegen generate && xcodebuild test -project BikeLanes.xcodeproj -scheme BikeLanes -destination 'platform=iOS Simulator,id=48C6CFB0-C3E2-4EDD-B7CB-097B53BCE275' -only-testing:BikeLanesTests/VeoReportViewModelTests`
Expected: FAIL — `cannot find 'VeoReportViewModel' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// BikeLanes/ViewModels/VeoReportViewModel.swift
import Foundation
import Observation
import CoreLocation

@MainActor
@Observable
final class VeoReportViewModel {
    var draft = VeoReportDraft()
    var isSubmitting = false
    var lastError: String?
    var didSubmit = false

    private let exif: ExifService
    private let resolver: VeoAddressResolving
    private let client: VeoSubmitting
    let profileStore: VeoProfileStore

    init(exif: ExifService, resolver: VeoAddressResolving,
         client: VeoSubmitting, profileStore: VeoProfileStore) {
        self.exif = exif; self.resolver = resolver
        self.client = client; self.profileStore = profileStore
    }

    func load(photoURL url: URL) async {
        lastError = nil; didSubmit = false
        var d = VeoReportDraft()
        d.photoURL = url
        if let meta = try? exif.read(url: url) {
            d.coordinates = meta.coordinates
            d.observedAt = meta.observedAt ?? .now
        }
        draft = d
        if let coord = draft.coordinates,
           let text = await resolver.addressText(for: coord) {
            draft.addressText = text
        }
    }

    func submit() async {
        lastError = nil
        guard profileStore.profile.isComplete else {
            lastError = "Add your name and email in Settings → Veo reporter first."
            return
        }
        guard let url = draft.photoURL, let data = try? Data(contentsOf: url) else {
            lastError = "Couldn't read the photo."
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let token = try await client.fetchCSRFToken()
            let filename = url.lastPathComponent
            let mime = filename.lowercased().hasSuffix(".heic") ? "image/heic" : "image/jpeg"
            let att = try await client.uploadAttachment(filename: filename, mimeType: mime, data: data)
            let submission = VeoSubmission(draft: draft, profile: profileStore.profile,
                                           attachmentJSON: att.rawJSON, csrfToken: token)
            try await client.submit(submission)
            didSubmit = true
        } catch {
            lastError = "Couldn't send to Veo: \(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/ViewModels/VeoReportViewModel.swift BikeLanes/BikeLanesTests/VeoReportViewModelTests.swift
git commit -m "feat(veo): add VeoReportViewModel (auth-free submit orchestration)"
```

---

### Task 10: `VeoScannerView` — live + photo QR

**Files:**
- Create: `BikeLanes/BikeLanes/Views/Veo/VeoScannerView.swift`
- Test: none (camera/Vision UI; parsing is covered by Task 5).

**Interfaces:**
- Consumes: `VeoCodeParser` (5).
- Produces:
  - `struct VeoScannerView: View` — full-screen live camera scanner via `AVCaptureMetadataOutput`; `let onScanned: (String) -> Void` (already parsed).
  - `enum VeoPhotoQR { static func scan(_ image: UIImage) -> String? }` using `VNDetectBarcodesRequest`.

- [ ] **Step 1: Write implementation**

```swift
// BikeLanes/Views/Veo/VeoScannerView.swift
import SwiftUI
import AVFoundation
import Vision
import UIKit

/// Decodes a QR/barcode from a still image via Vision.
enum VeoPhotoQR {
    static func scan(_ image: UIImage) -> String? {
        guard let cg = image.cgImage else { return nil }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr, .aztec, .code128, .code39, .dataMatrix, .ean13]
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try? handler.perform([request])
        let payload = (request.results as? [VNBarcodeObservation])?
            .compactMap { $0.payloadStringValue }.first
        return payload.map(VeoCodeParser.parseVehicleNumber)
    }
}

/// Full-screen live camera QR/barcode scanner. Calls `onScanned` with the parsed
/// vehicle number once, then dismisses.
struct VeoScannerView: UIViewControllerRepresentable {
    let onScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> ScannerController {
        let c = ScannerController()
        c.onScanned = { value in
            context.coordinator.deliverOnce(value)
        }
        return c
    }
    func updateUIViewController(_ vc: ScannerController, context: Context) {}
    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned, dismiss: { dismiss() })
    }

    final class Coordinator {
        private let onScanned: (String) -> Void
        private let dismiss: () -> Void
        private var delivered = false
        init(onScanned: @escaping (String) -> Void, dismiss: @escaping () -> Void) {
            self.onScanned = onScanned; self.dismiss = dismiss
        }
        func deliverOnce(_ raw: String) {
            guard !delivered else { return }
            delivered = true
            onScanned(VeoCodeParser.parseVehicleNumber(from: raw))
            dismiss()
        }
    }

    final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onScanned: ((String) -> Void)?
        private let session = AVCaptureSession()

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            session.addInput(input)
            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr, .aztec, .code128, .code39, .dataMatrix, .ean13]
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.layer.bounds
            view.layer.addSublayer(preview)
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            if !session.isRunning {
                DispatchQueue.global(qos: .userInitiated).async { [session] in session.startRunning() }
            }
        }
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if session.isRunning { session.stopRunning() }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput objects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let obj = objects.first as? AVMetadataMachineReadableCodeObject,
                  let value = obj.stringValue else { return }
            onScanned?(value)
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd BikeLanes && xcodegen generate && xcodebuild build -project BikeLanes.xcodeproj -scheme BikeLanes -destination 'platform=iOS Simulator,id=48C6CFB0-C3E2-4EDD-B7CB-097B53BCE275' -quiet`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add BikeLanes/BikeLanes/Views/Veo/VeoScannerView.swift
git commit -m "feat(veo): add live + photo QR scanner (VeoScannerView, VeoPhotoQR)"
```

---

### Task 11: `VeoReportView` + success view

**Files:**
- Create: `BikeLanes/BikeLanes/Views/Veo/VeoReportView.swift`
- Test: none (SwiftUI view; logic covered by Task 9).

**Interfaces:**
- Consumes: `VeoReportViewModel` (9), `VeoScannerView`/`VeoPhotoQR` (10), `VeoVehicleType` (1), and existing `PhotoCard`, `PhotoSourcePanel`, `CameraPicker`, `QuickPickRow`, `QuickPickOption`, `SubmitButton`.
- Produces: `struct VeoReportView: View` with `init(vm: VeoReportViewModel)`.

Behavior: photo empty-state → `PhotoSourcePanel`; after photo → `PhotoCard` + address `TextField` + vehicle-type `QuickPickRow` + vehicle-number row with scan menu (live/from-photo) + two yes/no `Picker`s + notes `TextField` + submit. On `didSubmit`, show a success `fullScreenCover` and reset.

- [ ] **Step 1: Write implementation**

```swift
// BikeLanes/Views/Veo/VeoReportView.swift
import SwiftUI
import PhotosUI

struct VeoReportView: View {
    @Bindable var vm: VeoReportViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingLibraryPicker = false
    @State private var showingCamera = false
    @State private var showingScanner = false
    @State private var scanPickerItem: PhotosPickerItem?
    @State private var showingScanFromPhoto = false
    private let bg = Color(red: 250/255, green: 250/255, blue: 247/255)

    init(vm: VeoReportViewModel) { self.vm = vm }

    private let vehicleOptions: [QuickPickOption<VeoVehicleType>] =
        VeoVehicleType.allCases.map { .init(label: $0.display, value: $0) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if vm.draft.photoURL == nil {
                    PhotoSourcePanel(onTakePhoto: { showingCamera = true },
                                     onChoosePhoto: { showingLibraryPicker = true })
                        .padding(.top, 12)
                } else {
                    form
                }
            }
            .padding(.vertical, 16)
        }
        .background(bg)
        .navigationTitle("Report to Veo")
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: $showingLibraryPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, new in guard let new else { return }; Task { await loadPicked(new) } }
        .photosPicker(isPresented: $showingScanFromPhoto, selection: $scanPickerItem, matching: .images)
        .onChange(of: scanPickerItem) { _, new in guard let new else { return }; Task { await scanFromPhoto(new) } }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker(onCaptured: { url in Task { await vm.load(photoURL: url) } }).ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingScanner) {
            VeoScannerView(onScanned: { vm.draft.vehicleNumber = $0 }).ignoresSafeArea()
        }
        .fullScreenCover(isPresented: Binding(get: { vm.didSubmit }, set: { if !$0 { vm.didSubmit = false } })) {
            VeoSuccessView(onDone: { vm.didSubmit = false; vm.draft = .init() })
        }
    }

    @ViewBuilder private var form: some View {
        PhotoCard(image: vm.draft.photoURL.flatMap { UIImage(contentsOfFile: $0.path) },
                  bbox: nil, plateBBox: nil, plateStatus: nil, heading: nil,
                  coordinate: vm.draft.coordinates,
                  onTakePhoto: { showingCamera = true },
                  onChoosePhoto: { showingLibraryPicker = true })
            .padding(.horizontal, 20)

        card { labeledField("Location (address or cross streets)",
                            text: $vm.draft.addressText, placeholder: "1300 Knox Ct, Denver, CO") }

        card { QuickPickRow(label: "Vehicle type",
                            options: vehicleOptions, selection: $vm.draft.vehicleType) }

        card { vehicleNumberRow }

        card { yesNoPicker("On private property / blocking a walkway, street or parking spot?",
                           selection: $vm.draft.onPrivateOrBlocking) }
        card { yesNoPicker("Blocking an accessibility ramp?", selection: $vm.draft.blockingRamp) }

        card { labeledField("Notes", text: $vm.draft.notes, placeholder: "Describe what you saw") }

        if let err = vm.lastError {
            Text(err).font(.system(size: 13)).foregroundStyle(Color(red: 179/255, green: 58/255, blue: 58/255))
                .padding(.horizontal, 20)
        }

        SubmitButton(enabled: vm.draft.isSubmittable && !vm.isSubmitting,
                     isLoading: vm.isSubmitting) {
            Task { await vm.submit() }
        }
        .padding(.horizontal, 20).padding(.top, 4)
    }

    private var vehicleNumberRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VEHICLE NUMBER").font(.system(size: 11, weight: .medium)).kerning(0.88)
                .foregroundStyle(Color(red: 138/255, green: 135/255, blue: 118/255))
            HStack {
                TextField(VeoReportDraft.vehicleNumberFallback, text: $vm.draft.vehicleNumber)
                    .textFieldStyle(.roundedBorder)
                Menu {
                    Button { showingScanner = true } label: { Label("Scan with camera", systemImage: "qrcode.viewfinder") }
                    Button { showingScanFromPhoto = true } label: { Label("Scan from photo", systemImage: "photo") }
                } label: {
                    Image(systemName: "qrcode.viewfinder").font(.system(size: 20))
                        .foregroundStyle(Color(red: 42/255, green: 111/255, blue: 63/255))
                }
            }
            Text("Located under the QR code in the center of the handlebars, if available.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased()).font(.system(size: 11, weight: .medium)).kerning(0.88)
                .foregroundStyle(Color(red: 138/255, green: 135/255, blue: 118/255))
            TextField(placeholder, text: text, axis: .vertical).textFieldStyle(.roundedBorder)
        }
    }

    private func yesNoPicker(_ label: String, selection: Binding<Bool?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased()).font(.system(size: 11, weight: .medium)).kerning(0.88)
                .foregroundStyle(Color(red: 138/255, green: 135/255, blue: 118/255))
            Picker(label, selection: Binding(
                get: { selection.wrappedValue },
                set: { selection.wrappedValue = $0 })) {
                    Text("Select").tag(Bool?.none)
                    Text("Yes").tag(Bool?.some(true))
                    Text("No").tag(Bool?.some(false))
                }
                .pickerStyle(.segmented)
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 20)
    }

    private func loadPicked(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("veo-pick-\(UUID()).jpg")
        try? data.write(to: url)
        await vm.load(photoURL: url)
    }

    private func scanFromPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data), let value = VeoPhotoQR.scan(image) else {
            vm.lastError = "No code found in that photo."
            return
        }
        vm.draft.vehicleNumber = value
    }
}

struct VeoSuccessView: View {
    let onDone: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 64))
                .foregroundStyle(Color(red: 42/255, green: 111/255, blue: 63/255))
            Text("Reported to Veo").font(.system(size: 22, weight: .semibold))
            Text("Your report was filed with Veo support. Thanks for keeping the sidewalks clear.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal, 40)
            Button(action: onDone) {
                Text("Done").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .padding(.vertical, 16).frame(maxWidth: .infinity)
                    .background(Color(red: 42/255, green: 111/255, blue: 63/255))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}
```

Note: `SubmitButton` says "Submit to Denver". Leave copy as-is for this task (a shared component change is out of scope); Task 12 optionally parameterizes it. If the shared copy is unacceptable, add a `title`/`caption` parameter to `SubmitButton` in this task and pass Veo copy — but do not break `ReportView`'s existing call.

- [ ] **Step 2: Verify it compiles**

Run: `cd BikeLanes && xcodegen generate && xcodebuild build -project BikeLanes.xcodeproj -scheme BikeLanes -destination 'platform=iOS Simulator,id=48C6CFB0-C3E2-4EDD-B7CB-097B53BCE275' -quiet`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add BikeLanes/BikeLanes/Views/Veo/VeoReportView.swift
git commit -m "feat(veo): add VeoReportView form + success screen"
```

---

### Task 12: `SubmitButton` copy parameterization (small, enables correct Veo copy)

**Files:**
- Modify: `BikeLanes/BikeLanes/Views/Report/SubmitButton.swift`
- Modify: `BikeLanes/BikeLanes/Views/Veo/VeoReportView.swift` (pass Veo copy)

**Interfaces:**
- Produces: `SubmitButton` gains `title: String = "Submit to Denver"` and `caption: String? = nil` (when non-nil, overrides the built-in 311 caption). Existing `ReportView` call keeps working via defaults.

- [ ] **Step 1: Modify `SubmitButton`**

Add parameters and use them:

```swift
struct SubmitButton: View {
    let enabled: Bool
    let isLoading: Bool
    let signedInAs: String?
    let title: String
    let captionOverride: String?
    let action: () -> Void

    init(enabled: Bool, isLoading: Bool, signedInAs: String? = nil,
         title: String = "Submit to Denver", captionOverride: String? = nil,
         action: @escaping () -> Void) {
        self.enabled = enabled; self.isLoading = isLoading
        self.signedInAs = signedInAs; self.title = title
        self.captionOverride = captionOverride; self.action = action
    }
    // ...replace the hard-coded Text("Submit to Denver") with Text(title)
    // ...replace captionText body to: captionOverride ?? "<existing 311 caption>"
```

Concretely change the button label line to `Text(title)` and the `captionText` computed property to:

```swift
    private var captionText: String {
        if let captionOverride { return captionOverride }
        let name = signedInAs ?? "your account"
        return "Files a case with Denver 311 under \(name).\nYou'll get status updates in your PocketGov account."
    }
```

- [ ] **Step 2: Update the Veo call site**

In `VeoReportView.form`, change the `SubmitButton(...)` call to:

```swift
        SubmitButton(enabled: vm.draft.isSubmittable && !vm.isSubmitting,
                     isLoading: vm.isSubmitting,
                     title: "Submit to Veo",
                     captionOverride: "Files a support request with Veo. No Denver account needed.") {
            Task { await vm.submit() }
        }
```

- [ ] **Step 3: Verify it compiles + existing tests pass**

Run: `cd BikeLanes && xcodegen generate && xcodebuild test -project BikeLanes.xcodeproj -scheme BikeLanes -destination 'platform=iOS Simulator,id=48C6CFB0-C3E2-4EDD-B7CB-097B53BCE275' -only-testing:BikeLanesTests/ReportViewSnapshotTests`
Expected: PASS (or build success if snapshot recording differs — inspect and re-record only if intentional).

- [ ] **Step 4: Commit**

```bash
git add BikeLanes/BikeLanes/Views/Report/SubmitButton.swift BikeLanes/BikeLanes/Views/Veo/VeoReportView.swift
git commit -m "feat(veo): parameterize SubmitButton title/caption; use Veo copy"
```

---

### Task 13: Settings — "Veo reporter" section

**Files:**
- Modify: `BikeLanes/BikeLanes/Views/SettingsView.swift`
- Modify: `BikeLanes/BikeLanes/App/BikeLanesApp.swift` (pass `veoProfileStore` into `SettingsView`) — coordinate with Task 15.

**Interfaces:**
- Consumes: `VeoProfileStore` (4).
- Produces: `SettingsView` gains `let veoProfile: VeoProfileStore?` (defaulted nil so previews/tests keep compiling) and renders a "Veo reporter" section binding to `veoProfile.profile`.

- [ ] **Step 1: Add the property + section**

Add to `SettingsView`:

```swift
    @Bindable var veoProfileBinding: VeoProfileStore
    // If keeping optional injection, prefer a non-optional store created by the app.
```

Simplest approach: make `SettingsView` take a non-optional `veoProfile: VeoProfileStore`. Update its initializer:

```swift
    let auth: AuthService?
    @Bindable var veoProfile: VeoProfileStore

    init(auth: AuthService? = nil, veoProfile: VeoProfileStore) {
        self.auth = auth
        self.veoProfile = veoProfile
    }
```

Add this section to the `Form`, after the "Account" section:

```swift
            Section("Veo reporter") {
                TextField("Full name", text: $veoProfile.profile.name)
                    .textContentType(.name)
                TextField("Email", text: $veoProfile.profile.email)
                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                TextField("Phone (optional)", text: $veoProfile.profile.phone)
                    .textContentType(.telephoneNumber).keyboardType(.phonePad)
                Text("Used only when you report a scooter/bike to Veo. Veo needs a name and email to follow up. No Denver account required.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
```

- [ ] **Step 2: Verify it compiles**

Run: `cd BikeLanes && xcodegen generate && xcodebuild build -project BikeLanes.xcodeproj -scheme BikeLanes -destination 'platform=iOS Simulator,id=48C6CFB0-C3E2-4EDD-B7CB-097B53BCE275' -quiet`
Expected: `BUILD SUCCEEDED` (after Task 15 updates the call sites, or update them here).

- [ ] **Step 3: Commit**

```bash
git add BikeLanes/BikeLanes/Views/SettingsView.swift
git commit -m "feat(veo): add Veo reporter profile section to Settings"
```

---

### Task 14: `ReportHomeView` chooser + remove banner from `ReportView`

**Files:**
- Create: `BikeLanes/BikeLanes/Views/Veo/ReportHomeView.swift`
- Modify: `BikeLanes/BikeLanes/Views/Report/ReportView.swift` (remove `OnboardingBanner()` and its trailing spacing)

**Interfaces:**
- Consumes: `OnboardingBanner`, `ReportView` (311), `VeoReportView` (11), `SettingsView` (13).
- Produces: `struct ReportHomeView: View` with `init(reportVM: ReportViewModel, veoVM: VeoReportViewModel, auth: AuthService?, veoProfile: VeoProfileStore)`; owns the `NavigationStack` (so `BikeLanesApp` no longer wraps `ReportView` in its own stack — see Task 15).

- [ ] **Step 1: Remove the banner from `ReportView`**

In `ReportView.body`, delete the `OnboardingBanner()` line (first child of the `VStack`). Leave the rest unchanged.

- [ ] **Step 2: Create `ReportHomeView`**

```swift
// BikeLanes/Views/Veo/ReportHomeView.swift
import SwiftUI

struct ReportHomeView: View {
    let reportVM: ReportViewModel
    let veoVM: VeoReportViewModel
    let auth: AuthService?
    let veoProfile: VeoProfileStore
    private let bg = Color(red: 250/255, green: 250/255, blue: 247/255)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    OnboardingBanner()
                    Text("What are you reporting?")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20).padding(.top, 4)

                    NavigationLink {
                        ReportView(vm: reportVM, auth: auth)
                    } label: {
                        chooserCard(icon: "car.fill", title: "Car in a bike lane",
                                    subtitle: "File a Denver 311 case (PocketGov sign-in required)")
                    }
                    NavigationLink {
                        VeoReportView(vm: veoVM)
                    } label: {
                        chooserCard(icon: "scooter", title: "Scooter or bike",
                                    subtitle: "Report to Veo — no account needed")
                    }
                }
                .padding(.vertical, 16)
            }
            .background(bg)
            .navigationTitle("Report")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView(auth: auth, veoProfile: veoProfile) } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }

    private func chooserCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 26))
                .foregroundStyle(Color(red: 42/255, green: 111/255, blue: 63/255))
                .frame(width: 52, height: 52)
                .background(Color(red: 239/255, green: 244/255, blue: 236/255))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color(red: 233/255, green: 229/255, blue: 218/255), lineWidth: 1))
        .padding(.horizontal, 20)
    }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `cd BikeLanes && xcodegen generate && xcodebuild build -project BikeLanes.xcodeproj -scheme BikeLanes -destination 'platform=iOS Simulator,id=48C6CFB0-C3E2-4EDD-B7CB-097B53BCE275' -quiet`
Expected: `BUILD SUCCEEDED` (once Task 15 wires it; if building standalone, may fail on the old `ReportView`-in-stack until Task 15 — acceptable, fix in 15).

- [ ] **Step 4: Commit**

```bash
git add BikeLanes/BikeLanes/Views/Veo/ReportHomeView.swift BikeLanes/BikeLanes/Views/Report/ReportView.swift
git commit -m "feat(veo): add ReportHomeView chooser; move welcome banner up"
```

---

### Task 15: App wiring in `BikeLanesApp`

**Files:**
- Modify: `BikeLanes/BikeLanes/App/BikeLanesApp.swift`

**Interfaces:**
- Consumes: `VeoReportViewModel` (9), `VeoReportClient` (8), `VeoAddressResolver` (6), `VeoProfileStore` (4), `ReportHomeView` (14).

- [ ] **Step 1: Build the Veo objects in `init` and store them**

Add stored properties and construct them:

```swift
    let reportVM: ReportViewModel
    let historyVM: HistoryViewModel
    let auth: AuthService
    let veoVM: VeoReportViewModel
    let veoProfile: VeoProfileStore
```

In `init`, after the existing setup, add:

```swift
        let veoStore = VeoProfileStore()
        self.veoProfile = veoStore
        self.veoVM = VeoReportViewModel(
            exif: ExifService(),
            resolver: VeoAddressResolver(),
            client: VeoReportClient(),
            profileStore: veoStore)
```

- [ ] **Step 2: Swap the Report tab to `ReportHomeView`**

Replace the Report tab in `body` (which currently wraps `ReportView` in a `NavigationStack`) with:

```swift
                ReportHomeView(reportVM: reportVM, veoVM: veoVM, auth: auth, veoProfile: veoProfile)
                    .tabItem { Label("Report", systemImage: "camera.viewfinder") }
```

(`ReportHomeView` owns its own `NavigationStack`, so do not wrap it in another.)

- [ ] **Step 3: Verify the whole app builds**

Run: `cd BikeLanes && xcodegen generate && xcodebuild build -project BikeLanes.xcodeproj -scheme BikeLanes -destination 'platform=iOS Simulator,id=48C6CFB0-C3E2-4EDD-B7CB-097B53BCE275' -quiet`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add BikeLanes/BikeLanes/App/BikeLanesApp.swift
git commit -m "feat(veo): wire Veo flow into app (ReportHomeView root + Veo VM)"
```

---

### Task 16: Full test + simulator smoke

**Files:** none (verification).

- [ ] **Step 1: Run the full unit-test suite**

Run: `cd BikeLanes && xcodegen generate && xcodebuild test -project BikeLanes.xcodeproj -scheme BikeLanes -destination 'platform=iOS Simulator,id=48C6CFB0-C3E2-4EDD-B7CB-097B53BCE275' -only-testing:BikeLanesTests`
Expected: all tests PASS (existing + new Veo tests).

- [ ] **Step 2: Launch in the simulator and verify the chooser + auth isolation**

```bash
APP=$(cd BikeLanes && xcodebuild -project BikeLanes.xcodeproj -scheme BikeLanes -configuration Debug -destination 'platform=iOS Simulator,id=48C6CFB0-C3E2-4EDD-B7CB-097B53BCE275' -derivedDataPath build build -quiet >/dev/null && echo BikeLanes/build/Build/Products/Debug-iphonesimulator/BikeLanes.app)
xcrun simctl install booted "$APP"
xcrun simctl launch booted ink.sam.bikelanes
xcrun simctl io booted screenshot /tmp/veo-home.png
```
Expected: Report tab shows the welcome card, then "What are you reporting?" with two cards. Tapping "Scooter or bike" opens the Veo form **without any sign-in prompt** (signed out).

- [ ] **Step 3: Final commit (if any doc/status updates)**

```bash
git add -A && git commit -m "chore(veo): verified full suite + simulator smoke" || echo "nothing to commit"
```

---

## Self-Review

**Spec coverage:**
- Chooser below welcome card → Task 14. ✅
- Separate Veo flow, shares photo+location plumbing → Tasks 9/11 reuse `ExifService`, `PhotoCard`, `CameraPicker`. ✅
- Location auto-fill via CLGeocoder (not Denver API) → Task 6/9. ✅
- Vehicle-number field + scan (live + from photo) → Tasks 5/10/11. ✅
- Saved Veo profile in Settings → Tasks 4/13. ✅
- Fire-and-forget + success confirmation → Task 11 (`VeoSuccessView`). ✅
- Auth isolation (no PocketGov gate) → Global Constraint + Task 9 test `testSubmitBuildsAndSendsWithoutAuth` + no `AuthService` in Veo files. ✅
- 3-call flow, 302=success, cookie reuse → Task 8. ✅
- Exact form encoding matches HAR → Task 7 tests. ✅
- Vehicle-type enum tags, yes/no tags, constants → Tasks 1/2/7. ✅

**Placeholder scan:** No TODO/TBD; all code steps include full code. ✅

**Type consistency:** `VeoSubmitting` methods, `VeoAttachment.rawJSON`, `VeoReportViewModel(exif:resolver:client:profileStore:)`, `VeoProfileStore(defaults:)`, `SubmitButton(title:captionOverride:)`, `ReportHomeView(reportVM:veoVM:auth:veoProfile:)`, `SettingsView(auth:veoProfile:)` are consistent across tasks. ✅
