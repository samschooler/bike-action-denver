// BikeLanes/ViewModels/ReportViewModel.swift
import Foundation
import Observation
import UIKit
import CoreLocation

@MainActor
@Observable
final class ReportViewModel {
    var draft = ReportDraft()
    var isLoading = false
    var isSubmitting = false
    var lastError: String?
    var lastSavedCase: StoredCase?

    private let exif: ExifService
    private let geocode: GeocodeResolving
    private let detector: VehicleDetector
    private let plateOCR: PlateOCRService
    private let color: ColorService
    private let api: CaseSubmitting
    private let repository: CasePersisting

    /// Cached Denver menu/question metadata, fetched lazily once per session.
    private var menu: DenverMenu?
    private var questions: [DenverMenuQuestion] = []

    init(exif: ExifService,
         geocode: GeocodeResolving,
         detector: VehicleDetector,
         plateOCR: PlateOCRService,
         color: ColorService,
         api: CaseSubmitting,
         repository: CasePersisting) {
        self.exif = exif; self.geocode = geocode
        self.detector = detector; self.plateOCR = plateOCR; self.color = color
        self.api = api; self.repository = repository
    }

    /// Kicks off all the pipelines for a newly-selected photo.
    func load(photoURL url: URL) async throws {
        isLoading = true; defer { isLoading = false }
        var d = draft
        d.photoURL = url

        // EXIF is synchronous; do it first.
        let meta = try exif.read(url: url)
        d.coordinates = meta.coordinates
        d.horizontalAccuracy = meta.horizontalAccuracy
        d.heading = meta.heading
        d.observedAt = meta.observedAt ?? .now

        draft = d

        // Parallel: geocode (if we have coords) and ML chain.
        await withTaskGroup(of: Void.self) { group in
            if let coord = meta.coordinates {
                group.addTask { [weak self] in
                    await self?.runGeocode(coord)
                }
            }
            group.addTask { [weak self] in
                await self?.runMLChain(url: url)
            }
        }
    }

    private func runGeocode(_ coord: CLLocationCoordinate2D) async {
        do {
            let addr = try await geocode.resolve(coordinate: coord)
            draft.resolvedAddress = addr
        } catch {
            lastError = "Couldn't resolve address: \(error.localizedDescription)"
        }
    }

    private func runMLChain(url: URL) async {
        guard let data = try? Data(contentsOf: url) else { return }
        do {
            guard let bbox = try await detector.detect(imageData: data),
                  let cropData = ImageCropper.cropJPEG(data: data, normalizedBBox: bbox) else {
                return
            }
            draft.detectedCarBBox = bbox

            async let plate = plateOCR.read(croppedImageData: cropData)
            if let image = UIImage(data: cropData) {
                draft.vehicleColor = color.dominantName(image: image)
            }
            if let reading = try await plate {
                draft.plate = reading.text
                draft.plateConfidence = reading.confidence
            }
        } catch {
            lastError = "ML pipeline failed: \(error.localizedDescription)"
        }
    }

    /// Serializes the draft into Denver's JSON and submits it.
    func submit() async throws {
        guard draft.isSubmittable else { return }
        isSubmitting = true; defer { isSubmitting = false }

        if menu == nil {
            guard let api = api as? DenverAPIClient else {
                throw NSError(domain: "BikeLanes", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "no DenverAPIClient for menu fetch"])
            }
            let menus = try await api.fetchMenus()
            menu = menus.first { $0.id == 10 }
            questions = try await api.fetchMenuQuestions(menuId: 10)
        }
        guard let menu else { throw APIError.noMenu }

        // Upload photo
        var attachmentId: UUID?
        if let url = draft.photoURL, let data = try? Data(contentsOf: url) {
            let uuid = UUID()
            let resp = try await api.uploadAttachment(
                id: uuid,
                filename: url.lastPathComponent,
                mimeType: mimeType(for: url),
                data: data)
            attachmentId = resp.id
        }

        // Build questions with answers
        let caseQs: [CreateCaseRequest.CaseQuestion] = questions.map { q in
            .init(id: q.id, question: q.question, sfAnswerField: q.sfAnswerField,
                  answer: answer(for: q.id))
        }
        let addr = draft.resolvedAddress!
        let req = CreateCaseRequest(
            comments: draft.notes ?? "",
            attachmentId: attachmentId,
            caseType: .init(
                menuType: menu.menuType, menuId: menu.id, title: menu.title,
                name: menu.caseType, sfIssueTemplateId: menu.sfIssueTemplateId,
                caseQuestions: caseQs),
            contact: .anonymous,
            location: .init(
                address: .init(id: addr.addressId, streetAddress: addr.line1,
                               city: addr.city, state: addr.state, zip: addr.zip),
                coordinates: .init(
                    latitude: draft.coordinates?.latitude ?? addr.coordinate.latitude,
                    longitude: draft.coordinates?.longitude ?? addr.coordinate.longitude),
                addressFromReverseGeocode: true))
        let resp = try await api.createCase(req)

        let snap = ReportDraftSnapshot(
            addressLine1: addr.line1, city: addr.city, state: addr.state, zip: addr.zip,
            latitude: draft.coordinates?.latitude ?? addr.coordinate.latitude,
            longitude: draft.coordinates?.longitude ?? addr.coordinate.longitude,
            plate: draft.plate ?? "",
            plateState: draft.plateState?.code ?? "CO",
            vehicleColor: draft.vehicleColor ?? "",
            vehicleType: draft.vehicleType?.wireValue ?? "",
            locationOfVehicle: draft.locationOfVehicle?.wireValue ?? "",
            blockingDriveway: draft.blockingDriveway ?? false,
            observedAt: draft.observedAt ?? .now,
            notes: draft.notes ?? "")
        lastSavedCase = try repository.save(
            denverInputRecordId: resp.id, denverCaseId: resp.caseId,
            denverCaseNumber: resp.caseNumber, internalStatus: resp.internalCaseStatus,
            thumbnailFilename: draft.photoURL?.lastPathComponent ?? "",
            snapshot: snap)
    }

    private func answer(for questionId: Int) -> String {
        switch questionId {
        case 20: return (draft.blockingDriveway ?? false) ? "Yes" : "No"
        case 21: return ISO8601DateFormatter().string(from: draft.observedAt ?? .now)
        case 22: return draft.plate ?? ""
        case 46: return draft.plateState?.code ?? "CO"
        case 47: return [draft.vehicleColor, draft.vehicleType?.wireValue]
                    .compactMap { $0 }.joined(separator: " ")
        case 48: return draft.vehicleType?.wireValue ?? ""
        case 49: return draft.locationOfVehicle?.wireValue ?? ""
        default: return ""
        }
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "heic": return "image/heic"
        case "png":  return "image/png"
        default:     return "image/jpeg"
        }
    }

    enum APIError: Error { case noMenu }
}
