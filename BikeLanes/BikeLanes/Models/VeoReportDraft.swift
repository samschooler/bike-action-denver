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
