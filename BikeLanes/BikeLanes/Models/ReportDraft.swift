// BikeLanes/Models/ReportDraft.swift
import Foundation
import CoreLocation

struct ReportDraft: Equatable {
    // Input
    var photoURL: URL?
    var detectedCarBBox: CGRect?
    var detectedPlateBBox: CGRect?   // Vision-normalized, within the source image
    /// Tmp-file path for a padded plate crop suitable for inline display.
    var plateCropImageURL: URL?
    var plateDetectorConfidence: Double?
    /// Debug string for the UI showing how the plate-detection stage went.
    var plateDetectorStatus: String?

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
