// BikeLanesTests/VeoSubmissionEncodingTests.swift
import XCTest
import CoreLocation
@testable import BikeLanes

final class VeoSubmissionEncodingTests: XCTestCase {
    private func sampleSubmission() -> VeoSubmission {
        var draft = VeoReportDraft()
        draft.photoURL = URL(fileURLWithPath: "/tmp/IMG.jpg")
        draft.addressText = "1300 Knox Ct, Denver, CO"
        draft.vehicleType = .eBike
        draft.vehicleNumber = ""            // -> fallback
        draft.onPrivateOrBlocking = false
        draft.blockingRamp = false
        draft.notes = "Bike parked on the sidewalk."
        let profile = VeoProfile(name: "Sam Schooler", email: "veo@sam.ink", phone: "(952) 688-3507")
        let attachment = #"{"id":"fodCAz","file_name":"IMG.jpg","url":"u","delete_url":"d"}"#
        return VeoSubmission(draft: draft, profile: profile,
                             attachmentJSON: attachment, csrfToken: "TOK")
    }

    func testEncodeUnreserved() {
        XCTAssertEqual(veoFormEncode("a b&c"), "a%20b%26c")
        XCTAssertEqual(veoFormEncode("Sam Schooler"), "Sam%20Schooler")
    }

    func testBodyContainsAllFields() {
        let body = sampleSubmission().formURLEncodedBody()
        XCTAssertTrue(body.contains("request%5Bticket_form_id%5D=24858990499988"))
        XCTAssertTrue(body.contains("request%5Banonymous_requester_email%5D=veo%40sam.ink"))
        XCTAssertTrue(body.contains("request%5Bsubject%5D="))
        XCTAssertTrue(body.contains("request%5Bdescription%5D=%3Cp%3EBike%20parked%20on%20the%20sidewalk.%3C%2Fp%3E"))
        XCTAssertTrue(body.contains("request%5Bdescription_mimetype%5D=text%2Fhtml"))
        XCTAssertTrue(body.contains("request%5Bcustom_fields%5D%5B360037999772%5D=9526883507")) // phone digits
        // Blank vehicle number is submitted empty, NOT as a "(Didn't find it)" fallback.
        XCTAssertFalse(body.contains(veoFormEncode("(Didn't find it)")))
        XCTAssertTrue(body.contains("request%5Bcustom_fields%5D%5B360038000552%5D=&"))            // empty vehicle number
        XCTAssertTrue(body.contains("request%5Bcustom_fields%5D%5B360029446151%5D=e-bike"))       // vehicle type
        XCTAssertTrue(body.contains("request%5Bcustom_fields%5D%5B360029389292%5D=den_denver_-_co"))
        XCTAssertTrue(body.contains("request%5Bcustom_fields%5D%5B24862782037652%5D=illegal_parking_no"))
        XCTAssertTrue(body.contains("request%5Bcustom_fields%5D%5B24862819814548%5D=block_ramp_no"))
        XCTAssertTrue(body.contains("authenticity_token=TOK"))
        XCTAssertTrue(body.contains("request%5Battachments%5D%5B%5D="))
    }

    func testNotesAreHTMLEscaped() {
        var draft = VeoReportDraft()
        draft.photoURL = URL(fileURLWithPath: "/tmp/x.jpg"); draft.addressText = "A"
        draft.vehicleType = .scooter
        draft.notes = "Tucker & <b>Sam</b>"
        let body = VeoSubmission(draft: draft, profile: VeoProfile(),
                                 attachmentJSON: "{}", csrfToken: "T").formURLEncodedBody()
        // <p>Tucker &amp; &lt;b&gt;Sam&lt;/b&gt;</p>, then form-encoded
        let expected = veoFormEncode("<p>Tucker &amp; &lt;b&gt;Sam&lt;/b&gt;</p>")
        XCTAssertTrue(body.contains("request%5Bdescription%5D=" + expected))
    }

    func testYesTags() {
        var draft = VeoReportDraft()
        draft.photoURL = URL(fileURLWithPath: "/tmp/x.jpg"); draft.addressText = "A"
        draft.vehicleType = .scooter
        draft.onPrivateOrBlocking = true; draft.blockingRamp = true
        let body = VeoSubmission(draft: draft, profile: VeoProfile(),
                                 attachmentJSON: "{}", csrfToken: "T").formURLEncodedBody()
        XCTAssertTrue(body.contains("360029446151%5D=scooter"))
        XCTAssertTrue(body.contains("24862782037652%5D=illegal_parking_yes"))
        XCTAssertTrue(body.contains("24862819814548%5D=block_ramp_yes"))
    }
}
