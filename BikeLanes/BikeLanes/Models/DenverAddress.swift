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
