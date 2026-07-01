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
