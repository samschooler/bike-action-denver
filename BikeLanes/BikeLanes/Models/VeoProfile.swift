// BikeLanes/Models/VeoProfile.swift
import Foundation
import Observation

struct VeoProfile: Codable, Equatable, Sendable {
    var name: String = ""
    var email: String = ""
    var phone: String = ""

    var isComplete: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var phoneDigits: String { phone.filter(\.isNumber) }
}

@MainActor
@Observable
final class VeoProfileStore {
    private let defaults: UserDefaults
    private let key = "veoReporterProfile"

    var profile: VeoProfile {
        didSet { persist() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(VeoProfile.self, from: data) {
            self.profile = decoded
        } else {
            self.profile = VeoProfile()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: key)
        }
    }
}
