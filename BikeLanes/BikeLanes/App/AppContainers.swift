// BikeLanes/App/AppContainers.swift
import Foundation
import SwiftData

final class AppContainers: Sendable {
    static let shared = AppContainers()
    let container: ModelContainer

    private init() {
        do {
            container = try ModelContainer(for: StoredCase.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
