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

final class FakeDenverAPI: DenverAddressSearching, @unchecked Sendable {
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
