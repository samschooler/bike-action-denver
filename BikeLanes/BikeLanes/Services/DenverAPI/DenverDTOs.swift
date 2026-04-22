// BikeLanes/Services/DenverAPI/DenverDTOs.swift
import Foundation

// MARK: Menus & questions

struct DenverMenu: Decodable, Identifiable {
    let id: Int
    let menuType: String
    let title: String
    let caseType: String
    let active: Bool
    let sfIssueTemplateId: String
    let configuration: String   // JSON string per Denver's schema; not parsed here
}

struct DenverMenuQuestion: Decodable, Identifiable {
    let id: Int
    let menuId: Int
    let question: String
    let questionType: String
    let active: Bool
    let required: Bool
    let order: Int
    let options: String         // JSON string
    let sfAnswerField: String
    let group: String
}

// MARK: Address search result — reuses DenverAddress for decoding

extension DenverAddress {
    /// The address-search endpoint returns a superset of DenverAddress fields; decode what we use.
    struct SearchResult: Decodable {
        let addressId: Int
        let addressLine1: String
        let city: String
        let state: String
        let zip: String
        let latitude: Double
        let longitude: Double
        let isInDenver: Bool

        var toAddress: DenverAddress {
            .init(addressId: addressId, line1: addressLine1, city: city,
                  state: state, zip: zip,
                  coordinate: .init(latitude: latitude, longitude: longitude))
        }
    }
}

// MARK: Attachment

struct AttachmentResponse: Decodable {
    let id: UUID
    let mimeType: String
    let pathToFiles: String
    let created: Date

    enum CodingKeys: String, CodingKey { case id, mimeType, pathToFiles, created }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let idString = try c.decode(String.self, forKey: .id)
        guard let uuid = UUID(uuidString: idString) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c,
                                                   debugDescription: "bad uuid \(idString)")
        }
        id = uuid
        mimeType = try c.decode(String.self, forKey: .mimeType)
        pathToFiles = try c.decode(String.self, forKey: .pathToFiles)
        created = try c.decode(Date.self, forKey: .created)
    }
}

// MARK: Create case

struct CreateCaseRequest: Encodable {
    struct CaseType: Encodable {
        let menuType: String
        let menuId: Int
        let title: String
        let name: String
        let sfIssueTemplateId: String
        let caseQuestions: [CaseQuestion]
    }
    struct CaseQuestion: Encodable {
        let id: Int
        let question: String
        let sfAnswerField: String
        let answer: String
    }
    struct Contact: Encodable {
        let anonymous: Bool
        let languagePreference: String
        let firstName: String
        let lastName: String
        let email: String
        let phone: String?
        /// Azure B2C object id; populated for signed-in submissions so Denver can
        /// tie the case to the user's PocketGov account.
        let b2cId: String?
    }
    struct Location: Encodable {
        struct Address: Encodable {
            let id: Int
            let streetAddress: String
            let city: String
            let state: String
            let zip: String
        }
        struct Coordinates: Encodable {
            let latitude: Double
            let longitude: Double
        }
        let address: Address
        let coordinates: Coordinates
        let addressFromReverseGeocode: Bool
    }

    let comments: String
    let attachmentId: UUID?
    let caseType: CaseType
    let contact: Contact
    let location: Location
}

struct CreateCaseResponse: Decodable {
    let id: Int                           // Denver primary key
    let inputRecordId: Int
    let internalCaseStatus: String
    let caseStatus: String
    let caseId: String?
    let caseNumber: String?
    let sentStatus: String
    let attempts: Int
}

// MARK: Anonymous contact helper

extension CreateCaseRequest.Contact {
    /// Default anonymous contact shape. Empty strings for name/email; phone nil.
    /// ⚠️ Unverified — will be finalized by LiveAPIIntegrationTests.testAnonymousContactShape_probe.
    /// If Denver rejects this shape, update here after the probe identifies the accepted variant.
    static var anonymous: CreateCaseRequest.Contact {
        .init(anonymous: true, languagePreference: "en",
              firstName: "", lastName: "", email: "", phone: nil, b2cId: nil)
    }

    /// Signed-in contact built from a fetched Denver `UserProfile`. Fields fall
    /// back to empty strings if the profile has them nil, matching the wire
    /// shape Denver's SPA sends.
    static func signedIn(profile: UserProfile) -> CreateCaseRequest.Contact {
        .init(anonymous: false,
              languagePreference: profile.preferredLanguage ?? "en",
              firstName: profile.firstName ?? "",
              lastName:  profile.lastName ?? "",
              email:     profile.email ?? "",
              phone:     profile.phone,
              b2cId:     profile.id)
    }
}
