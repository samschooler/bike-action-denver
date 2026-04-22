// BikeLanes/App/AppContainers.swift
import Foundation

/// Shared app-wide references. Used to be the SwiftData `ModelContainer`; now
/// that history is server-driven the container is effectively a placeholder
/// kept for future shared-state needs.
final class AppContainers: Sendable {
    static let shared = AppContainers()
    private init() {}
}
