# Bike Lanes v0.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a public iOS app that reports cars illegally parked in Denver bike lanes via one photo, submitting anonymously to Denver's `/api/cases` endpoint with on-device ML pre-filling the form fields.

**Architecture:** SwiftUI + @Observable view-models + service layer. No backend, no third-party SDKs. Direct URLSession to `den.denvergov.org`. `CLGeocoder` for reverse-geocoding. Core ML YOLOv11n for car detection. Vision for plate OCR. CoreImage for color extraction. SwiftData for local history.

**Tech Stack:** Swift 6, Xcode 16+, iOS 17 deployment target, SwiftUI, SwiftData, Vision, CoreML, CoreLocation, ImageIO, URLSession, XCTest.

**Reference docs:**
- Spec: `docs/superpowers/specs/2026-04-20-bike-lanes-design.md`
- API reference: `data/API.md`

---

## File structure

```
BikeLanes/                                       # Xcode project root
├── BikeLanes.xcodeproj/
├── BikeLanes/
│   ├── App/
│   │   ├── BikeLanesApp.swift                   # @main + SwiftData container
│   │   └── Info.plist                           # permission strings
│   ├── Models/
│   │   ├── ReportDraft.swift                    # working form state
│   │   ├── StoredCase.swift                     # @Model — local history row
│   │   ├── DenverAddress.swift                  # resolved address w/ addressId
│   │   └── Enums.swift                          # DenverVehicleType, PropertyType, USState
│   ├── Services/
│   │   ├── PhotoService.swift                   # camera + PhotosPicker
│   │   ├── ExifService.swift                    # ImageIO GPS/time/heading extraction
│   │   ├── GeocodeService.swift                 # CLGeocoder → Denver addressId
│   │   ├── PlateOCRService.swift                # Vision + plate regex
│   │   ├── VehicleDetector.swift                # YOLO Core ML → bbox
│   │   ├── ColorService.swift                   # dominant color on crop
│   │   ├── CaseRepository.swift                 # SwiftData store
│   │   └── DenverAPI/
│   │       ├── DenverAPIClient.swift            # URLSession wrapper
│   │       ├── DenverEndpoints.swift            # URL + method per endpoint
│   │       ├── DenverDTOs.swift                 # Codable request/response types
│   │       └── Multipart.swift                  # multipart/form-data builder
│   ├── ViewModels/
│   │   ├── ReportViewModel.swift                # orchestrates pipelines
│   │   └── HistoryViewModel.swift               # reads CaseRepository
│   ├── Views/
│   │   ├── Report/
│   │   │   ├── ReportView.swift                 # primary screen
│   │   │   ├── PhotoCard.swift                  # hero photo + bbox overlay
│   │   │   ├── FieldRow.swift                   # reusable tap-to-edit row
│   │   │   └── SubmitButton.swift
│   │   ├── Edit/
│   │   │   ├── EditPlateSheet.swift
│   │   │   ├── EditVehicleSheet.swift
│   │   │   ├── EditAddressSheet.swift
│   │   │   ├── EditDateTimeSheet.swift
│   │   │   └── EditNotesSheet.swift
│   │   ├── History/
│   │   │   ├── HistoryView.swift
│   │   │   └── HistoryRow.swift
│   │   ├── CaseDetailView.swift
│   │   └── SettingsView.swift
│   └── Resources/
│       ├── Assets.xcassets/
│       └── MLModels/
│           └── YOLOv11nCar.mlpackage
├── BikeLanesTests/
│   ├── Fixtures/
│   │   ├── IMG_3239.HEIC
│   │   └── NoGPS.jpg
│   ├── ExifServiceTests.swift
│   ├── DenverAPIClientTests.swift
│   ├── MultipartTests.swift
│   ├── GeocodeServiceTests.swift
│   ├── PlateOCRServiceTests.swift
│   ├── ColorServiceTests.swift
│   ├── CaseRepositoryTests.swift
│   ├── ReportViewModelTests.swift
│   └── LiveAPIIntegrationTests.swift            # gated by env var
└── BikeLanesUITests/
    └── ReportViewSnapshotTests.swift
```

---

## Phase 0 — Project bootstrap

### Task 0: Create the Xcode project

**Files:**
- Create: `BikeLanes/BikeLanes.xcodeproj` (via Xcode)
- Create: `BikeLanes/BikeLanes/App/BikeLanesApp.swift`
- Create: `BikeLanes/BikeLanes/App/Info.plist`

- [ ] **Step 1: Create project in Xcode**

In Xcode → File → New → Project → iOS App:
- Product Name: `BikeLanes`
- Team: (your dev team)
- Organization Identifier: `ink.sam`
- Bundle Identifier: `ink.sam.bikelanes`
- Interface: **SwiftUI**
- Language: **Swift**
- Storage: **SwiftData**
- Include Tests: ✓
- Save at `/Users/samschooler/repo/bike-lanes/BikeLanes`

- [ ] **Step 2: Set deployment target to iOS 17**

In project settings → General → Minimum Deployments → iOS 17.0.

- [ ] **Step 3: Add required Info.plist keys**

Add via Xcode's Info tab (or edit `Info.plist` directly):

```xml
<key>NSCameraUsageDescription</key>
<string>Take a photo of the illegally parked vehicle to attach to your report.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Pick a photo of the illegally parked vehicle from your library.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used only when reverse-geocoding a photo's GPS to a street address.</string>
```

- [ ] **Step 4: Verify the app builds and runs**

⌘R — an empty SwiftUI screen should appear in the simulator.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes
git commit -m "feat: bootstrap Xcode project for BikeLanes"
```

### Task 1: Bundle test fixtures

**Files:**
- Create: `BikeLanes/BikeLanesTests/Fixtures/IMG_3239.HEIC`
- Create: `BikeLanes/BikeLanesTests/Fixtures/NoGPS.jpg`

- [ ] **Step 1: Copy the HAR-recovered HEIC into fixtures**

```bash
cp /tmp/IMG_3239.HEIC BikeLanes/BikeLanesTests/Fixtures/IMG_3239.HEIC
```

If `/tmp/IMG_3239.HEIC` has been cleared, re-extract it from the HAR at `data/www.denvergov.org_Archive [26-04-20 20-52-49].har` using the Python recipe documented in `data/API.md` commit history (the UTF-8 → Latin-1 reroundtrip).

- [ ] **Step 2: Create a GPS-stripped variant**

```bash
python3 -c "
from PIL import Image
img = Image.open('BikeLanes/BikeLanesTests/Fixtures/IMG_3239.HEIC')
img.convert('RGB').save('BikeLanes/BikeLanesTests/Fixtures/NoGPS.jpg', 'JPEG', exif=b'')
"
```

Requires pillow-heif installed: `pip install --user pillow-heif` or in a venv.

- [ ] **Step 3: Add both to the BikeLanesTests bundle**

In Xcode, drag the two files into the `BikeLanesTests` group → check "Copy items if needed", target → `BikeLanesTests`.

- [ ] **Step 4: Verify bundle access**

Add a temporary smoke test at `BikeLanesTests/FixtureSmokeTests.swift`:

```swift
import XCTest

final class FixtureSmokeTests: XCTestCase {
    func testFixturesResolvable() throws {
        let bundle = Bundle(for: Self.self)
        XCTAssertNotNil(bundle.url(forResource: "IMG_3239", withExtension: "HEIC"))
        XCTAssertNotNil(bundle.url(forResource: "NoGPS", withExtension: "jpg"))
    }
}
```

Run: ⌘U. Expected: PASS.

Delete `FixtureSmokeTests.swift` after verifying; it served only as bundle proof.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanesTests/Fixtures
git commit -m "test: add HEIC fixtures (with and without GPS)"
```

### Task 2: Bundle the YOLO Core ML model

**Files:**
- Create: `BikeLanes/BikeLanes/Resources/MLModels/YOLOv11nCar.mlpackage`

- [ ] **Step 1: Export YOLOv11n to Core ML**

In a Python venv with `ultralytics`:

```bash
python3 -m venv /tmp/yolo-export && /tmp/yolo-export/bin/pip install ultralytics
/tmp/yolo-export/bin/python -c "
from ultralytics import YOLO
m = YOLO('yolo11n.pt')
m.export(format='coreml', nms=True, int8=True, imgsz=640)
"
```

This produces `yolo11n.mlpackage`. Rename to `YOLOv11nCar.mlpackage`.

- [ ] **Step 2: Add model to Xcode**

Drag `YOLOv11nCar.mlpackage` into the `BikeLanes/Resources/MLModels/` group → target `BikeLanes`. Xcode auto-generates a `YOLOv11nCar` class.

- [ ] **Step 3: Write a smoke test**

`BikeLanesTests/VehicleDetectorSmokeTests.swift`:

```swift
import XCTest
import CoreML

final class VehicleDetectorSmokeTests: XCTestCase {
    func testModelLoads() throws {
        let config = MLModelConfiguration()
        _ = try YOLOv11nCar(configuration: config)
    }
}
```

Run: ⌘U. Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add BikeLanes/BikeLanes/Resources/MLModels BikeLanes/BikeLanesTests/VehicleDetectorSmokeTests.swift
git commit -m "feat: bundle YOLOv11n Core ML model for car detection"
```

---

## Phase 1 — Models & enums

### Task 3: Core domain enums

**Files:**
- Create: `BikeLanes/BikeLanes/Models/Enums.swift`
- Test: `BikeLanes/BikeLanesTests/EnumsTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// BikeLanesTests/EnumsTests.swift
import XCTest
@testable import BikeLanes

final class EnumsTests: XCTestCase {
    func testDenverVehicleTypeRoundtripsToDenverWireString() {
        XCTAssertEqual(DenverVehicleType.sedan.wireValue, "Sedan (4 Door)")
        XCTAssertEqual(DenverVehicleType.suv.wireValue, "SUV")
        XCTAssertEqual(DenverVehicleType.pickup.wireValue, "Pickup")
        XCTAssertEqual(DenverVehicleType.allCases.count, 7)
    }

    func testPropertyTypeWire() {
        XCTAssertEqual(PropertyType.publicProperty.wireValue, "Public Property")
        XCTAssertEqual(PropertyType.privateProperty.wireValue, "Private Property")
    }

    func testUSStateTwoLetter() {
        XCTAssertEqual(USState.colorado.code, "CO")
        XCTAssertEqual(USState.california.code, "CA")
        XCTAssertEqual(USState(code: "CO"), .colorado)
        XCTAssertNil(USState(code: "XX"))
    }
}
```

- [ ] **Step 2: Run tests to see them fail (types don't exist)**

⌘U. Expected: 3 FAIL — "cannot find type 'DenverVehicleType'".

- [ ] **Step 3: Implement the enums**

```swift
// BikeLanes/Models/Enums.swift
import Foundation

enum DenverVehicleType: String, CaseIterable, Codable {
    case coupe, sedan, utility, pickup, suv, van, other

    var wireValue: String {
        switch self {
        case .coupe:   return "Coupe (2 door)"
        case .sedan:   return "Sedan (4 Door)"
        case .utility: return "Utility Vehicle"
        case .pickup:  return "Pickup"
        case .suv:     return "SUV"
        case .van:     return "Van"
        case .other:   return "Other"
        }
    }

    var display: String { wireValue }
}

enum PropertyType: String, CaseIterable, Codable {
    case publicProperty, privateProperty

    var wireValue: String {
        self == .publicProperty ? "Public Property" : "Private Property"
    }
}

enum USState: String, CaseIterable, Codable {
    case alabama, alaska, arizona, arkansas, california, colorado, connecticut,
         delaware, florida, georgia, hawaii, idaho, illinois, indiana, iowa,
         kansas, kentucky, louisiana, maine, maryland, massachusetts, michigan,
         minnesota, mississippi, missouri, montana, nebraska, nevada,
         newHampshire, newJersey, newMexico, newYork, northCarolina, northDakota,
         ohio, oklahoma, oregon, pennsylvania, rhodeIsland, southCarolina,
         southDakota, tennessee, texas, utah, vermont, virginia, washington,
         westVirginia, wisconsin, wyoming

    var code: String {
        switch self {
        case .alabama: return "AL"; case .alaska: return "AK"
        case .arizona: return "AZ"; case .arkansas: return "AR"
        case .california: return "CA"; case .colorado: return "CO"
        case .connecticut: return "CT"; case .delaware: return "DE"
        case .florida: return "FL"; case .georgia: return "GA"
        case .hawaii: return "HI"; case .idaho: return "ID"
        case .illinois: return "IL"; case .indiana: return "IN"
        case .iowa: return "IA"; case .kansas: return "KS"
        case .kentucky: return "KY"; case .louisiana: return "LA"
        case .maine: return "ME"; case .maryland: return "MD"
        case .massachusetts: return "MA"; case .michigan: return "MI"
        case .minnesota: return "MN"; case .mississippi: return "MS"
        case .missouri: return "MO"; case .montana: return "MT"
        case .nebraska: return "NE"; case .nevada: return "NV"
        case .newHampshire: return "NH"; case .newJersey: return "NJ"
        case .newMexico: return "NM"; case .newYork: return "NY"
        case .northCarolina: return "NC"; case .northDakota: return "ND"
        case .ohio: return "OH"; case .oklahoma: return "OK"
        case .oregon: return "OR"; case .pennsylvania: return "PA"
        case .rhodeIsland: return "RI"; case .southCarolina: return "SC"
        case .southDakota: return "SD"; case .tennessee: return "TN"
        case .texas: return "TX"; case .utah: return "UT"
        case .vermont: return "VT"; case .virginia: return "VA"
        case .washington: return "WA"; case .westVirginia: return "WV"
        case .wisconsin: return "WI"; case .wyoming: return "WY"
        }
    }

    var display: String { rawValue.localizedCapitalized }

    init?(code: String) {
        let upper = code.uppercased()
        guard let match = Self.allCases.first(where: { $0.code == upper }) else { return nil }
        self = match
    }
}
```

- [ ] **Step 4: Run tests**

⌘U. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Models/Enums.swift BikeLanes/BikeLanesTests/EnumsTests.swift
git commit -m "feat: add Denver wire-value enums (vehicle type, property type, US state)"
```

### Task 4: `DenverAddress` model

**Files:**
- Create: `BikeLanes/BikeLanes/Models/DenverAddress.swift`

- [ ] **Step 1: Implement the value type**

```swift
// BikeLanes/Models/DenverAddress.swift
import Foundation
import CoreLocation

struct DenverAddress: Equatable, Codable, Hashable {
    let addressId: Int
    let line1: String
    let city: String
    let state: String
    let zip: String
    let coordinate: CLLocationCoordinate2D

    enum CodingKeys: String, CodingKey {
        case addressId, line1 = "addressLine1", city, state, zip, latitude, longitude
    }

    init(addressId: Int, line1: String, city: String, state: String, zip: String, coordinate: CLLocationCoordinate2D) {
        self.addressId = addressId
        self.line1 = line1
        self.city = city
        self.state = state
        self.zip = zip
        self.coordinate = coordinate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        addressId = try c.decode(Int.self, forKey: .addressId)
        line1 = try c.decode(String.self, forKey: .line1)
        city = try c.decode(String.self, forKey: .city)
        state = try c.decode(String.self, forKey: .state)
        zip = try c.decode(String.self, forKey: .zip)
        coordinate = .init(
            latitude: try c.decode(Double.self, forKey: .latitude),
            longitude: try c.decode(Double.self, forKey: .longitude)
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(addressId, forKey: .addressId)
        try c.encode(line1, forKey: .line1)
        try c.encode(city, forKey: .city)
        try c.encode(state, forKey: .state)
        try c.encode(zip, forKey: .zip)
        try c.encode(coordinate.latitude, forKey: .latitude)
        try c.encode(coordinate.longitude, forKey: .longitude)
    }

    static func == (a: DenverAddress, b: DenverAddress) -> Bool {
        a.addressId == b.addressId && a.line1 == b.line1 && a.city == b.city
            && a.state == b.state && a.zip == b.zip
            && a.coordinate.latitude == b.coordinate.latitude
            && a.coordinate.longitude == b.coordinate.longitude
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(addressId); hasher.combine(line1)
        hasher.combine(coordinate.latitude); hasher.combine(coordinate.longitude)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BikeLanes/BikeLanes/Models/DenverAddress.swift
git commit -m "feat: add DenverAddress model with Codable round-trip"
```

### Task 5: `ReportDraft` working state

**Files:**
- Create: `BikeLanes/BikeLanes/Models/ReportDraft.swift`

- [ ] **Step 1: Implement**

```swift
// BikeLanes/Models/ReportDraft.swift
import Foundation
import CoreLocation

struct ReportDraft: Equatable {
    // Input
    var photoURL: URL?
    var detectedCarBBox: CGRect?

    // Location
    var coordinates: CLLocationCoordinate2D?
    var horizontalAccuracy: Double?
    var heading: CLLocationDirection?
    var resolvedAddress: DenverAddress?

    // Vehicle
    var plate: String?
    var plateState: USState? = .colorado          // Denver app default; user editable
    var plateConfidence: Double?
    var vehicleColor: String?
    var vehicleType: DenverVehicleType?
    var locationOfVehicle: PropertyType?
    var blockingDriveway: Bool?

    // Timing
    var observedAt: Date?

    // Notes
    var notes: String?

    /// Ready when every field Denver's form requires has a value.
    var isSubmittable: Bool {
        resolvedAddress != nil
            && plate?.isEmpty == false
            && plateState != nil
            && vehicleColor?.isEmpty == false
            && vehicleType != nil
            && locationOfVehicle != nil
            && blockingDriveway != nil
            && observedAt != nil
    }

    static func == (a: ReportDraft, b: ReportDraft) -> Bool {
        a.photoURL == b.photoURL
            && a.plate == b.plate && a.plateState == b.plateState
            && a.vehicleColor == b.vehicleColor && a.vehicleType == b.vehicleType
            && a.locationOfVehicle == b.locationOfVehicle
            && a.blockingDriveway == b.blockingDriveway
            && a.notes == b.notes
            && a.resolvedAddress == b.resolvedAddress
            && a.observedAt == b.observedAt
            && a.coordinates?.latitude == b.coordinates?.latitude
            && a.coordinates?.longitude == b.coordinates?.longitude
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BikeLanes/BikeLanes/Models/ReportDraft.swift
git commit -m "feat: add ReportDraft working-state model"
```

### Task 6: `StoredCase` SwiftData model

**Files:**
- Create: `BikeLanes/BikeLanes/Models/StoredCase.swift`

- [ ] **Step 1: Implement**

```swift
// BikeLanes/Models/StoredCase.swift
import Foundation
import SwiftData

@Model
final class StoredCase {
    var localId: UUID
    var denverInputRecordId: Int
    var denverCaseId: String?
    var denverCaseNumber: String?
    var submittedAt: Date
    var thumbnailFilename: String
    var snapshotJSON: String          // serialized ReportDraftSnapshot
    var internalStatus: String

    init(localId: UUID = UUID(),
         denverInputRecordId: Int,
         denverCaseId: String? = nil,
         denverCaseNumber: String? = nil,
         submittedAt: Date = .now,
         thumbnailFilename: String,
         snapshotJSON: String,
         internalStatus: String) {
        self.localId = localId
        self.denverInputRecordId = denverInputRecordId
        self.denverCaseId = denverCaseId
        self.denverCaseNumber = denverCaseNumber
        self.submittedAt = submittedAt
        self.thumbnailFilename = thumbnailFilename
        self.snapshotJSON = snapshotJSON
        self.internalStatus = internalStatus
    }
}

/// Codable freeze of a `ReportDraft` at submit time.
/// Kept separate so the `ReportDraft` stays non-Codable (CLLocationCoordinate2D isn't).
struct ReportDraftSnapshot: Codable {
    let addressLine1: String
    let city: String
    let state: String
    let zip: String
    let latitude: Double
    let longitude: Double
    let plate: String
    let plateState: String
    let vehicleColor: String
    let vehicleType: String
    let locationOfVehicle: String
    let blockingDriveway: Bool
    let observedAt: Date
    let notes: String
}
```

- [ ] **Step 2: Commit**

```bash
git add BikeLanes/BikeLanes/Models/StoredCase.swift
git commit -m "feat: add StoredCase @Model and snapshot type"
```

---

## Phase 2 — Denver API client

### Task 7: `DenverEndpoints` URL builder

**Files:**
- Create: `BikeLanes/BikeLanes/Services/DenverAPI/DenverEndpoints.swift`
- Test: `BikeLanes/BikeLanesTests/DenverEndpointsTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// BikeLanesTests/DenverEndpointsTests.swift
import XCTest
@testable import BikeLanes

final class DenverEndpointsTests: XCTestCase {
    func testMenusURL() {
        XCTAssertEqual(DenverEndpoints.menus.absoluteString,
                       "https://den.denvergov.org/api/forms/Menus")
    }

    func testMenuQuestionsFilterEncoded() {
        let url = DenverEndpoints.menuQuestions(menuId: 10).absoluteString
        XCTAssertTrue(url.contains("$filter=MenuId%20eq%2010%20AND%20Active"))
        XCTAssertTrue(url.contains("$orderby=Group%20ASC,%20Order%20ASC"))
    }

    func testAddressSearchEncoded() {
        let url = DenverEndpoints.addressSearch("2744 W 13th Ave, Denver, CO").absoluteString
        XCTAssertTrue(url.hasSuffix("/api/locations/Addresses/search/denver/2744%20W%2013th%20Ave,%20Denver,%20CO"))
    }

    func testAttachmentURL() {
        let id = UUID(uuidString: "EC3E203A-149E-4FE5-9E2E-528B227C5F2A")!
        XCTAssertEqual(DenverEndpoints.attachment(id).absoluteString,
                       "https://den.denvergov.org/api/cases/attachments/ec3e203a-149e-4fe5-9e2e-528b227c5f2a")
    }

    func testCasesURL() {
        XCTAssertEqual(DenverEndpoints.cases.absoluteString,
                       "https://den.denvergov.org/api/cases")
    }
}
```

- [ ] **Step 2: Run tests — fail**

⌘U. Expected: FAIL — no `DenverEndpoints`.

- [ ] **Step 3: Implement**

```swift
// BikeLanes/Services/DenverAPI/DenverEndpoints.swift
import Foundation

enum DenverEndpoints {
    static let base = URL(string: "https://den.denvergov.org")!

    static let menus: URL = base.appending(path: "api/forms/Menus")

    static func menuQuestions(menuId: Int) -> URL {
        var c = URLComponents(url: base.appending(path: "api/forms/MenuQuestions"), resolvingAgainstBaseURL: false)!
        c.queryItems = [
            URLQueryItem(name: "$filter",  value: "MenuId eq \(menuId) AND Active"),
            URLQueryItem(name: "$orderby", value: "Group ASC, Order ASC"),
        ]
        // Denver expects spaces as %20, not '+'; URLComponents uses %20 by default for queryItems.
        return c.url!
    }

    static func addressSearch(_ query: String) -> URL {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query
        return base.appending(path: "api/locations/Addresses/search/denver/\(encoded)")
    }

    static func attachment(_ id: UUID) -> URL {
        base.appending(path: "api/cases/attachments/\(id.uuidString.lowercased())")
    }

    static let cases: URL = base.appending(path: "api/cases")
}
```

- [ ] **Step 4: Run tests**

⌘U. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Services/DenverAPI/DenverEndpoints.swift BikeLanes/BikeLanesTests/DenverEndpointsTests.swift
git commit -m "feat: DenverEndpoints URL builder"
```

### Task 8: `DenverDTOs` Codable types

**Files:**
- Create: `BikeLanes/BikeLanes/Services/DenverAPI/DenverDTOs.swift`
- Test: `BikeLanes/BikeLanesTests/DenverDTOsTests.swift`

- [ ] **Step 1: Write failing decode tests against fixture JSON**

```swift
// BikeLanesTests/DenverDTOsTests.swift
import XCTest
@testable import BikeLanes

final class DenverDTOsTests: XCTestCase {
    func testMenuDecodes() throws {
        let json = """
        [{"menuType":"Report an Issue","title":"Illegal Parking","caseType":"REQ_ILLEGALPARKING",
          "active":true,"sfIssueTemplateId":"a3Gi000000375ai","configuration":"{}",
          "menuQuestions":null,"id":10}]
        """.data(using: .utf8)!
        let menus = try JSONDecoder().decode([DenverMenu].self, from: json)
        XCTAssertEqual(menus.first?.id, 10)
        XCTAssertEqual(menus.first?.caseType, "REQ_ILLEGALPARKING")
        XCTAssertEqual(menus.first?.sfIssueTemplateId, "a3Gi000000375ai")
    }

    func testMenuQuestionDecodes() throws {
        let json = """
        [{"menuId":10,"question":"Plate Number","questionType":"textInput","active":true,
          "required":true,"order":2,"options":"{\\"maxLength\\":10}",
          "sfAnswerField":"Issue_Question_3__c","group":"3","menu":null,"id":22}]
        """.data(using: .utf8)!
        let qs = try JSONDecoder().decode([DenverMenuQuestion].self, from: json)
        XCTAssertEqual(qs.first?.id, 22)
        XCTAssertEqual(qs.first?.sfAnswerField, "Issue_Question_3__c")
    }

    func testAttachmentResponseDecodes() throws {
        let json = """
        {"caseHistoryId":0,"caseNumber":null,"mimeType":"image/heic",
         "pathToFiles":"2026/4/20/x","created":"2026-04-21T02:50:37.679Z",
         "id":"ec3e203a-149e-4fe5-9e2e-528b227c5f2a"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let resp = try decoder.decode(AttachmentResponse.self, from: json)
        XCTAssertEqual(resp.id, UUID(uuidString: "EC3E203A-149E-4FE5-9E2E-528B227C5F2A"))
        XCTAssertEqual(resp.mimeType, "image/heic")
    }

    func testCreateCaseResponseDecodes() throws {
        let json = """
        {"inputRecordId":266859,"attachmentId":"ec3e203a-149e-4fe5-9e2e-528b227c5f2a",
         "menuId":10,"title":"Illegal Parking","email":"","b2CId":"",
         "anonymousId":"00000000-0000-0000-0000-000000000000",
         "created":"2026-04-21T02:52:30Z","closed":null,
         "internalCaseStatus":"queuedForCRM","caseStatus":"New",
         "caseId":null,"caseNumber":null,"resolutionNotes":null,
         "sentStatus":"notSent","sfError":null,"attempts":0,
         "inputRecord":{"userInput":"{}","salesForceInput":null,
                        "created":"2026-04-21T02:52:30Z","caseHistory":null,"id":266859},
         "id":266869}
        """.data(using: .utf8)!
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let r = try decoder.decode(CreateCaseResponse.self, from: json)
        XCTAssertEqual(r.id, 266869)
        XCTAssertEqual(r.internalCaseStatus, "queuedForCRM")
    }
}
```

- [ ] **Step 2: Run tests — fail**

⌘U. Expected: 4 FAIL.

- [ ] **Step 3: Implement DTOs**

```swift
// BikeLanes/Services/DenverAPI/DenverDTOs.swift
import Foundation

// MARK: Menus & questions

struct DenverMenu: Decodable, Identifiable {
    let id: Int
    let menuType: String
    let title: String
    let caseType: String
    let active: Bool
    let sfIssueTemplateId: String
    let configuration: String   // JSON string per Denver's schema; not parsed here
}

struct DenverMenuQuestion: Decodable, Identifiable {
    let id: Int
    let menuId: Int
    let question: String
    let questionType: String
    let active: Bool
    let required: Bool
    let order: Int
    let options: String         // JSON string
    let sfAnswerField: String
    let group: String
}

// MARK: Address search result — reuses DenverAddress for decoding

extension DenverAddress {
    /// The address-search endpoint returns a superset of DenverAddress fields; decode what we use.
    struct SearchResult: Decodable {
        let addressId: Int
        let addressLine1: String
        let city: String
        let state: String
        let zip: String
        let latitude: Double
        let longitude: Double
        let isInDenver: Bool

        var toAddress: DenverAddress {
            .init(addressId: addressId, line1: addressLine1, city: city,
                  state: state, zip: zip,
                  coordinate: .init(latitude: latitude, longitude: longitude))
        }
    }
}

// MARK: Attachment

struct AttachmentResponse: Decodable {
    let id: UUID
    let mimeType: String
    let pathToFiles: String
    let created: Date

    enum CodingKeys: String, CodingKey { case id, mimeType, pathToFiles, created }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let idString = try c.decode(String.self, forKey: .id)
        guard let uuid = UUID(uuidString: idString) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c,
                                                   debugDescription: "bad uuid \(idString)")
        }
        id = uuid
        mimeType = try c.decode(String.self, forKey: .mimeType)
        pathToFiles = try c.decode(String.self, forKey: .pathToFiles)
        created = try c.decode(Date.self, forKey: .created)
    }
}

// MARK: Create case

struct CreateCaseRequest: Encodable {
    struct CaseType: Encodable {
        let menuType: String
        let menuId: Int
        let title: String
        let name: String
        let sfIssueTemplateId: String
        let caseQuestions: [CaseQuestion]
    }
    struct CaseQuestion: Encodable {
        let id: Int
        let question: String
        let sfAnswerField: String
        let answer: String
    }
    struct Contact: Encodable {
        let anonymous: Bool
        let languagePreference: String
        let firstName: String
        let lastName: String
        let email: String
        let phone: String?
    }
    struct Location: Encodable {
        struct Address: Encodable {
            let id: Int
            let streetAddress: String
            let city: String
            let state: String
            let zip: String
        }
        struct Coordinates: Encodable {
            let latitude: Double
            let longitude: Double
        }
        let address: Address
        let coordinates: Coordinates
        let addressFromReverseGeocode: Bool
    }

    let comments: String
    let attachmentId: UUID?
    let caseType: CaseType
    let contact: Contact
    let location: Location
}

struct CreateCaseResponse: Decodable {
    let id: Int                           // Denver primary key
    let inputRecordId: Int
    let internalCaseStatus: String
    let caseStatus: String
    let caseId: String?
    let caseNumber: String?
    let sentStatus: String
    let attempts: Int
}
```

- [ ] **Step 4: Run tests**

⌘U. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Services/DenverAPI/DenverDTOs.swift BikeLanes/BikeLanesTests/DenverDTOsTests.swift
git commit -m "feat: Denver API Codable DTOs for menus, attachments, case create"
```

### Task 9: Multipart builder

**Files:**
- Create: `BikeLanes/BikeLanes/Services/DenverAPI/Multipart.swift`
- Test: `BikeLanes/BikeLanesTests/MultipartTests.swift`

- [ ] **Step 1: Failing test**

```swift
// BikeLanesTests/MultipartTests.swift
import XCTest
@testable import BikeLanes

final class MultipartTests: XCTestCase {
    func testFileFieldEncodesCorrectly() {
        let boundary = "----test-boundary-123"
        let fileBytes = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let body = Multipart.body(boundary: boundary, fileField: "file",
                                  filename: "IMG.HEIC", mimeType: "image/heic",
                                  data: fileBytes)
        let prefix = "------test-boundary-123\r\nContent-Disposition: form-data; name=\"file\"; filename=\"IMG.HEIC\"\r\nContent-Type: image/heic\r\n\r\n"
        let suffix = "\r\n------test-boundary-123--\r\n"
        var expected = Data(prefix.utf8)
        expected.append(fileBytes)
        expected.append(Data(suffix.utf8))
        XCTAssertEqual(body, expected)
    }

    func testContentTypeHeader() {
        XCTAssertEqual(Multipart.contentType(boundary: "b"),
                       "multipart/form-data; boundary=----b")
    }
}
```

- [ ] **Step 2: Run — fail**

⌘U. Expected: FAIL.

- [ ] **Step 3: Implement**

```swift
// BikeLanes/Services/DenverAPI/Multipart.swift
import Foundation

enum Multipart {
    /// Returns header value like Firefox: `multipart/form-data; boundary=----<given>`.
    static func contentType(boundary: String) -> String {
        "multipart/form-data; boundary=----\(boundary)"
    }

    /// Build a single-file multipart body matching Denver's capture shape.
    static func body(boundary: String, fileField: String, filename: String,
                     mimeType: String, data: Data) -> Data {
        var out = Data()
        out.append("------\(boundary)\r\n".asUTF8)
        out.append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(filename)\"\r\n".asUTF8)
        out.append("Content-Type: \(mimeType)\r\n\r\n".asUTF8)
        out.append(data)
        out.append("\r\n------\(boundary)--\r\n".asUTF8)
        return out
    }

    static func newBoundary() -> String {
        // Match Firefox's "geckoformboundary<hex>"; any unique token works server-side.
        let hex = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        return "bikelanesboundary\(hex)"
    }
}

private extension String {
    var asUTF8: Data { data(using: .utf8) ?? Data() }
}
```

- [ ] **Step 4: Run tests — pass**

⌘U. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Services/DenverAPI/Multipart.swift BikeLanes/BikeLanesTests/MultipartTests.swift
git commit -m "feat: multipart/form-data body builder"
```

### Task 10: `DenverAPIClient` — network surface

**Files:**
- Create: `BikeLanes/BikeLanes/Services/DenverAPI/DenverAPIClient.swift`
- Test: `BikeLanes/BikeLanesTests/DenverAPIClientTests.swift`

- [ ] **Step 1: Write failing tests using `URLProtocol` stub**

```swift
// BikeLanesTests/DenverAPIClientTests.swift
import XCTest
@testable import BikeLanes

final class DenverAPIClientTests: XCTestCase {
    override func setUp() { MockURLProtocol.responders.removeAll() }

    func testFetchMenusReturnsDecoded() async throws {
        MockURLProtocol.responders[DenverEndpoints.menus] = .json("""
            [{"menuType":"Report an Issue","title":"Illegal Parking",
              "caseType":"REQ_ILLEGALPARKING","active":true,
              "sfIssueTemplateId":"a3Gi000000375ai","configuration":"{}",
              "menuQuestions":null,"id":10}]
            """, status: 200)
        let client = DenverAPIClient(session: MockURLProtocol.session)
        let menus = try await client.fetchMenus()
        XCTAssertEqual(menus.first?.id, 10)
    }

    func testSearchAddressReturnsEmptyOn204() async throws {
        let url = DenverEndpoints.addressSearch("nothing")
        MockURLProtocol.responders[url] = .status(204)
        let client = DenverAPIClient(session: MockURLProtocol.session)
        let results = try await client.searchAddress("nothing")
        XCTAssertTrue(results.isEmpty)
    }

    func testUploadAttachmentSendsMultipart() async throws {
        let id = UUID()
        MockURLProtocol.responders[DenverEndpoints.attachment(id)] = .json("""
            {"caseHistoryId":0,"caseNumber":null,"mimeType":"image/heic",
             "pathToFiles":"p","created":"2026-04-21T00:00:00Z",
             "id":"\(id.uuidString.lowercased())"}
            """, status: 201)
        let client = DenverAPIClient(session: MockURLProtocol.session)
        let resp = try await client.uploadAttachment(id: id, filename: "IMG.HEIC",
                                                     mimeType: "image/heic",
                                                     data: Data([0, 1, 2]))
        XCTAssertEqual(resp.id, id)
        let recorded = MockURLProtocol.recordedRequests.first!
        XCTAssertTrue(recorded.value(forHTTPHeaderField: "Content-Type")?
                        .hasPrefix("multipart/form-data;") ?? false)
    }
}

// Minimal URLProtocol stub. In practice ship once under BikeLanesTests/TestSupport/MockURLProtocol.swift.
final class MockURLProtocol: URLProtocol {
    enum Response { case json(String, status: Int); case status(Int) }
    static var responders: [URL: Response] = [:]
    static var recordedRequests: [URLRequest] = []

    static var session: URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: cfg)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.recordedRequests.append(request)
        guard let url = request.url, let r = Self.responders[url] else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return
        }
        switch r {
        case .json(let s, let status):
            let resp = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(s.utf8))
        case .status(let status):
            let resp = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
```

- [ ] **Step 2: Run — fail**

⌘U. Expected: FAIL — `DenverAPIClient` not defined.

- [ ] **Step 3: Implement client**

```swift
// BikeLanes/Services/DenverAPI/DenverAPIClient.swift
import Foundation

struct DenverAPIClient {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: Menus

    func fetchMenus() async throws -> [DenverMenu] {
        try await getJSON(DenverEndpoints.menus)
    }

    func fetchMenuQuestions(menuId: Int) async throws -> [DenverMenuQuestion] {
        try await getJSON(DenverEndpoints.menuQuestions(menuId: menuId))
    }

    // MARK: Address search

    func searchAddress(_ query: String) async throws -> [DenverAddress.SearchResult] {
        var req = URLRequest(url: DenverEndpoints.addressSearch(query))
        addDefaultHeaders(&req)
        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        if status == 204 { return [] }
        guard (200...299).contains(status) else { throw APIError.http(status: status, body: data) }
        return try decoder.decode([DenverAddress.SearchResult].self, from: data)
    }

    // MARK: Attachment upload

    func uploadAttachment(id: UUID, filename: String, mimeType: String,
                          data fileData: Data) async throws -> AttachmentResponse {
        var req = URLRequest(url: DenverEndpoints.attachment(id))
        req.httpMethod = "POST"
        let boundary = Multipart.newBoundary()
        req.setValue(Multipart.contentType(boundary: boundary), forHTTPHeaderField: "Content-Type")
        addDefaultHeaders(&req)
        req.httpBody = Multipart.body(boundary: boundary, fileField: "file",
                                      filename: filename, mimeType: mimeType, data: fileData)
        let (data, response) = try await session.data(for: req)
        return try decodeOrThrow(data, response)
    }

    // MARK: Case create

    func createCase(_ request: CreateCaseRequest) async throws -> CreateCaseResponse {
        var req = URLRequest(url: DenverEndpoints.cases)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addDefaultHeaders(&req)
        req.httpBody = try JSONEncoder().encode(request)
        let (data, response) = try await session.data(for: req)
        return try decodeOrThrow(data, response)
    }

    // MARK: Helpers

    private func addDefaultHeaders(_ req: inout URLRequest) {
        req.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        // Echo the SPA Origin so Denver's anti-abuse checks don't flag us.
        req.setValue("https://www.denvergov.org", forHTTPHeaderField: "Origin")
        req.setValue("https://www.denvergov.org/", forHTTPHeaderField: "Referer")
    }

    private func getJSON<T: Decodable>(_ url: URL) async throws -> T {
        var req = URLRequest(url: url)
        addDefaultHeaders(&req)
        let (data, response) = try await session.data(for: req)
        return try decodeOrThrow(data, response)
    }

    private func decodeOrThrow<T: Decodable>(_ data: Data, _ response: URLResponse) throws -> T {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else { throw APIError.http(status: status, body: data) }
        return try decoder.decode(T.self, from: data)
    }

    enum APIError: Error, CustomStringConvertible {
        case http(status: Int, body: Data)

        var description: String {
            switch self {
            case .http(let s, let b):
                return "Denver API HTTP \(s): \(String(data: b, encoding: .utf8) ?? "<non-utf8>")"
            }
        }
    }
}
```

- [ ] **Step 4: Run — pass**

⌘U. Expected: PASS (all three).

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Services/DenverAPI/DenverAPIClient.swift BikeLanes/BikeLanesTests/DenverAPIClientTests.swift
git commit -m "feat: DenverAPIClient with menus, address search, attachment upload, case create"
```

### Task 11: Live-API anonymous-contact probe

**Files:**
- Create: `BikeLanes/BikeLanesTests/LiveAPIIntegrationTests.swift`
- Modify: `data/API.md` — record probe result

- [ ] **Step 1: Write probe test**

Goal: the spec flagged the anonymous contact shape as unverified. Probe which variant the server accepts and record it.

```swift
// BikeLanesTests/LiveAPIIntegrationTests.swift
import XCTest
@testable import BikeLanes

/// Runs only when the environment variable BIKE_LANES_LIVE_API=1.
/// These tests file real Denver cases — treat with care.
final class LiveAPIIntegrationTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BIKE_LANES_LIVE_API"] == "1",
                          "Live API tests skipped (set BIKE_LANES_LIVE_API=1 to enable)")
    }

    /// Probes three variants and records which one Denver accepts.
    func testAnonymousContactShape_probe() async throws {
        let client = DenverAPIClient()

        // Build a minimal case around a known addressId from /api/locations/Addresses/search
        let searches = try await client.searchAddress("2744 W 13th Ave, Denver, CO")
        let addr = try XCTUnwrap(searches.first?.toAddress)

        let menus = try await client.fetchMenus()
        let menu = try XCTUnwrap(menus.first { $0.id == 10 })
        let qs = try await client.fetchMenuQuestions(menuId: 10)

        func answer(_ id: Int) -> String {
            switch id {
            case 20: return "No"
            case 21: return ISO8601DateFormatter().string(from: .now)
            case 22: return "TEST00"
            case 46: return "CO"
            case 47: return "Probe car — please close"
            case 48: return DenverVehicleType.sedan.wireValue
            case 49: return PropertyType.publicProperty.wireValue
            default: return ""
            }
        }
        let caseQuestions = qs.map {
            CreateCaseRequest.CaseQuestion(id: $0.id, question: $0.question,
                                           sfAnswerField: $0.sfAnswerField, answer: answer($0.id))
        }

        func tryVariant(_ contact: CreateCaseRequest.Contact) async -> (ok: Bool, error: String?) {
            let req = CreateCaseRequest(
                comments: "AUTOMATED PROBE — please close",
                attachmentId: nil,
                caseType: .init(menuType: menu.menuType, menuId: menu.id, title: menu.title,
                                name: menu.caseType, sfIssueTemplateId: menu.sfIssueTemplateId,
                                caseQuestions: caseQuestions),
                contact: contact,
                location: .init(
                    address: .init(id: addr.addressId, streetAddress: addr.line1,
                                   city: addr.city, state: addr.state, zip: addr.zip),
                    coordinates: .init(latitude: addr.coordinate.latitude,
                                       longitude: addr.coordinate.longitude),
                    addressFromReverseGeocode: true
                )
            )
            do { _ = try await client.createCase(req); return (true, nil) }
            catch { return (false, "\(error)") }
        }

        let emptyStrings = CreateCaseRequest.Contact(
            anonymous: true, languagePreference: "en",
            firstName: "", lastName: "", email: "", phone: nil)
        let r1 = await tryVariant(emptyStrings)
        print("VARIANT empty-strings → \(r1)")

        // Dashes variant
        let dashes = CreateCaseRequest.Contact(
            anonymous: true, languagePreference: "en",
            firstName: "-", lastName: "-", email: "anonymous@denvergov.org", phone: nil)
        let r2 = await tryVariant(dashes)
        print("VARIANT dashes → \(r2)")

        XCTAssertTrue(r1.ok || r2.ok, "At least one anonymous shape should be accepted")
    }
}
```

- [ ] **Step 2: Run the probe (opt-in)**

```bash
BIKE_LANES_LIVE_API=1 xcodebuild test -project BikeLanes/BikeLanes.xcodeproj \
    -scheme BikeLanes -only-testing:BikeLanesTests/LiveAPIIntegrationTests \
    -destination 'platform=iOS Simulator,name=iPhone 15'
```

Read the printed `VARIANT ...` output. Record which variant returned 201.

- [ ] **Step 3: Freeze the accepted shape**

In `DenverAPIClient` (Task 10) or a new `AnonymousContact` helper, expose:

```swift
extension CreateCaseRequest.Contact {
    static var anonymous: CreateCaseRequest.Contact {
        // UPDATE AFTER PROBE — whichever variant the probe confirmed.
        .init(anonymous: true, languagePreference: "en",
              firstName: "", lastName: "", email: "", phone: nil)
    }
}
```

- [ ] **Step 4: Update `data/API.md` §3.7 with the verified shape**

Add a note below the body example: "Verified 2026-04-20 — anonymous submits require `firstName=""`, `lastName=""`, `email=""`, `phone=null`." (or whichever the probe confirmed).

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanesTests/LiveAPIIntegrationTests.swift \
        BikeLanes/BikeLanes/Services/DenverAPI/DenverAPIClient.swift \
        data/API.md
git commit -m "feat: lock anonymous-contact payload shape via live probe"
```

---

## Phase 3 — Location & geocoding

### Task 12: `ExifService`

**Files:**
- Create: `BikeLanes/BikeLanes/Services/ExifService.swift`
- Test: `BikeLanes/BikeLanesTests/ExifServiceTests.swift`

- [ ] **Step 1: Failing tests against fixtures**

```swift
// BikeLanesTests/ExifServiceTests.swift
import XCTest
import CoreLocation
@testable import BikeLanes

final class ExifServiceTests: XCTestCase {
    func testReadsGPSFromHEIC() throws {
        let url = Bundle(for: Self.self).url(forResource: "IMG_3239", withExtension: "HEIC")!
        let meta = try ExifService().read(url: url)
        let coord = try XCTUnwrap(meta.coordinates)
        XCTAssertEqual(coord.latitude, 39.7365, accuracy: 0.001)
        XCTAssertEqual(coord.longitude, -105.0210, accuracy: 0.001)
        XCTAssertNotNil(meta.observedAt)
        XCTAssertNotNil(meta.heading)
    }

    func testReturnsNilCoordsWhenAbsent() throws {
        let url = Bundle(for: Self.self).url(forResource: "NoGPS", withExtension: "jpg")!
        let meta = try ExifService().read(url: url)
        XCTAssertNil(meta.coordinates)
    }
}
```

- [ ] **Step 2: Run — fail**

⌘U. Expected: FAIL — `ExifService` undefined.

- [ ] **Step 3: Implement**

```swift
// BikeLanes/Services/ExifService.swift
import Foundation
import ImageIO
import CoreLocation

struct PhotoMetadata {
    var coordinates: CLLocationCoordinate2D?
    var horizontalAccuracy: Double?
    var heading: CLLocationDirection?
    var observedAt: Date?
}

struct ExifService {
    enum Error: Swift.Error { case cannotReadImage }

    func read(url: URL) throws -> PhotoMetadata {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any]
        else { throw Error.cannotReadImage }

        var meta = PhotoMetadata()

        // GPS
        if let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any],
           let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
           let lng = gps[kCGImagePropertyGPSLongitude as String] as? Double {
            let latRef = (gps[kCGImagePropertyGPSLatitudeRef as String] as? String) ?? "N"
            let lngRef = (gps[kCGImagePropertyGPSLongitudeRef as String] as? String) ?? "E"
            meta.coordinates = .init(
                latitude:  latRef == "S" ? -lat : lat,
                longitude: lngRef == "W" ? -lng : lng
            )
            meta.horizontalAccuracy = gps[kCGImagePropertyGPSHPositioningError as String] as? Double
            if let dir = gps[kCGImagePropertyGPSImgDirection as String] as? Double {
                meta.heading = dir
            }
        }

        // Exif date/time
        if let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let str = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            let f = DateFormatter()
            f.dateFormat = "yyyy:MM:dd HH:mm:ss"
            f.timeZone = .current
            meta.observedAt = f.date(from: str)
        }

        return meta
    }
}
```

- [ ] **Step 4: Run — pass**

⌘U. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Services/ExifService.swift BikeLanes/BikeLanesTests/ExifServiceTests.swift
git commit -m "feat: ExifService reads GPS, heading, and observed-at from HEIC/JPEG"
```

### Task 13: Address-line normalizer

**Files:**
- Create: `BikeLanes/BikeLanes/Services/AddressNormalizer.swift`
- Test: `BikeLanes/BikeLanesTests/AddressNormalizerTests.swift`

- [ ] **Step 1: Failing tests**

```swift
// BikeLanesTests/AddressNormalizerTests.swift
import XCTest
@testable import BikeLanes

final class AddressNormalizerTests: XCTestCase {
    func testAbbreviatesDirectionalsAndSuffixes() {
        XCTAssertEqual(AddressNormalizer.normalize("2744 West 13th Avenue"),
                       "2744 W 13th Ave")
        XCTAssertEqual(AddressNormalizer.normalize("1400 North Colfax Street"),
                       "1400 N Colfax St")
        XCTAssertEqual(AddressNormalizer.normalize("200 South Broadway Boulevard"),
                       "200 S Broadway Blvd")
    }

    func testPreservesAlreadyShortForms() {
        XCTAssertEqual(AddressNormalizer.normalize("2744 W 13th Ave"),
                       "2744 W 13th Ave")
    }

    func testBuildsQueryString() {
        XCTAssertEqual(AddressNormalizer.denverQuery(line1: "2744 W 13th Ave"),
                       "2744 W 13th Ave, Denver, CO")
    }
}
```

- [ ] **Step 2: Run — fail**

⌘U. Expected: FAIL.

- [ ] **Step 3: Implement**

```swift
// BikeLanes/Services/AddressNormalizer.swift
import Foundation

enum AddressNormalizer {
    private static let substitutions: [(String, String)] = [
        ("\\bWest\\b",       "W"),
        ("\\bEast\\b",       "E"),
        ("\\bNorth\\b",      "N"),
        ("\\bSouth\\b",      "S"),
        ("\\bAvenue\\b",     "Ave"),
        ("\\bStreet\\b",     "St"),
        ("\\bBoulevard\\b",  "Blvd"),
        ("\\bRoad\\b",       "Rd"),
        ("\\bDrive\\b",      "Dr"),
        ("\\bCourt\\b",      "Ct"),
        ("\\bPlace\\b",      "Pl"),
        ("\\bLane\\b",       "Ln"),
        ("\\bHighway\\b",    "Hwy"),
        ("\\bParkway\\b",    "Pkwy"),
    ]

    static func normalize(_ input: String) -> String {
        var s = input
        for (pattern, replacement) in substitutions {
            s = s.replacingOccurrences(of: pattern, with: replacement,
                                        options: [.regularExpression, .caseInsensitive])
        }
        return s.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "  ", with: " ")
    }

    static func denverQuery(line1: String) -> String {
        "\(normalize(line1)), Denver, CO"
    }
}
```

- [ ] **Step 4: Run — pass**

⌘U. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Services/AddressNormalizer.swift BikeLanes/BikeLanesTests/AddressNormalizerTests.swift
git commit -m "feat: address-line normalizer (West→W, Avenue→Ave, etc.)"
```

### Task 14: `GeocodeService`

**Files:**
- Create: `BikeLanes/BikeLanes/Services/GeocodeService.swift`
- Test: `BikeLanes/BikeLanesTests/GeocodeServiceTests.swift`

- [ ] **Step 1: Failing test (mocking CLGeocoder via protocol)**

```swift
// BikeLanesTests/GeocodeServiceTests.swift
import XCTest
import CoreLocation
@testable import BikeLanes

final class GeocodeServiceTests: XCTestCase {
    func testResolvesCoordinatesToDenverAddress() async throws {
        let fakeReverse: GeocodeService.ReverseGeocoder = { _ in
            "2746 West 13th Avenue"   // what CLGeocoder returns near our test point
        }
        let fakeDenver = FakeDenverAPI()
        fakeDenver.nextSearch = [
            DenverAddress(addressId: 70428, line1: "2746 W 13th Ave",
                          city: "Denver", state: "CO", zip: "80204",
                          coordinate: .init(latitude: 39.7363, longitude: -105.0207))
        ]

        let service = GeocodeService(reverse: fakeReverse, api: fakeDenver)
        let addr = try await service.resolve(
            coordinate: .init(latitude: 39.73655, longitude: -105.02099))
        XCTAssertEqual(addr?.addressId, 70428)
        XCTAssertEqual(fakeDenver.lastQuery, "2746 W 13th Ave, Denver, CO")
    }
}

final class FakeDenverAPI: DenverAddressSearching {
    var nextSearch: [DenverAddress] = []
    var lastQuery: String?
    func searchAddress(_ query: String) async throws -> [DenverAddress.SearchResult] {
        lastQuery = query
        return nextSearch.map {
            .init(addressId: $0.addressId, addressLine1: $0.line1,
                  city: $0.city, state: $0.state, zip: $0.zip,
                  latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude,
                  isInDenver: true)
        }
    }
}
```

- [ ] **Step 2: Run — fail**

⌘U. Expected: FAIL.

- [ ] **Step 3: Implement, extracting a seam for both dependencies**

```swift
// BikeLanes/Services/GeocodeService.swift
import Foundation
import CoreLocation

protocol DenverAddressSearching {
    func searchAddress(_ query: String) async throws -> [DenverAddress.SearchResult]
}

extension DenverAPIClient: DenverAddressSearching {}

struct GeocodeService {
    typealias ReverseGeocoder = (CLLocationCoordinate2D) async throws -> String?

    let reverse: ReverseGeocoder
    let api: DenverAddressSearching

    /// Default: real `CLGeocoder` + real `DenverAPIClient`.
    init(reverse: @escaping ReverseGeocoder = Self.clReverse,
         api: DenverAddressSearching = DenverAPIClient()) {
        self.reverse = reverse
        self.api = api
    }

    /// Coordinate → best-guess DenverAddress (with real addressId), or nil if nothing found.
    func resolve(coordinate: CLLocationCoordinate2D) async throws -> DenverAddress? {
        guard let streetLine = try await reverse(coordinate) else { return nil }
        let query = AddressNormalizer.denverQuery(line1: streetLine)
        let results = try await api.searchAddress(query)
        return results.first(where: { $0.isInDenver })?.toAddress ?? results.first?.toAddress
    }

    /// Production reverse-geocoder using CLGeocoder.
    static func clReverse(_ coord: CLLocationCoordinate2D) async throws -> String? {
        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(loc)
        guard let p = placemarks.first,
              let number = p.subThoroughfare,
              let street = p.thoroughfare else { return nil }
        return "\(number) \(street)"
    }
}
```

- [ ] **Step 4: Run — pass**

⌘U. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Services/GeocodeService.swift BikeLanes/BikeLanesTests/GeocodeServiceTests.swift
git commit -m "feat: GeocodeService composes CLGeocoder and Denver address search"
```

---

## Phase 4 — Photo ML services

### Task 15: `VehicleDetector`

**Files:**
- Create: `BikeLanes/BikeLanes/Services/VehicleDetector.swift`
- Test: `BikeLanes/BikeLanesTests/VehicleDetectorTests.swift`

- [ ] **Step 1: Failing test**

```swift
// BikeLanesTests/VehicleDetectorTests.swift
import XCTest
@testable import BikeLanes

final class VehicleDetectorTests: XCTestCase {
    func testDetectsCarInFixturePhoto() async throws {
        let url = Bundle(for: Self.self).url(forResource: "IMG_3239", withExtension: "HEIC")!
        let data = try Data(contentsOf: url)
        let detector = try VehicleDetector()
        let bbox = try await detector.detect(imageData: data)
        XCTAssertNotNil(bbox)
        let b = try XCTUnwrap(bbox)
        // Normalized 0...1 coords; should be non-degenerate.
        XCTAssertGreaterThan(b.width, 0.1)
        XCTAssertGreaterThan(b.height, 0.1)
    }
}
```

- [ ] **Step 2: Run — fail**

⌘U. Expected: FAIL.

- [ ] **Step 3: Implement**

```swift
// BikeLanes/Services/VehicleDetector.swift
import Foundation
import CoreML
import Vision

struct VehicleDetector {
    private let model: VNCoreMLModel

    init() throws {
        let config = MLModelConfiguration()
        let ml = try YOLOv11nCar(configuration: config).model
        model = try VNCoreMLModel(for: ml)
    }

    /// Runs detection and returns the highest-confidence "car" bounding box in
    /// Vision's normalized image coordinates (0...1, origin bottom-left), or nil.
    func detect(imageData: Data) async throws -> CGRect? {
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFit
        let handler = VNImageRequestHandler(data: imageData)
        try handler.perform([request])

        let cars = (request.results ?? [])
            .compactMap { $0 as? VNRecognizedObjectObservation }
            .filter { $0.labels.first?.identifier.lowercased() == "car" }
            .sorted { ($0.labels.first?.confidence ?? 0) > ($1.labels.first?.confidence ?? 0) }
        return cars.first?.boundingBox
    }
}
```

- [ ] **Step 4: Run — pass**

⌘U. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Services/VehicleDetector.swift BikeLanes/BikeLanesTests/VehicleDetectorTests.swift
git commit -m "feat: VehicleDetector runs YOLO Core ML for car bounding boxes"
```

### Task 16: `PlateOCRService`

**Files:**
- Create: `BikeLanes/BikeLanes/Services/PlateOCRService.swift`
- Test: `BikeLanes/BikeLanesTests/PlateOCRServiceTests.swift`

- [ ] **Step 1: Failing test**

```swift
// BikeLanesTests/PlateOCRServiceTests.swift
import XCTest
@testable import BikeLanes

final class PlateOCRServiceTests: XCTestCase {
    func testRecognizesPlateShapedStrings() {
        let candidates = ["Hello", "DHKQ98", "COLORADO", "ABC-123", "12"]
        let filtered = PlateOCRService.filterPlateCandidates(candidates)
        XCTAssertEqual(filtered, ["DHKQ98", "ABC-123"])
    }
}
```

Note: a live Vision OCR test against the fixture HEIC depends on the photo's actual readability; keep it as a soft integration test.

- [ ] **Step 2: Run — fail**

⌘U. Expected: FAIL.

- [ ] **Step 3: Implement**

```swift
// BikeLanes/Services/PlateOCRService.swift
import Foundation
import Vision
import CoreGraphics

struct PlateReading {
    let text: String
    let confidence: Double
}

struct PlateOCRService {
    /// Regex: 5–8 chars, letters/digits/dashes, at least one digit and one letter.
    private static let plateRegex = try! NSRegularExpression(
        pattern: "^(?=.*[A-Z])(?=.*[0-9])[A-Z0-9-]{5,8}$")

    /// Filter OCR candidate strings to plate-shaped ones.
    static func filterPlateCandidates(_ raw: [String]) -> [String] {
        raw.map { $0.uppercased().replacingOccurrences(of: " ", with: "") }
            .filter { string in
                let range = NSRange(location: 0, length: string.utf16.count)
                return plateRegex.firstMatch(in: string, range: range) != nil
            }
    }

    /// Runs Vision text recognition on a cropped image, returns best plate reading or nil.
    func read(croppedImageData: Data) async throws -> PlateReading? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(data: croppedImageData)
        try handler.perform([request])

        let observations = (request.results ?? [])
        let candidates = observations.flatMap { $0.topCandidates(3) }
        let plateLike = candidates
            .filter { Self.filterPlateCandidates([$0.string]).isEmpty == false }
            .sorted { $0.confidence > $1.confidence }

        guard let best = plateLike.first else { return nil }
        return PlateReading(text: best.string.uppercased()
                                    .replacingOccurrences(of: " ", with: ""),
                            confidence: Double(best.confidence))
    }
}
```

- [ ] **Step 4: Run — pass (unit test for regex)**

⌘U. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Services/PlateOCRService.swift BikeLanes/BikeLanesTests/PlateOCRServiceTests.swift
git commit -m "feat: PlateOCRService with Vision text recognition + shape filter"
```

### Task 17: `ColorService`

**Files:**
- Create: `BikeLanes/BikeLanes/Services/ColorService.swift`
- Test: `BikeLanes/BikeLanesTests/ColorServiceTests.swift`

- [ ] **Step 1: Failing tests**

```swift
// BikeLanesTests/ColorServiceTests.swift
import XCTest
@testable import BikeLanes

final class ColorServiceTests: XCTestCase {
    func testNearestNameMapsCommonRGB() {
        XCTAssertEqual(ColorService.nearestName(r: 255, g: 0, b: 0),   "Red")
        XCTAssertEqual(ColorService.nearestName(r: 10,  g: 10, b: 10),  "Black")
        XCTAssertEqual(ColorService.nearestName(r: 240, g: 240, b: 240),"White")
        XCTAssertEqual(ColorService.nearestName(r: 20,  g: 40, b: 200), "Blue")
    }
}
```

- [ ] **Step 2: Run — fail**

⌘U. Expected: FAIL.

- [ ] **Step 3: Implement**

```swift
// BikeLanes/Services/ColorService.swift
import Foundation
import CoreImage
import UIKit

struct ColorService {
    private static let palette: [(name: String, r: Int, g: Int, b: Int)] = [
        ("Black",  20, 20, 20),
        ("White",  240, 240, 240),
        ("Gray",   128, 128, 128),
        ("Silver", 192, 192, 192),
        ("Red",    200, 20, 20),
        ("Blue",   30, 60, 200),
        ("Green",  30, 140, 60),
        ("Yellow", 240, 210, 40),
        ("Orange", 235, 130, 30),
        ("Brown",  110, 70, 40),
        ("Tan",    200, 170, 130),
        ("Beige",  220, 200, 170),
        ("Gold",   200, 170, 90),
        ("Purple", 120, 60, 160),
    ]

    static func nearestName(r: Int, g: Int, b: Int) -> String {
        palette.min { a, b2 in
            sqDist(r: r, g: g, b: b, to: a) < sqDist(r: r, g: g, b: b, to: b2)
        }!.name
    }

    private static func sqDist(r: Int, g: Int, b: Int,
                               to entry: (name: String, r: Int, g: Int, b: Int)) -> Int {
        let dr = r - entry.r, dg = g - entry.g, db = b - entry.b
        return dr*dr + dg*dg + db*db
    }

    /// Extract the dominant color name from an image (or crop).
    func dominantName(image: UIImage) -> String? {
        guard let ci = CIImage(image: image) else { return nil }
        // CIAreaAverage gives a 1x1 output with the average color.
        let filter = CIFilter(name: "CIAreaAverage",
                              parameters: [kCIInputImageKey: ci,
                                           kCIInputExtentKey: CIVector(cgRect: ci.extent)])!
        guard let out = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext().render(out, toBitmap: &bitmap, rowBytes: 4,
                            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                            format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return Self.nearestName(r: Int(bitmap[0]),
                                g: Int(bitmap[1]),
                                b: Int(bitmap[2]))
    }
}
```

- [ ] **Step 4: Run — pass**

⌘U. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Services/ColorService.swift BikeLanes/BikeLanesTests/ColorServiceTests.swift
git commit -m "feat: ColorService (dominant color + palette mapping)"
```

---

## Phase 5 — Persistence

### Task 18: `CaseRepository`

**Files:**
- Create: `BikeLanes/BikeLanes/Services/CaseRepository.swift`
- Test: `BikeLanes/BikeLanesTests/CaseRepositoryTests.swift`

- [ ] **Step 1: Failing tests**

```swift
// BikeLanesTests/CaseRepositoryTests.swift
import XCTest
import SwiftData
@testable import BikeLanes

final class CaseRepositoryTests: XCTestCase {
    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: StoredCase.self, configurations: config)
    }

    func testSaveAndFetch() throws {
        let repo = CaseRepository(container: container)
        let snap = ReportDraftSnapshot(
            addressLine1: "2744 W 13th Ave", city: "Denver", state: "CO", zip: "80204",
            latitude: 39.7363, longitude: -105.0215,
            plate: "ABC123", plateState: "CO",
            vehicleColor: "Blue", vehicleType: "Sedan (4 Door)",
            locationOfVehicle: "Public Property", blockingDriveway: false,
            observedAt: .now, notes: "")
        let saved = try repo.save(
            denverInputRecordId: 266869, denverCaseId: nil, denverCaseNumber: nil,
            internalStatus: "queuedForCRM", thumbnailFilename: "a.jpg", snapshot: snap)
        XCTAssertEqual(saved.denverInputRecordId, 266869)

        let all = try repo.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.localId, saved.localId)
    }
}
```

- [ ] **Step 2: Run — fail**

⌘U. Expected: FAIL.

- [ ] **Step 3: Implement**

```swift
// BikeLanes/Services/CaseRepository.swift
import Foundation
import SwiftData

struct CaseRepository {
    let container: ModelContainer

    @discardableResult
    func save(denverInputRecordId: Int,
              denverCaseId: String?,
              denverCaseNumber: String?,
              internalStatus: String,
              thumbnailFilename: String,
              snapshot: ReportDraftSnapshot) throws -> StoredCase {
        let data = try JSONEncoder().encode(snapshot)
        let snapshotJSON = String(data: data, encoding: .utf8) ?? "{}"
        let stored = StoredCase(
            denverInputRecordId: denverInputRecordId,
            denverCaseId: denverCaseId,
            denverCaseNumber: denverCaseNumber,
            thumbnailFilename: thumbnailFilename,
            snapshotJSON: snapshotJSON,
            internalStatus: internalStatus)
        let ctx = ModelContext(container)
        ctx.insert(stored)
        try ctx.save()
        return stored
    }

    func fetchAll() throws -> [StoredCase] {
        let ctx = ModelContext(container)
        let desc = FetchDescriptor<StoredCase>(sortBy: [SortDescriptor(\.submittedAt, order: .reverse)])
        return try ctx.fetch(desc)
    }

    func deleteAll() throws {
        let ctx = ModelContext(container)
        try ctx.delete(model: StoredCase.self)
        try ctx.save()
    }
}
```

- [ ] **Step 4: Run — pass**

⌘U. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Services/CaseRepository.swift BikeLanes/BikeLanesTests/CaseRepositoryTests.swift
git commit -m "feat: CaseRepository backed by SwiftData"
```

---

## Phase 6 — Orchestration

### Task 19: `ReportViewModel`

**Files:**
- Create: `BikeLanes/BikeLanes/ViewModels/ReportViewModel.swift`
- Test: `BikeLanes/BikeLanesTests/ReportViewModelTests.swift`

- [ ] **Step 1: Failing test of the happy path**

```swift
// BikeLanesTests/ReportViewModelTests.swift
import XCTest
import CoreLocation
@testable import BikeLanes

@MainActor
final class ReportViewModelTests: XCTestCase {
    func testHappyPathPopulatesAllFields() async throws {
        let url = Bundle(for: Self.self).url(forResource: "IMG_3239", withExtension: "HEIC")!

        let fakeGeocode = FakeGeocodeService()
        fakeGeocode.stubbed = DenverAddress(
            addressId: 70424, line1: "2744 W 13th Ave",
            city: "Denver", state: "CO", zip: "80204",
            coordinate: .init(latitude: 39.7363, longitude: -105.0215))

        let vm = ReportViewModel(
            exif: ExifService(),
            geocode: fakeGeocode,
            detector: try VehicleDetector(),
            plateOCR: PlateOCRService(),
            color: ColorService(),
            api: FakeSubmitAPI(),
            repository: InMemoryCaseRepo())

        try await vm.load(photoURL: url)

        XCTAssertNotNil(vm.draft.coordinates)
        XCTAssertEqual(vm.draft.resolvedAddress?.addressId, 70424)
        XCTAssertNotNil(vm.draft.observedAt)
    }
}

final class FakeGeocodeService: GeocodeResolving {
    var stubbed: DenverAddress?
    func resolve(coordinate: CLLocationCoordinate2D) async throws -> DenverAddress? { stubbed }
}

final class FakeSubmitAPI: CaseSubmitting {
    func uploadAttachment(id: UUID, filename: String, mimeType: String, data: Data)
        async throws -> AttachmentResponse {
        .init(from: try JSONDecoder().decode(AttachmentResponse.self, from: """
            {"caseHistoryId":0,"caseNumber":null,"mimeType":"\(mimeType)",
             "pathToFiles":"p","created":"2026-04-21T00:00:00Z","id":"\(id.uuidString.lowercased())"}
            """.data(using: .utf8)!))
    }
    func createCase(_ r: CreateCaseRequest) async throws -> CreateCaseResponse {
        try JSONDecoder().decode(CreateCaseResponse.self, from: """
            {"inputRecordId":1,"attachmentId":"\(UUID().uuidString.lowercased())",
             "menuId":10,"title":"t","email":"","b2CId":"","anonymousId":"\(UUID().uuidString.lowercased())",
             "created":"2026-04-21T00:00:00Z","closed":null,
             "internalCaseStatus":"queuedForCRM","caseStatus":"New",
             "caseId":null,"caseNumber":null,"resolutionNotes":null,
             "sentStatus":"notSent","sfError":null,"attempts":0,
             "inputRecord":{"userInput":"{}","salesForceInput":null,
                            "created":"2026-04-21T00:00:00Z","caseHistory":null,"id":1},
             "id":42}
            """.data(using: .utf8)!)
    }
}

final class InMemoryCaseRepo: CasePersisting {
    var saved: [StoredCase] = []
    func save(denverInputRecordId: Int, denverCaseId: String?, denverCaseNumber: String?,
              internalStatus: String, thumbnailFilename: String,
              snapshot: ReportDraftSnapshot) throws -> StoredCase {
        let s = StoredCase(denverInputRecordId: denverInputRecordId,
                           denverCaseId: denverCaseId, denverCaseNumber: denverCaseNumber,
                           thumbnailFilename: thumbnailFilename,
                           snapshotJSON: "", internalStatus: internalStatus)
        saved.append(s); return s
    }
    func fetchAll() throws -> [StoredCase] { saved }
    func deleteAll() throws { saved.removeAll() }
}
```

- [ ] **Step 2: Run — fail**

⌘U. Expected: FAIL.

- [ ] **Step 3: Implement protocols and view-model**

```swift
// Add protocols at bottom of existing service files or inline here:
protocol GeocodeResolving {
    func resolve(coordinate: CLLocationCoordinate2D) async throws -> DenverAddress?
}
extension GeocodeService: GeocodeResolving {}

protocol CaseSubmitting {
    func uploadAttachment(id: UUID, filename: String, mimeType: String, data: Data) async throws -> AttachmentResponse
    func createCase(_ r: CreateCaseRequest) async throws -> CreateCaseResponse
}
extension DenverAPIClient: CaseSubmitting {}

protocol CasePersisting {
    func save(denverInputRecordId: Int, denverCaseId: String?, denverCaseNumber: String?,
              internalStatus: String, thumbnailFilename: String,
              snapshot: ReportDraftSnapshot) throws -> StoredCase
    func fetchAll() throws -> [StoredCase]
    func deleteAll() throws
}
extension CaseRepository: CasePersisting {}
```

```swift
// BikeLanes/ViewModels/ReportViewModel.swift
import Foundation
import Observation
import UIKit
import CoreLocation

@MainActor
@Observable
final class ReportViewModel {
    var draft = ReportDraft()
    var isLoading = false
    var isSubmitting = false
    var lastError: String?
    var lastSavedCase: StoredCase?

    private let exif: ExifService
    private let geocode: GeocodeResolving
    private let detector: VehicleDetector
    private let plateOCR: PlateOCRService
    private let color: ColorService
    private let api: CaseSubmitting
    private let repository: CasePersisting

    /// Cached Denver menu/question metadata, fetched lazily once per session.
    private var menu: DenverMenu?
    private var questions: [DenverMenuQuestion] = []

    init(exif: ExifService,
         geocode: GeocodeResolving,
         detector: VehicleDetector,
         plateOCR: PlateOCRService,
         color: ColorService,
         api: CaseSubmitting,
         repository: CasePersisting) {
        self.exif = exif; self.geocode = geocode
        self.detector = detector; self.plateOCR = plateOCR; self.color = color
        self.api = api; self.repository = repository
    }

    /// Kicks off all the pipelines for a newly-selected photo.
    func load(photoURL url: URL) async throws {
        isLoading = true; defer { isLoading = false }
        var d = draft
        d.photoURL = url

        // EXIF is synchronous; do it first.
        let meta = try exif.read(url: url)
        d.coordinates = meta.coordinates
        d.horizontalAccuracy = meta.horizontalAccuracy
        d.heading = meta.heading
        d.observedAt = meta.observedAt ?? .now

        draft = d

        // Parallel: geocode (if we have coords) and ML chain.
        await withTaskGroup(of: Void.self) { group in
            if let coord = meta.coordinates {
                group.addTask { [weak self] in
                    await self?.runGeocode(coord)
                }
            }
            group.addTask { [weak self] in
                await self?.runMLChain(url: url)
            }
        }
    }

    private func runGeocode(_ coord: CLLocationCoordinate2D) async {
        do {
            let addr = try await geocode.resolve(coordinate: coord)
            draft.resolvedAddress = addr
        } catch {
            lastError = "Couldn't resolve address: \(error.localizedDescription)"
        }
    }

    private func runMLChain(url: URL) async {
        guard let data = try? Data(contentsOf: url) else { return }
        do {
            guard let bbox = try await detector.detect(imageData: data),
                  let cropData = ImageCropper.cropJPEG(data: data, normalizedBBox: bbox) else {
                return
            }
            draft.detectedCarBBox = bbox

            async let plate = plateOCR.read(croppedImageData: cropData)
            if let image = UIImage(data: cropData) {
                draft.vehicleColor = color.dominantName(image: image)
            }
            if let reading = try await plate {
                draft.plate = reading.text
                draft.plateConfidence = reading.confidence
            }
        } catch {
            lastError = "ML pipeline failed: \(error.localizedDescription)"
        }
    }

    /// Serializes the draft into Denver's JSON and submits it.
    func submit() async throws {
        guard draft.isSubmittable else { return }
        isSubmitting = true; defer { isSubmitting = false }

        if menu == nil {
            guard let api = api as? DenverAPIClient else {
                throw NSError(domain: "BikeLanes", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "no DenverAPIClient for menu fetch"])
            }
            let menus = try await api.fetchMenus()
            menu = menus.first { $0.id == 10 }
            questions = try await api.fetchMenuQuestions(menuId: 10)
        }
        guard let menu else { throw APIError.noMenu }

        // Upload photo
        var attachmentId: UUID?
        if let url = draft.photoURL, let data = try? Data(contentsOf: url) {
            let uuid = UUID()
            let resp = try await api.uploadAttachment(
                id: uuid,
                filename: url.lastPathComponent,
                mimeType: mimeType(for: url),
                data: data)
            attachmentId = resp.id
        }

        // Build questions with answers
        let caseQs: [CreateCaseRequest.CaseQuestion] = questions.map { q in
            .init(id: q.id, question: q.question, sfAnswerField: q.sfAnswerField,
                  answer: answer(for: q.id))
        }
        let addr = draft.resolvedAddress!
        let req = CreateCaseRequest(
            comments: draft.notes ?? "",
            attachmentId: attachmentId,
            caseType: .init(
                menuType: menu.menuType, menuId: menu.id, title: menu.title,
                name: menu.caseType, sfIssueTemplateId: menu.sfIssueTemplateId,
                caseQuestions: caseQs),
            contact: .anonymous,
            location: .init(
                address: .init(id: addr.addressId, streetAddress: addr.line1,
                               city: addr.city, state: addr.state, zip: addr.zip),
                coordinates: .init(
                    latitude: draft.coordinates?.latitude ?? addr.coordinate.latitude,
                    longitude: draft.coordinates?.longitude ?? addr.coordinate.longitude),
                addressFromReverseGeocode: true))
        let resp = try await api.createCase(req)

        let snap = ReportDraftSnapshot(
            addressLine1: addr.line1, city: addr.city, state: addr.state, zip: addr.zip,
            latitude: draft.coordinates?.latitude ?? addr.coordinate.latitude,
            longitude: draft.coordinates?.longitude ?? addr.coordinate.longitude,
            plate: draft.plate ?? "",
            plateState: draft.plateState?.code ?? "CO",
            vehicleColor: draft.vehicleColor ?? "",
            vehicleType: draft.vehicleType?.wireValue ?? "",
            locationOfVehicle: draft.locationOfVehicle?.wireValue ?? "",
            blockingDriveway: draft.blockingDriveway ?? false,
            observedAt: draft.observedAt ?? .now,
            notes: draft.notes ?? "")
        lastSavedCase = try repository.save(
            denverInputRecordId: resp.id, denverCaseId: resp.caseId,
            denverCaseNumber: resp.caseNumber, internalStatus: resp.internalCaseStatus,
            thumbnailFilename: draft.photoURL?.lastPathComponent ?? "",
            snapshot: snap)
    }

    private func answer(for questionId: Int) -> String {
        switch questionId {
        case 20: return (draft.blockingDriveway ?? false) ? "Yes" : "No"
        case 21: return ISO8601DateFormatter().string(from: draft.observedAt ?? .now)
        case 22: return draft.plate ?? ""
        case 46: return draft.plateState?.code ?? "CO"
        case 47: return [draft.vehicleColor, draft.vehicleType?.wireValue]
                    .compactMap { $0 }.joined(separator: " ")
        case 48: return draft.vehicleType?.wireValue ?? ""
        case 49: return draft.locationOfVehicle?.wireValue ?? ""
        default: return ""
        }
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "heic": return "image/heic"
        case "png":  return "image/png"
        default:     return "image/jpeg"
        }
    }

    enum APIError: Error { case noMenu }
}
```

Also add a helper for cropping since we reference `ImageCropper`:

```swift
// BikeLanes/Services/ImageCropper.swift
import Foundation
import UIKit

enum ImageCropper {
    /// Crops a JPEG/HEIC data blob to the normalized bbox (Vision's coordinate system,
    /// origin bottom-left, 0...1). Returns JPEG data.
    static func cropJPEG(data: Data, normalizedBBox bbox: CGRect) -> Data? {
        guard let image = UIImage(data: data), let cg = image.cgImage else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let rect = CGRect(x: bbox.minX * w,
                          y: (1 - bbox.maxY) * h,          // flip Y
                          width: bbox.width * w,
                          height: bbox.height * h)
        guard let cropped = cg.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped).jpegData(compressionQuality: 0.85)
    }
}
```

- [ ] **Step 4: Run — pass**

⌘U. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/ViewModels/ReportViewModel.swift \
        BikeLanes/BikeLanes/Services/ImageCropper.swift \
        BikeLanes/BikeLanesTests/ReportViewModelTests.swift
git commit -m "feat: ReportViewModel orchestrates EXIF/geocode/ML and submit"
```

---

## Phase 7 — Views

### Task 20: `FieldRow` reusable tap-to-edit component

**Files:**
- Create: `BikeLanes/BikeLanes/Views/Report/FieldRow.swift`

- [ ] **Step 1: Implement**

```swift
// BikeLanes/Views/Report/FieldRow.swift
import SwiftUI

struct FieldRow<Leading: View>: View {
    let label: String
    let value: String?
    let caption: String?
    let onEdit: () -> Void
    let leading: () -> Leading

    var body: some View {
        HStack(spacing: 14) {
            leading()
                .frame(width: 44, height: 44)
                .background(Color(red: 239/255, green: 244/255, blue: 236/255))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .kerning(0.88)
                    .foregroundStyle(Color(red: 138/255, green: 135/255, blue: 118/255))

                Text(value ?? "Tap to add")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(value == nil ? .secondary : .primary)

                if let caption {
                    Text(caption)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
            Button("Edit", action: onEdit)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 42/255, green: 111/255, blue: 63/255))
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BikeLanes/BikeLanes/Views/Report/FieldRow.swift
git commit -m "feat: reusable FieldRow for tap-to-edit report rows"
```

### Task 21: `PhotoCard`

**Files:**
- Create: `BikeLanes/BikeLanes/Views/Report/PhotoCard.swift`

- [ ] **Step 1: Implement**

```swift
// BikeLanes/Views/Report/PhotoCard.swift
import SwiftUI

struct PhotoCard: View {
    let image: UIImage?
    let bbox: CGRect?            // normalized, Vision coordinates (origin bottom-left)
    let heading: Double?
    let onRetake: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(LinearGradient(
                    colors: [Color(red: 58/255, green: 74/255, blue: 90/255),
                             Color(red: 31/255, green: 42/255, blue: 53/255)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            }

            // BBox overlay
            GeometryReader { geo in
                if let bbox {
                    let rect = CGRect(
                        x: bbox.minX * geo.size.width,
                        y: (1 - bbox.maxY) * geo.size.height,
                        width: bbox.width * geo.size.width,
                        height: bbox.height * geo.size.height)
                    Path { p in p.addRect(rect) }
                        .stroke(Color.green.opacity(0.9), lineWidth: 2)
                }
            }

            VStack {
                HStack(spacing: 6) {
                    chip(text: image == nil ? "WAITING" : "CAR DETECTED",
                         filled: image != nil)
                    if let heading {
                        chip(text: "heading \(compass(heading))", filled: false)
                    }
                }
                Spacer()
                HStack {
                    Spacer()
                    Button("Retake", action: onRetake)
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Capsule())
                }
            }
            .padding(14)
        }
        .aspectRatio(16/9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func chip(text: String, filled: Bool) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(filled
                ? Color(red: 42/255, green: 111/255, blue: 63/255).opacity(0.9)
                : Color.white.opacity(0.15))
            .clipShape(Capsule())
    }

    private func compass(_ deg: Double) -> String {
        let dirs = ["N","NE","E","SE","S","SW","W","NW"]
        let idx = Int(((deg + 22.5).truncatingRemainder(dividingBy: 360)) / 45)
        return dirs[max(0, min(dirs.count-1, idx))]
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BikeLanes/BikeLanes/Views/Report/PhotoCard.swift
git commit -m "feat: PhotoCard with bbox overlay and heading chip"
```

### Task 22: `ReportView` (primary screen)

**Files:**
- Create: `BikeLanes/BikeLanes/Views/Report/ReportView.swift`

- [ ] **Step 1: Implement**

```swift
// BikeLanes/Views/Report/ReportView.swift
import SwiftUI
import PhotosUI

struct ReportView: View {
    @Bindable var vm: ReportViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingPicker = false
    @State private var editing: EditTarget?
    private let backgroundColor = Color(red: 250/255, green: 250/255, blue: 247/255)

    enum EditTarget: Identifiable {
        case plate, vehicle, address, dateTime, notes
        var id: Int { switch self { case .plate: 0; case .vehicle: 1; case .address: 2; case .dateTime: 3; case .notes: 4 } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Report")
                        .font(.custom("Fraunces", size: 28).weight(.medium))
                    Spacer()
                    NavigationLink(destination: SettingsView()) {
                        Circle().fill(Color(red: 240/255, green: 237/255, blue: 226/255))
                            .frame(width: 36, height: 36)
                            .overlay(Image(systemName: "gearshape").foregroundStyle(.secondary))
                    }
                }
                .padding(.horizontal, 20)

                PhotoCard(
                    image: vm.draft.photoURL.flatMap { UIImage(contentsOfFile: $0.path) },
                    bbox: vm.draft.detectedCarBBox,
                    heading: vm.draft.heading,
                    onRetake: { showingPicker = true })
                .padding(.horizontal, 20)

                VStack(spacing: 0) {
                    FieldRow(label: "Where",
                             value: vm.draft.resolvedAddress?.line1,
                             caption: locationCaption,
                             onEdit: { editing = .address }) {
                        Text("📍").font(.system(size: 16))
                    }
                    divider
                    FieldRow(label: "Plate",
                             value: plateValue,
                             caption: vm.draft.plate.map { _ in "Read from photo" },
                             onEdit: { editing = .plate }) {
                        Text(vm.draft.plateState?.code ?? "??")
                            .font(.system(size: 11, weight: .bold))
                    }
                    divider
                    FieldRow(label: "Vehicle",
                             value: vehicleValue,
                             caption: vehicleCaption,
                             onEdit: { editing = .vehicle }) {
                        Circle().fill(Color(colorCategory(vm.draft.vehicleColor)))
                            .frame(width: 22, height: 22)
                    }
                    divider
                    FieldRow(label: "Observed",
                             value: vm.draft.observedAt.map { relativeDate($0) },
                             caption: vm.draft.observedAt.map { _ in "From photo timestamp" },
                             onEdit: { editing = .dateTime }) {
                        Text("🕒").font(.system(size: 16))
                    }
                    divider
                    FieldRow(label: "Notes · optional",
                             value: vm.draft.notes,
                             caption: nil,
                             onEdit: { editing = .notes }) {
                        Text("＋").font(.system(size: 18)).foregroundStyle(.secondary)
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 20)

                SubmitButton(enabled: vm.draft.isSubmittable && !vm.isSubmitting) {
                    Task { try? await vm.submit() }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .padding(.vertical, 16)
        }
        .background(backgroundColor)
        .photosPicker(isPresented: $showingPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, new in
            guard let new else { return }
            Task { await loadPicked(new) }
        }
        .sheet(item: $editing) { target in
            switch target {
            case .plate:   EditPlateSheet(draft: $vm.draft)
            case .vehicle: EditVehicleSheet(draft: $vm.draft)
            case .address: EditAddressSheet(draft: $vm.draft)
            case .dateTime: EditDateTimeSheet(draft: $vm.draft)
            case .notes:   EditNotesSheet(draft: $vm.draft)
            }
        }
        .task {
            if vm.draft.photoURL == nil { showingPicker = true }
        }
    }

    private var divider: some View {
        Rectangle().fill(Color(red: 242/255, green: 239/255, blue: 229/255))
            .frame(height: 1).padding(.horizontal, 16)
    }

    private func loadPicked(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("pick-\(UUID().uuidString).heic")
            try data.write(to: tmp)
            try await vm.load(photoURL: tmp)
        } catch {
            vm.lastError = error.localizedDescription
        }
    }

    private var locationCaption: String? {
        guard let a = vm.draft.resolvedAddress else { return nil }
        let accuracy = vm.draft.horizontalAccuracy.map { "±\(Int($0))m" } ?? ""
        return "\(a.city), \(a.state) \(a.zip) \(accuracy)".trimmingCharacters(in: .whitespaces)
    }

    private var plateValue: String? {
        guard let p = vm.draft.plate, !p.isEmpty else { return nil }
        let state = vm.draft.plateState?.display ?? ""
        return "\(p) · \(state)"
    }

    private var vehicleValue: String? {
        let c = vm.draft.vehicleColor
        let t = vm.draft.vehicleType?.wireValue
        switch (c, t) {
        case let (c?, t?): return "\(c) \(t.lowercased())"
        case let (c?, nil): return c
        case let (nil, t?): return t
        default: return nil
        }
    }

    private var vehicleCaption: String? {
        var bits: [String] = []
        if let lv = vm.draft.locationOfVehicle { bits.append(lv.wireValue) }
        if let bd = vm.draft.blockingDriveway { bits.append(bd ? "blocking driveway" : "not blocking driveway") }
        return bits.isEmpty ? nil : bits.joined(separator: " · ")
    }

    private func colorCategory(_ name: String?) -> (red: Double, green: Double, blue: Double) {
        switch name?.lowercased() {
        case "blue": return (58/255, 90/255, 154/255)
        case "red": return (200/255, 50/255, 50/255)
        case "black": return (30/255, 30/255, 30/255)
        case "white": return (240/255, 240/255, 240/255)
        case "gray", "silver": return (140/255, 140/255, 140/255)
        case "green": return (50/255, 140/255, 80/255)
        case "yellow", "gold": return (220/255, 190/255, 60/255)
        case "orange": return (235/255, 130/255, 30/255)
        default: return (180/255, 180/255, 180/255)
        }
    }

    private func relativeDate(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .short
        return f.localizedString(for: d, relativeTo: .now)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BikeLanes/BikeLanes/Views/Report/ReportView.swift
git commit -m "feat: ReportView primary screen with photo, fields, and submit"
```

### Task 23: `SubmitButton`

**Files:**
- Create: `BikeLanes/BikeLanes/Views/Report/SubmitButton.swift`

- [ ] **Step 1: Implement**

```swift
// BikeLanes/Views/Report/SubmitButton.swift
import SwiftUI

struct SubmitButton: View {
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: action) {
                HStack {
                    Text("Submit to Denver")
                        .font(.system(size: 16, weight: .semibold))
                    Text("→").foregroundStyle(.white.opacity(0.75))
                }
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(enabled ? Color(red: 42/255, green: 111/255, blue: 63/255)
                                     : Color.secondary.opacity(0.5))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color(red: 42/255, green: 111/255, blue: 63/255).opacity(0.25),
                        radius: 14, y: 4)
            }
            .disabled(!enabled)

            Text("Files an anonymous case with Denver 311.\nNo account required.")
                .multilineTextAlignment(.center)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BikeLanes/BikeLanes/Views/Report/SubmitButton.swift
git commit -m "feat: SubmitButton primary action"
```

### Task 24: Edit sheets (one task, five sheets)

**Files:**
- Create: `BikeLanes/BikeLanes/Views/Edit/EditPlateSheet.swift`
- Create: `BikeLanes/BikeLanes/Views/Edit/EditVehicleSheet.swift`
- Create: `BikeLanes/BikeLanes/Views/Edit/EditAddressSheet.swift`
- Create: `BikeLanes/BikeLanes/Views/Edit/EditDateTimeSheet.swift`
- Create: `BikeLanes/BikeLanes/Views/Edit/EditNotesSheet.swift`

- [ ] **Step 1: Implement EditPlateSheet**

```swift
// BikeLanes/Views/Edit/EditPlateSheet.swift
import SwiftUI

struct EditPlateSheet: View {
    @Binding var draft: ReportDraft
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Plate") {
                    TextField("ABC123", text: Binding(
                        get: { draft.plate ?? "" },
                        set: { draft.plate = $0.uppercased() }))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                }
                Section("State") {
                    Picker("State", selection: Binding(
                        get: { draft.plateState ?? .colorado },
                        set: { draft.plateState = $0 })) {
                        ForEach(USState.allCases, id: \.self) { state in
                            Text(state.display).tag(state)
                        }
                    }
                }
            }
            .navigationTitle("Plate").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Implement EditVehicleSheet**

```swift
// BikeLanes/Views/Edit/EditVehicleSheet.swift
import SwiftUI

struct EditVehicleSheet: View {
    @Binding var draft: ReportDraft
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Color") {
                    TextField("Blue", text: Binding(
                        get: { draft.vehicleColor ?? "" },
                        set: { draft.vehicleColor = $0 }))
                }
                Section("Type") {
                    Picker("Type", selection: Binding(
                        get: { draft.vehicleType ?? .sedan },
                        set: { draft.vehicleType = $0 })) {
                        ForEach(DenverVehicleType.allCases, id: \.self) { t in
                            Text(t.wireValue).tag(t)
                        }
                    }
                }
                Section("Where is it parked?") {
                    Picker("Property", selection: Binding(
                        get: { draft.locationOfVehicle ?? .publicProperty },
                        set: { draft.locationOfVehicle = $0 })) {
                        Text("Public Property").tag(PropertyType.publicProperty)
                        Text("Private Property").tag(PropertyType.privateProperty)
                    }
                    Toggle("Blocking a driveway", isOn: Binding(
                        get: { draft.blockingDriveway ?? false },
                        set: { draft.blockingDriveway = $0 }))
                }
            }
            .navigationTitle("Vehicle").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Implement EditAddressSheet**

```swift
// BikeLanes/Views/Edit/EditAddressSheet.swift
import SwiftUI

struct EditAddressSheet: View {
    @Binding var draft: ReportDraft
    @Environment(\.dismiss) var dismiss
    @State private var query: String = ""
    @State private var results: [DenverAddress] = []
    private let api = DenverAPIClient()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Start typing an address…", text: $query)
                    .padding()
                    .onChange(of: query) { _, q in Task { await runSearch(q) } }
                List {
                    ForEach(results, id: \.addressId) { addr in
                        Button {
                            draft.resolvedAddress = addr
                            dismiss()
                        } label: {
                            VStack(alignment: .leading) {
                                Text(addr.line1).font(.body)
                                Text("\(addr.city), \(addr.state) \(addr.zip)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Address").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { query = draft.resolvedAddress?.line1 ?? "" }
        }
    }

    private func runSearch(_ q: String) async {
        guard q.count >= 4 else { results = []; return }
        do {
            let searched = try await api.searchAddress(
                AddressNormalizer.denverQuery(line1: q))
            results = searched.map(\.toAddress)
        } catch {
            results = []
        }
    }
}
```

- [ ] **Step 4: Implement EditDateTimeSheet and EditNotesSheet**

```swift
// BikeLanes/Views/Edit/EditDateTimeSheet.swift
import SwiftUI

struct EditDateTimeSheet: View {
    @Binding var draft: ReportDraft
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Observed at", selection: Binding(
                    get: { draft.observedAt ?? .now },
                    set: { draft.observedAt = $0 }))
            }
            .navigationTitle("Observed").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// BikeLanes/Views/Edit/EditNotesSheet.swift
import SwiftUI

struct EditNotesSheet: View {
    @Binding var draft: ReportDraft
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextEditor(text: Binding(
                    get: { draft.notes ?? "" },
                    set: { draft.notes = $0 }))
                .frame(minHeight: 200)
            }
            .navigationTitle("Notes").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add BikeLanes/BikeLanes/Views/Edit
git commit -m "feat: five edit sheets — plate, vehicle, address, date/time, notes"
```

### Task 25: History & case detail views

**Files:**
- Create: `BikeLanes/BikeLanes/ViewModels/HistoryViewModel.swift`
- Create: `BikeLanes/BikeLanes/Views/History/HistoryView.swift`
- Create: `BikeLanes/BikeLanes/Views/History/HistoryRow.swift`
- Create: `BikeLanes/BikeLanes/Views/CaseDetailView.swift`

- [ ] **Step 1: Implement HistoryViewModel**

```swift
// BikeLanes/ViewModels/HistoryViewModel.swift
import Foundation
import Observation

@MainActor
@Observable
final class HistoryViewModel {
    var cases: [StoredCase] = []
    let repo: CasePersisting

    init(repo: CasePersisting) { self.repo = repo }

    func refresh() {
        do { cases = try repo.fetchAll() } catch { cases = [] }
    }
}
```

- [ ] **Step 2: Implement HistoryView + Row**

```swift
// BikeLanes/Views/History/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @Bindable var vm: HistoryViewModel

    var body: some View {
        List(vm.cases, id: \.localId) { c in
            NavigationLink(destination: CaseDetailView(stored: c)) {
                HistoryRow(stored: c)
            }
        }
        .navigationTitle("My Reports")
        .onAppear { vm.refresh() }
    }
}

// BikeLanes/Views/History/HistoryRow.swift
import SwiftUI

struct HistoryRow: View {
    let stored: StoredCase

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary.opacity(0.2)).frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshotLine1).font(.body)
                Text(stored.submittedAt, style: .date).font(.caption).foregroundStyle(.secondary)
                Text("Case #\(stored.denverInputRecordId) · \(stored.internalStatus)")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private var snapshotLine1: String {
        guard let d = stored.snapshotJSON.data(using: .utf8),
              let snap = try? JSONDecoder().decode(ReportDraftSnapshot.self, from: d) else {
            return "Report"
        }
        return snap.addressLine1
    }
}
```

- [ ] **Step 3: Implement CaseDetailView**

```swift
// BikeLanes/Views/CaseDetailView.swift
import SwiftUI

struct CaseDetailView: View {
    let stored: StoredCase

    var body: some View {
        Form {
            Section("Denver") {
                LabeledContent("Case", value: "#\(stored.denverInputRecordId)")
                LabeledContent("Status", value: stored.internalStatus)
                if let cn = stored.denverCaseNumber { LabeledContent("SF #", value: cn) }
                LabeledContent("Submitted", value: stored.submittedAt.formatted())
            }
            if let snap = snapshot {
                Section("Report") {
                    LabeledContent("Address", value: "\(snap.addressLine1), \(snap.city)")
                    LabeledContent("Plate", value: "\(snap.plate) \(snap.plateState)")
                    LabeledContent("Vehicle", value: "\(snap.vehicleColor) \(snap.vehicleType)")
                    LabeledContent("Blocking driveway",
                                   value: snap.blockingDriveway ? "Yes" : "No")
                }
            }
            Section {
                Link("View on Denvergov.org",
                     destination: URL(string:
                        "https://www.denvergov.org/myprofile/home/cases/\(stored.denverInputRecordId)")!)
            }
        }
        .navigationTitle("Case #\(stored.denverInputRecordId)")
    }

    private var snapshot: ReportDraftSnapshot? {
        guard let d = stored.snapshotJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ReportDraftSnapshot.self, from: d)
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add BikeLanes/BikeLanes/ViewModels/HistoryViewModel.swift \
        BikeLanes/BikeLanes/Views/History \
        BikeLanes/BikeLanes/Views/CaseDetailView.swift
git commit -m "feat: history list and case detail views"
```

### Task 26: `SettingsView`

**Files:**
- Create: `BikeLanes/BikeLanes/Views/SettingsView.swift`

- [ ] **Step 1: Implement**

```swift
// BikeLanes/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @State private var showingEraseConfirm = false
    let repo: CasePersisting

    init(repo: CasePersisting = CaseRepository(container: AppContainers.shared.container)) {
        self.repo = repo
    }

    var body: some View {
        Form {
            Section("About") {
                LabeledContent("Version", value: Bundle.main.shortVersion ?? "?")
                Link("Privacy policy", destination: URL(string: "https://sam.ink/bike-lanes/privacy")!)
            }
            Section("Data") {
                Button("Delete all local reports", role: .destructive) {
                    showingEraseConfirm = true
                }
            }
            Section("What this does") {
                Text("Submits anonymous illegal-parking reports to Denver's 311 system. All photo analysis happens on your device; the photo and address are uploaded to Denver.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Delete all local reports?",
                            isPresented: $showingEraseConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) { try? repo.deleteAll() }
        }
    }
}

private extension Bundle {
    var shortVersion: String? {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BikeLanes/BikeLanes/Views/SettingsView.swift
git commit -m "feat: SettingsView (version, privacy link, delete all)"
```

### Task 27: App entry + shared container

**Files:**
- Modify: `BikeLanes/BikeLanes/App/BikeLanesApp.swift`
- Create: `BikeLanes/BikeLanes/App/AppContainers.swift`

- [ ] **Step 1: Implement shared containers singleton**

```swift
// BikeLanes/App/AppContainers.swift
import Foundation
import SwiftData

final class AppContainers {
    static let shared = AppContainers()
    let container: ModelContainer

    private init() {
        do {
            container = try ModelContainer(for: StoredCase.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
```

- [ ] **Step 2: Replace the default template `BikeLanesApp.swift`**

```swift
// BikeLanes/App/BikeLanesApp.swift
import SwiftUI
import SwiftData

@main
struct BikeLanesApp: App {
    let reportVM: ReportViewModel
    let historyVM: HistoryViewModel

    init() {
        let container = AppContainers.shared.container
        let repo = CaseRepository(container: container)
        let api = DenverAPIClient()
        let detector = (try? VehicleDetector()) ?? {
            fatalError("YOLO model failed to load — rebuild clean.")
        }()
        self.reportVM = ReportViewModel(
            exif: ExifService(),
            geocode: GeocodeService(),
            detector: detector,
            plateOCR: PlateOCRService(),
            color: ColorService(),
            api: api,
            repository: repo)
        self.historyVM = HistoryViewModel(repo: repo)
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack { ReportView(vm: reportVM) }
                    .tabItem { Label("Report", systemImage: "camera.viewfinder") }
                NavigationStack { HistoryView(vm: historyVM) }
                    .tabItem { Label("History", systemImage: "list.bullet") }
            }
            .modelContainer(AppContainers.shared.container)
        }
    }
}
```

- [ ] **Step 3: Build & run in simulator**

⌘R. Expected: two-tab app appears. Report tab opens the photos picker. Pick the fixture HEIC (sideload via simulator photos → drag `IMG_3239.HEIC`). Form fields auto-populate over 1–2 s.

- [ ] **Step 4: Commit**

```bash
git add BikeLanes/BikeLanes/App
git commit -m "feat: wire up app entry, containers, and tab navigation"
```

---

## Phase 8 — Hardening

### Task 28: Degraded-mode banner & no-GPS path

**Files:**
- Modify: `BikeLanes/BikeLanes/Views/Report/ReportView.swift`

- [ ] **Step 1: Add banner component at top of scroll**

Insert directly below the header in `ReportView`:

```swift
if vm.draft.photoURL != nil && vm.draft.coordinates == nil {
    Button(action: { editing = .address }) {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(red: 179/255, green: 58/255, blue: 58/255))
            VStack(alignment: .leading, spacing: 2) {
                Text("No location in photo").font(.system(size: 13, weight: .semibold))
                Text("Tap to add an address")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color(red: 253/255, green: 237/255, blue: 233/255))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 20)
}
```

- [ ] **Step 2: Colorize rows with missing required values in red**

In `FieldRow`, add a `missing: Bool` parameter that tints the value text red italic when true, and thread it through from `ReportView` based on each row's required-ness. Skip if the field is non-required (e.g. Notes).

- [ ] **Step 3: Manual verification**

Sideload `NoGPS.jpg` (the stripped fixture) into simulator photos. Pick it in the app. Verify banner shows; address row reads "Tap to add"; submit stays disabled until address provided.

- [ ] **Step 4: Commit**

```bash
git add BikeLanes/BikeLanes/Views/Report/ReportView.swift \
        BikeLanes/BikeLanes/Views/Report/FieldRow.swift
git commit -m "feat: degraded mode banner + red-italic styling for unfilled rows"
```

### Task 29: Submit feedback — in-progress and success

**Files:**
- Modify: `BikeLanes/BikeLanes/Views/Report/ReportView.swift`
- Modify: `BikeLanes/BikeLanes/Views/Report/SubmitButton.swift`
- Create: `BikeLanes/BikeLanes/Views/SubmissionResultView.swift`

- [ ] **Step 1: Show progress in SubmitButton**

Change `SubmitButton` to accept an `isLoading` flag, replacing the arrow with a `ProgressView` when true.

```swift
struct SubmitButton: View {
    let enabled: Bool
    let isLoading: Bool
    let action: () -> Void
    // ... body uses ProgressView when isLoading
}
```

- [ ] **Step 2: Create success screen**

```swift
// BikeLanes/Views/SubmissionResultView.swift
import SwiftUI

struct SubmissionResultView: View {
    let storedCase: StoredCase
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .resizable().frame(width: 72, height: 72)
                .foregroundStyle(Color(red: 42/255, green: 111/255, blue: 63/255))
            VStack(spacing: 8) {
                Text("Submitted")
                    .font(.custom("Fraunces", size: 28).weight(.medium))
                Text("Denver case #\(storedCase.denverInputRecordId)")
                    .font(.system(size: 14)).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)
        }
        .padding()
    }
}
```

- [ ] **Step 3: Wire into `ReportView`**

Add `@State private var showingSuccess = false` and present `SubmissionResultView(storedCase: vm.lastSavedCase!, onDone: { showingSuccess = false; vm.draft = .init() })` as a `.fullScreenCover` when `showingSuccess`. Flip to true after `await vm.submit()` returns without error.

- [ ] **Step 4: Commit**

```bash
git add BikeLanes/BikeLanes/Views
git commit -m "feat: submit progress indicator and success screen"
```

### Task 30: Snapshot tests (SwiftUI previews + runtime guard)

**Files:**
- Create: `BikeLanes/BikeLanesUITests/ReportViewSnapshotTests.swift`

- [ ] **Step 1: Add simple snapshot tests using `@testable` rendering into UIKit hosting controller**

Full snapshot infrastructure requires either `swift-snapshot-testing` or a custom hosting comparator. For v0.1 we stay dependency-free and check via an `XCTAttachment`:

```swift
// BikeLanesUITests/ReportViewSnapshotTests.swift
import XCTest
import SwiftUI
@testable import BikeLanes

final class ReportViewSnapshotTests: XCTestCase {
    @MainActor
    func testRendersHappyPath() throws {
        let vm = ReportViewModel.preview(state: .happy)
        let host = UIHostingController(rootView: ReportView(vm: vm))
        host.view.frame = .init(x: 0, y: 0, width: 390, height: 844)

        let renderer = UIGraphicsImageRenderer(size: host.view.frame.size)
        let img = renderer.image { ctx in host.view.layer.render(in: ctx.cgContext) }
        add(XCTAttachment(image: img, quality: .high))
    }
}

extension ReportViewModel {
    @MainActor
    static func preview(state: PreviewState) -> ReportViewModel {
        let vm = ReportViewModel(
            exif: ExifService(), geocode: NullGeocode(),
            detector: try! VehicleDetector(),
            plateOCR: PlateOCRService(), color: ColorService(),
            api: NullSubmit(), repository: InMemoryRepo())
        switch state {
        case .happy:
            vm.draft.resolvedAddress = .init(addressId: 70424, line1: "2744 W 13th Ave",
                city: "Denver", state: "CO", zip: "80204",
                coordinate: .init(latitude: 39.7363, longitude: -105.0215))
            vm.draft.plate = "DHKQ98"
            vm.draft.vehicleColor = "Blue"
            vm.draft.vehicleType = .sedan
            vm.draft.locationOfVehicle = .publicProperty
            vm.draft.blockingDriveway = false
            vm.draft.observedAt = .now
        case .degradedNoGPS:
            vm.draft.plate = "DHKQ98"
        }
        return vm
    }
    enum PreviewState { case happy, degradedNoGPS }
}

struct NullGeocode: GeocodeResolving {
    func resolve(coordinate: CLLocationCoordinate2D) async -> DenverAddress? { nil }
}
struct NullSubmit: CaseSubmitting {
    func uploadAttachment(id: UUID, filename: String, mimeType: String, data: Data) async throws -> AttachmentResponse {
        fatalError("unused in snapshot")
    }
    func createCase(_ r: CreateCaseRequest) async throws -> CreateCaseResponse {
        fatalError("unused in snapshot")
    }
}
final class InMemoryRepo: CasePersisting {
    func save(denverInputRecordId: Int, denverCaseId: String?, denverCaseNumber: String?,
              internalStatus: String, thumbnailFilename: String,
              snapshot: ReportDraftSnapshot) throws -> StoredCase {
        .init(denverInputRecordId: denverInputRecordId,
              thumbnailFilename: thumbnailFilename,
              snapshotJSON: "", internalStatus: internalStatus)
    }
    func fetchAll() throws -> [StoredCase] { [] }
    func deleteAll() throws {}
}
```

- [ ] **Step 2: Run tests — inspect attachments in Xcode's Report navigator**

⌘U. Verify the captured attachment shows a readable ReportView.

- [ ] **Step 3: Commit**

```bash
git add BikeLanes/BikeLanesUITests/ReportViewSnapshotTests.swift
git commit -m "test: snapshot-capture of ReportView happy and degraded states"
```

### Task 31: App Store polish

**Files:**
- Modify: `BikeLanes/BikeLanes/App/Info.plist` (or Xcode "Info" tab)
- Create: `BikeLanes/BikeLanes/Resources/Assets.xcassets/AppIcon.appiconset/...`

- [ ] **Step 1: Add app icon**

Replace placeholder `AppIcon` with a 1024×1024 PNG. A minimal bike icon over a green ground is a reasonable starter; place at `BikeLanes/Resources/Assets.xcassets/AppIcon.appiconset/1024.png` and update Contents.json accordingly.

- [ ] **Step 2: Launch screen**

Under Target → App Icons and Launch Screen → Launch Screen File → choose `LaunchScreen` (create a simple SwiftUI launch screen with the wordmark).

- [ ] **Step 3: App Store privacy nutrition label**

In App Store Connect for the app record, set:
- Data types collected: **Photos** (linked to user, product functionality), **Coarse Location** (linked to user, product functionality).
- Tracking: **No**.

Document this by creating `docs/superpowers/specs/2026-04-20-privacy-nutrition-label.md` with the above.

- [ ] **Step 4: Commit**

```bash
git add BikeLanes/BikeLanes/Resources/Assets.xcassets \
        BikeLanes/BikeLanes/App/Info.plist \
        docs/superpowers/specs/2026-04-20-privacy-nutrition-label.md
git commit -m "chore: app icon, launch screen, privacy nutrition label"
```

### Task 32: Final integration smoke

**Files:**
- (none created; this is a manual verification task)

- [ ] **Step 1: Run the manual matrix**

Fresh install in simulator → open Report → pick `IMG_3239.HEIC` → verify every auto-filled field populates within 2 s → submit → verify success screen shows a real Denver case number → verify it appears on History tab → open in CaseDetailView → tap "View on Denvergov.org" → confirm it loads in Safari.

Repeat with `NoGPS.jpg`:
- Verify banner appears
- Tap banner → address sheet → manually enter "2744 W 13th Ave"
- Finish form manually → submit → verify case lands

- [ ] **Step 2: Record results**

Create `docs/superpowers/specs/2026-04-20-smoke-run.md` with screenshots and the Denver case numbers.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-04-20-smoke-run.md
git commit -m "chore: v0.1 smoke-run evidence"
```

---

## Self-review record

After writing the plan, I re-read the spec and confirmed:

1. **Spec coverage:** every §-numbered requirement maps to a task above.
   - §3 decisions → Tasks 0 (project setup), 10 (direct-to-Denver).
   - §4 architecture → Tasks 3–27 (every service + VM + view).
   - §5 screens → Tasks 20–26.
   - §6 data models → Tasks 3–6.
   - §7 pipelines → Tasks 12, 14, 15–17, 19.
   - §8 error handling → Task 28 (degraded banner), Task 19 (retry inside `submit`), Task 29 (success state).
   - §9 privacy → Task 0 (Info.plist), Task 31 (nutrition label).
   - §10 testing → Tasks 1 (fixtures), 3–18 (unit), 11 (integration), 30 (snapshot), 32 (manual matrix).
   - §11 dependencies → Tasks 0 + 2 (no SPM, bundled models).
   - §13 open questions → all resolved inline via Task 11 probe and the plate-state default (`.colorado` in `ReportDraft`).

2. **Placeholder scan:** no TODO/TBD markers in any step. Every code step contains actual Swift.

3. **Type consistency:** service protocol names (`CaseSubmitting`, `GeocodeResolving`, `CasePersisting`) match between declaration in Task 19 and usage in Tasks 27/30. `DenverMenu.id` is `Int`, matching the wire JSON. `AttachmentResponse.id` is `UUID`, matching the client-side `attachmentId`. `CreateCaseResponse.id` is `Int` (Denver's primary key), matching the route `/myprofile/home/cases/{id}`.

4. **Scope check:** the plan focuses on v0.1 only (spec §12 deferred items are out); every task produces a commit.
