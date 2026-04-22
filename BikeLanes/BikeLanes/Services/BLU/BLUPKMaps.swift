// BikeLanes/Services/BLU/BLUPKMaps.swift
import Foundation

/// Opaque Wix Data row PKs for Bike Lane Uprising's submission-form dropdowns.
/// Captured from the `/submit` page DOM on 2026-04-22. These IDs do not
/// correspond to any public taxonomy — treat them as constants. If a future
/// capture shows a mismatch, BLU has re-seeded their collections and we need
/// to re-scrape. See `data/blu-pk-maps.md` for the full capture.
enum BLUPKMaps {

    // MARK: - Category

    /// BLU categories for the violation type. Our app only ever reports
    /// private-owner parking violations, so we hardcode to `.privateOwner`.
    /// The other six cases are documented for completeness if the app ever
    /// expands beyond the bike-lane-parking use case.
    enum Category: Int {
        case municipalVehicle = 1      // city vehicles including USPS
        case privateOwner     = 2      // ← only one our app uses
        case companyVehicle   = 3
        case other            = 4      // damaged lane / snow / debris / pedestrian
        case rideshareTaxi    = 5      // Taxi / Uber / Livery / Lyft
        case construction     = 6
    }

    /// Our fan-out always reports as private-owner; ML already determines
    /// vehicle type for Denver, but BLU's taxonomy is coarser and the
    /// private-owner bucket is the correct floor for a bike-lane obstruction
    /// report with no better metadata.
    static let defaultCategory: Category = .privateOwner

    // MARK: - Plate state

    /// Sentinel PKs for non-US-state plate values.
    enum PlateStateSentinel: Int {
        case unknown          = 43
        case notApplicable    = 45
        case noPlateOnVehicle = 32
        case usGovernment     = 24
        case mexico           = 20
    }

    /// US state + DC USPS code → BLU plate-state PK. Keyed by USPS two-letter
    /// code to match our `USState.code` output directly.
    static let statePKByUSPSCode: [String: Int] = [
        "AL": 37, "AK": 61, "AZ": 63, "AR": 51, "CA": 33, "CO": 69,
        "CT":  1, "DE": 21, "DC": 49, "FL": 27, "GA": 18, "HI": 47,
        "ID": 34, "IL": 26, "IN": 70, "IA": 14, "KS":  5, "KY": 54,
        "LA": 65, "ME": 12, "MD": 19, "MA": 42, "MI": 41, "MN": 31,
        "MS": 28, "MO": 38, "MT": 35, "NE": 40, "NV": 64, "NH": 58,
        "NJ": 17, "NM": 48, "NY": 52, "NC": 36, "ND": 15, "OH": 53,
        "OK":  8, "OR": 46, "PA":  2, "RI": 60, "SC":  4, "SD": 23,
        "TN": 72, "TX": 68, "UT":  7, "VT": 56, "VA":  9, "WA": 39,
        "WV": 25, "WI":  3, "WY": 16,
    ]

    /// Resolve a `USState` to its BLU plate-state PK. Falls back to the
    /// UNKNOWN sentinel if the USPS code isn't in our table (which shouldn't
    /// happen — we have all 50 + DC — but the fallback keeps submission
    /// total-functional).
    static func plateStatePK(for state: USState?) -> Int {
        guard let code = state?.code,
              let pk = statePKByUSPSCode[code]
        else { return PlateStateSentinel.unknown.rawValue }
        return pk
    }

    // MARK: - Metro city

    /// Denver and the "not listed" fallback — the only two we strictly need.
    static let denverPK         = 146
    static let notListedPK      = 109

    /// Front Range municipalities where a Denver-resident's report might
    /// geocode to (RTD service area + common commute destinations). Keyed by
    /// lowercased city name to match what CLPlacemark.locality typically
    /// returns. If a report's locality is here, we use this PK; otherwise we
    /// fall back to `notListedPK`.
    static let frontRangeCityPK: [String: Int] = [
        "denver":         146,
        "arvada":         336,
        "aurora":         337,
        "broomfield":     338,
        "castle rock":    339,
        "centennial":     340,
        "commerce city": 2058,
        "englewood":     2070,
        "glendale":      2077,
        "golden":         353,
        "grand junction": 342,
        "lakewood":       343,
        "littleton":      354,
        "longmont":       344,
        "loveland":       345,
        "northglenn":     357,
        "pueblo":         346,
        "thornton":       347,
        "westminster":    348,
        "wheat ridge":    360,
    ]

    /// Resolve a locality string (from reverse-geocoding) to a BLU city PK.
    /// Defaults to "My metro city is not listed" for anything outside the
    /// Front Range — BLU prefers this over a bogus city rather than a hard
    /// rejection.
    static func metroCityPK(forLocality locality: String?) -> Int {
        guard let key = locality?.lowercased(),
              let pk = frontRangeCityPK[key]
        else { return notListedPK }
        return pk
    }
}
