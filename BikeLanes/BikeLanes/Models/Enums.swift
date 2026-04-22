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

    /// Compact label for pill selectors. `wireValue` is too wordy (e.g. "Sedan (4 Door)").
    var shortLabel: String {
        switch self {
        case .coupe:   return "Coupe"
        case .sedan:   return "Sedan"
        case .utility: return "Utility"
        case .pickup:  return "Pickup"
        case .suv:     return "SUV"
        case .van:     return "Van"
        case .other:   return "Other"
        }
    }
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
