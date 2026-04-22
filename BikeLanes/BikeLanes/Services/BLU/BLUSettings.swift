// BikeLanes/Services/BLU/BLUSettings.swift
import Foundation
import Observation

/// User-facing settings for the Bike Lane Uprising fan-out. Backed by
/// UserDefaults so the toggle state survives relaunches. Observable so
/// SwiftUI views can bind directly.
@MainActor
@Observable
final class BLUSettings {
    /// When true AND the user is signed in to BLU, successful Denver
    /// submits will trigger a mirrored BLU submission. Default false.
    var mirrorEnabled: Bool {
        didSet { defaults.set(mirrorEnabled, forKey: Keys.mirrorEnabled) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.mirrorEnabled = defaults.bool(forKey: Keys.mirrorEnabled)
    }

    private enum Keys {
        static let mirrorEnabled = "blu.mirrorEnabled"
    }
}
