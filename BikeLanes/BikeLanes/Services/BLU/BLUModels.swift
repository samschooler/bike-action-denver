// BikeLanes/Services/BLU/BLUModels.swift
import Foundation

/// Wire-level DTOs for Bike Lane Uprising's Wix Velo backend. BLU's RPC
/// convention is positional JSON arrays — the `*Args` types that follow are
/// *always* serialised as `[arg1, arg2, …]`, never as `{name1: …, name2: …}`.
enum BLU {

    // MARK: - Session tokens

    /// Snapshot of the anonymous-visitor tokens that Thunderbolt would normally
    /// inject into page-scoped fetches. We get these from one call to
    /// `/_api/v1/access-tokens`; they expire (mediaAuthToken ~24h, apps
    /// instance ~24h), so we refresh whenever a Velo call returns 401/403.
    struct SessionTokens {
        /// `wixcode-pub.<sig>.<claims>` — goes into Authorization + x-wix-app-instance.
        /// Extracted from `apps[WIX_CODE_APP_DEF_ID].instance`.
        let wixcodePubToken: String
        /// `<epoch-ms>|<opaque>` — goes into the x-xsrf-token header.
        /// Read from the `XSRF-TOKEN` cookie the /_api/v1/access-tokens response sets.
        let xsrfToken: String
        /// Site-scoped file.upload JWT for `files.wix.com` requests
        /// (sent as `Authorization: APP <token>`).
        let mediaAuthToken: String
        /// Wall-clock when this snapshot was captured. We refresh after ~20h.
        let capturedAt: Date

        var isFresh: Bool { Date().timeIntervalSince(capturedAt) < 20 * 3600 }
    }

    // MARK: - Login

    /// Positional body: `[email, password]`
    struct LoginArgs: Encodable {
        let email: String
        let password: String

        func encode(to encoder: any Encoder) throws {
            var c = encoder.unkeyedContainer()
            try c.encode(email); try c.encode(password)
        }
    }

    /// Response: `{"result":{"approved":true,"token":"<cognito id_token>"}}`
    struct LoginResponse: Decodable {
        struct Payload: Decodable {
            let approved: Bool
            let token: String?
        }
        let result: Payload
    }

    // MARK: - Session validity

    /// Positional body: `[idToken]` (or `[null]` for an anonymous probe).
    struct SessionValidArgs: Encodable {
        let idToken: String?
        func encode(to encoder: any Encoder) throws {
            var c = encoder.unkeyedContainer()
            if let t = idToken { try c.encode(t) } else { try c.encodeNil() }
        }
    }

    struct SessionValidResponse: Decodable {
        let result: Bool
    }

    // MARK: - Media upload

    /// `files.wix.com/site/media/files/upload/url` response.
    /// Only `upload_url` is load-bearing for our PUT step.
    struct UploadURLResponse: Decodable {
        let upload_url: String
    }

    /// Each element of the array returned by the raw PUT to upload.wixmp.com.
    /// We only need `file_url` to construct the public `static.wixstatic.com` URL.
    struct UploadedFile: Decodable {
        let file_url: String
    }

    // MARK: - Submit

    /// Wire object matching the submit.ajax positional array element exactly.
    /// Numeric PK fields are strings — Wix's collection IDs are stored as
    /// strings on the wire even though the dropdown <option> values are ints.
    struct SubmitBody: Encodable {
        let category: String                  // stringified int, see BLUPKMaps.Category
        let licensePlateState: String         // stringified int
        let licensePlateNumber: String
        let notes: String
        let metroCity: String                 // stringified int
        let geoLocation2: String              // empty string if no pin
        let address: String
        let date: MongoDate                   // midnight-local-UTC wrapper
        let time: String                      // "HH:MM:SS.fff" local
        let crashOccurred: Bool
        let images: [Image]
        let cognitoToken: String              // AWS Cognito id_token from login.ajax
        let dateAndTime: String               // local ISO8601 with offset

        struct Image: Encodable {
            let url: String                   // public static.wixstatic.com URL
        }

        /// MongoDB extended-JSON date: `{"$date": "2026-04-20T06:00:00.000Z"}`.
        /// Wix Data uses this convention for date-only fields.
        struct MongoDate: Encodable {
            let iso: String
            enum CodingKeys: String, CodingKey { case date = "$date" }
            func encode(to encoder: any Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(iso, forKey: .date)
            }
        }
    }

    /// Response is an empty object `{}`. We treat any 200 as success.
    struct SubmitResponse: Decodable {}
}
