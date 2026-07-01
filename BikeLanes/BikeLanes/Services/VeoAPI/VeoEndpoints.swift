import Foundation

/// Veo (VeoRide) Zendesk Help Center endpoints + form constants.
/// See docs/veo-report-api.md.
enum VeoEndpoints {
    static let base = URL(string: "https://veoride.zendesk.com")!

    static let csrfToken     = base.appending(path: "hc/api/internal/csrf_token.json")
    static let requestUploads = base.appending(path: "hc/en-us/request_uploads")
    static let requests       = base.appending(path: "hc/en-us/requests")

    static let ticketFormID = "24858990499988"
    static let market       = "den_denver_-_co"
    static let subject      = "A vehicle is parked where it doesn\u{2019}t belong"
    static let descriptionMimeType = "text/html"

    /// Zendesk custom-field IDs for this ticket form.
    enum Field {
        static let phone           = "360037999772"
        static let vehicleNumber   = "360038000552"
        static let vehicleType     = "360029446151"
        static let market          = "360029389292"
        static let fullName        = "360038288771"
        static let location        = "24861449413652"
        static let privateBlocking = "24862782037652"
        static let blockingRamp    = "24862819814548"
    }
}
