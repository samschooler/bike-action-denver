import Foundation
import Observation
import CoreLocation

@MainActor
@Observable
final class VeoReportViewModel {
    var draft = VeoReportDraft()
    var isSubmitting = false
    var lastError: String?
    var didSubmit = false

    private let exif: ExifService
    private let resolver: VeoAddressResolving
    private let client: VeoSubmitting
    let profileStore: VeoProfileStore

    init(exif: ExifService, resolver: VeoAddressResolving,
         client: VeoSubmitting, profileStore: VeoProfileStore) {
        self.exif = exif; self.resolver = resolver
        self.client = client; self.profileStore = profileStore
    }

    func load(photoURL url: URL) async {
        lastError = nil; didSubmit = false
        var d = VeoReportDraft()
        d.photoURL = url
        if let meta = try? exif.read(url: url) {
            d.coordinates = meta.coordinates
            d.observedAt = meta.observedAt ?? .now
        }
        draft = d
        if let coord = draft.coordinates,
           let text = await resolver.addressText(for: coord) {
            draft.addressText = text
        }
    }

    func submit() async {
        lastError = nil
        guard profileStore.profile.isComplete else {
            lastError = "Add your name and email in the reporter section above first."
            return
        }
        guard let url = draft.photoURL, let data = try? Data(contentsOf: url) else {
            lastError = "Couldn't read the photo."
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let token = try await client.fetchCSRFToken()
            let filename = url.lastPathComponent
            let mime = filename.lowercased().hasSuffix(".heic") ? "image/heic" : "image/jpeg"
            let att = try await client.uploadAttachment(filename: filename, mimeType: mime, data: data)
            let submission = VeoSubmission(draft: draft, profile: profileStore.profile,
                                           attachmentJSON: att.rawJSON, csrfToken: token)
            try await client.submit(submission)
            didSubmit = true
        } catch {
            lastError = "Couldn't send to Veo: \(error.localizedDescription)"
        }
    }
}
