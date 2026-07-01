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
            .compactMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }
}
