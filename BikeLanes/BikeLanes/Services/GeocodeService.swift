// BikeLanes/Services/GeocodeService.swift
import Foundation
import CoreLocation

protocol DenverAddressSearching: Sendable {
    func searchAddress(_ query: String) async throws -> [DenverAddress.SearchResult]
}

extension DenverAPIClient: DenverAddressSearching {}

/// Protocol seam for reverse geocoding, lets view-models use fakes in tests.
protocol GeocodeResolving: Sendable {
    func resolve(coordinate: CLLocationCoordinate2D) async throws -> DenverAddress?
}

extension GeocodeService: GeocodeResolving {}

struct GeocodeService {
    typealias ReverseGeocoder = @Sendable (CLLocationCoordinate2D) async throws -> String?

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
    @Sendable
    static func clReverse(_ coord: CLLocationCoordinate2D) async throws -> String? {
        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(loc)
        guard let p = placemarks.first,
              let number = p.subThoroughfare,
              let street = p.thoroughfare else { return nil }
        return "\(number) \(street)"
    }
}
