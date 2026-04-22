// BikeLanes/ViewModels/ReportViewModel.swift
import Foundation
import Observation
import UIKit
import CoreLocation

/// Lightweight record handed to `SubmissionResultView` after a successful submit.
/// Replaces the old local-DB `StoredCase` — history is now server-driven.
struct CaseReceipt: Equatable, Hashable, Sendable {
    let id: Int                   // Denver primary key
    let caseNumber: String?       // Salesforce number, usually nil at submit time
    let internalCaseStatus: String
}

@MainActor
@Observable
final class ReportViewModel {
    var draft = ReportDraft()
    var isLoading = false
    var isSubmitting = false
    var lastError: String?
    var lastSavedCase: CaseReceipt?

    private let exif: ExifService
    private let geocode: GeocodeResolving
    private let detector: VehicleDetector
    private let plateDetector: PlateDetector?
    private let plateOCR: PlateOCRService
    private let color: ColorService
    private let api: CaseSubmitting
    private let auth: AuthService?

    /// Cached Denver menu/question metadata, fetched lazily once per session.
    private var menu: DenverMenu?
    private var questions: [DenverMenuQuestion] = []

    init(exif: ExifService,
         geocode: GeocodeResolving,
         detector: VehicleDetector,
         plateDetector: PlateDetector?,
         plateOCR: PlateOCRService,
         color: ColorService,
         api: CaseSubmitting,
         auth: AuthService? = nil) {
        self.exif = exif; self.geocode = geocode
        self.detector = detector; self.plateDetector = plateDetector
        self.plateOCR = plateOCR; self.color = color
        self.api = api; self.auth = auth
    }

    /// Kicks off all the pipelines for a newly-selected photo. Resets the draft —
    /// picking a new photo discards everything the user had for the previous one.
    func load(photoURL url: URL) async throws {
        isLoading = true; defer { isLoading = false }
        lastError = nil
        lastSavedCase = nil
        var d = ReportDraft()
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
            guard let carBBox = try await detector.detect(imageData: data),
                  let carCrop = ImageCropper.cropCGImage(data: data, normalizedBBox: carBBox) else {
                return
            }
            draft.detectedCarBBox = carBBox

            draft.vehicleColor = color.dominantName(image: UIImage(cgImage: carCrop))

            guard let plateDetector else {
                draft.plateDetectorStatus = "detector disabled"
                return
            }
            guard let fullCGImage = ImageCropper.fullCGImage(data: data) else {
                draft.plateDetectorStatus = "failed to decode image"
                return
            }
            let detection = try await plateDetector.detect(in: fullCGImage)
            draft.plateDetectorConfidence = detection.bestConfidence
            draft.plateDetectorStatus = detection.statusMessage
            if let plateBBox = detection.box {
                draft.detectedPlateBBox = plateBBox
                if let thumb = Self.cropCGImage(fullCGImage, normalizedBBox: plateBBox, pad: 0.25),
                   let thumbData = UIImage(cgImage: thumb).jpegData(compressionQuality: 0.92) {
                    let thumbURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("plate-\(UUID().uuidString).jpg")
                    try? thumbData.write(to: thumbURL)
                    draft.plateCropImageURL = thumbURL
                }
                if let plateCrop = Self.cropCGImage(fullCGImage, normalizedBBox: plateBBox, pad: 0.10),
                   let reading = try await plateOCR.read(cgImage: plateCrop) {
                    draft.plate = reading.text
                    draft.plateConfidence = reading.confidence
                }
            }
        } catch {
            lastError = "ML pipeline failed: \(error.localizedDescription)"
        }
    }

    private static func cropCGImage(_ image: CGImage, normalizedBBox bbox: CGRect, pad: CGFloat) -> CGImage? {
        let padded = CGRect(
            x: max(0, bbox.minX - bbox.width * pad),
            y: max(0, bbox.minY - bbox.height * pad),
            width: min(1 - bbox.minX + bbox.width * pad, bbox.width * (1 + 2 * pad)),
            height: min(1 - bbox.minY + bbox.height * pad, bbox.height * (1 + 2 * pad)))
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let rect = CGRect(
            x: padded.minX * w,
            y: (1 - padded.maxY) * h,
            width: padded.width * w,
            height: padded.height * h)
        return image.cropping(to: rect)
    }

    /// Serializes the draft into Denver's JSON and submits it. Does not persist
    /// anything locally — history is driven exclusively by the server list.
    func submit() async throws {
        guard draft.isSubmittable else { return }
        guard auth?.profile != nil else {
            lastError = "Sign in to submit reports."
            throw NSError(domain: "BikeLanes", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Sign in required"])
        }
        isSubmitting = true; defer { isSubmitting = false }

        if menu == nil {
            guard let menuAPI = api as? MenuProviding else {
                throw NSError(domain: "BikeLanes", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "no MenuProviding for menu fetch"])
            }
            let menus = try await menuAPI.fetchMenus()
            menu = menus.first { $0.id == 10 }
            questions = try await menuAPI.fetchMenuQuestions(menuId: 10)
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
            contact: auth?.profile.map(CreateCaseRequest.Contact.signedIn) ?? .anonymous,
            location: .init(
                address: .init(id: addr.addressId, streetAddress: addr.line1,
                               city: addr.city, state: addr.state, zip: addr.zip),
                coordinates: .init(
                    latitude: draft.coordinates?.latitude ?? addr.coordinate.latitude,
                    longitude: draft.coordinates?.longitude ?? addr.coordinate.longitude),
                addressFromReverseGeocode: true))
        let resp = try await api.createCase(req)
        lastSavedCase = CaseReceipt(
            id: resp.id,
            caseNumber: resp.caseNumber,
            internalCaseStatus: resp.internalCaseStatus)
    }

    private func answer(for questionId: Int) -> String {
        switch questionId {
        case 20: return (draft.blockingDriveway ?? false) ? "Yes" : "No"
        case 21:
            let f = DateFormatter()
            f.calendar = .init(identifier: .gregorian)
            f.locale = .init(identifier: "en_US_POSIX")
            f.timeZone = .current
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: draft.observedAt ?? .now)
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
