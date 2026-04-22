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
