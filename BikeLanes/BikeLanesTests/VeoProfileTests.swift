// BikeLanesTests/VeoProfileTests.swift
import XCTest
@testable import BikeLanes

@MainActor
final class VeoProfileTests: XCTestCase {
    func testIsCompleteAndPhoneDigits() {
        var p = VeoProfile(name: "", email: "", phone: "")
        XCTAssertFalse(p.isComplete)
        p = VeoProfile(name: "Sam Schooler", email: "veo@sam.ink", phone: "(952) 688-3507")
        XCTAssertTrue(p.isComplete)
        XCTAssertEqual(p.phoneDigits, "9526883507")
    }

    func testStorePersistsAcrossInstances() {
        let suite = "veo.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = VeoProfileStore(defaults: defaults)
        store.profile = VeoProfile(name: "A B", email: "a@b.co", phone: "1234567890")
        let reloaded = VeoProfileStore(defaults: defaults)
        XCTAssertEqual(reloaded.profile.email, "a@b.co")
        defaults.removePersistentDomain(forName: suite)
    }
}
