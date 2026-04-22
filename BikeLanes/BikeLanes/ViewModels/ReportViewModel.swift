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
    private let blu: BLUAuthService?
    private let bluSettings: BLUSettings?
    private let bluClient: BLUAPIClient
    let bluMirror: BLUCaseMirror
    /// In-memory retry context for BLU submissions, keyed by Denver case id.
    /// Populated whenever we kick off a BLU fan-out; consulted by
    /// `retryBLU(denverCaseId:)`. Lost on app relaunch — that's intentional
    /// v1 scope; retry is only offered during the same session.
    private(set) var pendingBLURetries: [Int: ReportDraft] = [:]

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
         auth: AuthService? = nil,
         blu: BLUAuthService? = nil,
         bluSettings: BLUSettings? = nil,
         bluClient: BLUAPIClient = BLUAPIClient(),
         bluMirror: BLUCaseMirror = BLUCaseMirror()) {
        self.exif = exif; self.geocode = geocode
        self.detector = detector; self.plateDetector = plateDetector
        self.plateOCR = plateOCR; self.color = color
        self.api = api; self.auth = auth
        self.blu = blu; self.bluSettings = bluSettings
        self.bluClient = bluClient
        self.bluMirror = bluMirror
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

        // Demo mode (App Store review) — simulate a successful submit with no
        // network calls so the reviewer doesn't file a real 311 case.
        if auth?.isDemoMode == true {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            lastSavedCase = CaseReceipt(
                id: Int.random(in: 900_000...999_999),
                caseNumber: nil,
                internalCaseStatus: "queuedForCRM")
            return
        }

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

        // Fan out to Bike Lane Uprising if the user has enabled the mirror
        // and is signed in. Runs detached — Denver has already succeeded
        // and the UI should advance to the receipt screen immediately. BLU
        // result lands in `bluMirror`, which the receipt / history views
        // observe for status + retry affordances. Per user directive BLU
        // must never block or roll back the Denver submit.
        let caseId = resp.id
        // Snapshot draft (value type) so a subsequent `load()` on a new
        // photo doesn't race with the in-flight BLU submit.
        let draftSnapshot = draft
        Task { [weak self] in
            await self?.fanOutToBLU(denverCaseId: caseId, draft: draftSnapshot)
        }
    }

    // MARK: - BLU fan-out

    /// Runs the full BLU submission chain for a just-filed Denver case. Any
    /// failure is captured in `bluMirror` and surfaced via UI; nothing is
    /// re-thrown because BLU is an optional secondary write.
    func fanOutToBLU(denverCaseId: Int, draft: ReportDraft) async {
        guard let blu, let bluSettings,
              bluSettings.mirrorEnabled, blu.isSignedIn
        else { return }

        pendingBLURetries[denverCaseId] = draft
        bluMirror.set(.init(status: .pending, updatedAt: .now), for: denverCaseId)
        do {
            try await submitToBLU(draft: draft, blu: blu)
            bluMirror.set(.init(status: .sent, updatedAt: .now), for: denverCaseId)
            pendingBLURetries[denverCaseId] = nil
        } catch {
            bluMirror.set(.init(status: .failed, updatedAt: .now,
                                errorMessage: String(describing: error)),
                          for: denverCaseId)
        }
    }

    /// User-initiated retry for a failed BLU submission. Requires that we
    /// still hold the retry context (photo URL + draft) for this case id —
    /// returns silently if not (retry unavailable after app relaunch).
    func retryBLU(denverCaseId: Int) async {
        guard let draft = pendingBLURetries[denverCaseId] else { return }
        await fanOutToBLU(denverCaseId: denverCaseId, draft: draft)
    }

    /// True when a retry can still be offered for a given case in this
    /// session. UI uses this to enable/disable the Retry button.
    func canRetryBLU(denverCaseId: Int) -> Bool {
        pendingBLURetries[denverCaseId] != nil
    }

    private func submitToBLU(draft: ReportDraft, blu: BLUAuthService) async throws {
        let (tokens, idToken) = try await blu.tokensForSubmit()

        // Upload the photo to Wix first; BLU wants a public static.wixstatic.com URL.
        guard let url = draft.photoURL, let data = try? Data(contentsOf: url)
        else { throw BLUSubmitError.noPhoto }
        let imageURL = try await bluClient.uploadPhoto(
            tokens: tokens, data: data,
            filename: url.lastPathComponent,
            mimeType: mimeType(for: url))

        let body = try buildBLUSubmitBody(draft: draft, cognitoToken: idToken, imageURL: imageURL)
        try await bluClient.submit(tokens: tokens, body: body)
    }

    private func buildBLUSubmitBody(draft: ReportDraft, cognitoToken: String, imageURL: String) throws -> BLU.SubmitBody {
        guard let addr = draft.resolvedAddress else { throw BLUSubmitError.noAddress }
        let observedAt = draft.observedAt ?? .now
        let tz = TimeZone.current

        // Wix Data date-only field: midnight local expressed as a UTC instant
        // wrapped in {$date: "…Z"}. HAR showed 2026-04-20T06:00:00.000Z for a
        // Denver-local 2026-04-20 event (tz offset -06:00 at the time).
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let startOfDayLocal = cal.startOfDay(for: observedAt)
        let dayUTCFormatter = ISO8601DateFormatter()
        dayUTCFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        dayUTCFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dayISO = dayUTCFormatter.string(from: startOfDayLocal)

        // Time: "HH:MM:SS.fff" local, no offset
        let timeFormatter = DateFormatter()
        timeFormatter.calendar = cal
        timeFormatter.locale = .init(identifier: "en_US_POSIX")
        timeFormatter.timeZone = tz
        timeFormatter.dateFormat = "HH:mm:ss.SSS"
        let timeStr = timeFormatter.string(from: observedAt)

        // dateAndTime: ISO8601 local with offset, fractional seconds.
        let combinedFormatter = DateFormatter()
        combinedFormatter.calendar = cal
        combinedFormatter.locale = .init(identifier: "en_US_POSIX")
        combinedFormatter.timeZone = tz
        combinedFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSxxx"
        let dateAndTime = combinedFormatter.string(from: observedAt)

        // BLU's address field is one-line free text. HAR showed
        // "2708 West 13th Avenue, Denver, 80204" — line1 + city + zip.
        let addressOneLine = [addr.line1, addr.city, addr.zip]
            .filter { !$0.isEmpty }.joined(separator: ", ")

        return BLU.SubmitBody(
            category:           String(BLUPKMaps.defaultCategory.rawValue),
            licensePlateState:  String(BLUPKMaps.plateStatePK(for: draft.plateState)),
            licensePlateNumber: draft.plate ?? "",
            notes:              draft.notes ?? "",
            metroCity:          String(BLUPKMaps.metroCityPK(forLocality: addr.city)),
            geoLocation2:       "",
            address:            addressOneLine,
            date:               .init(iso: dayISO),
            time:               timeStr,
            crashOccurred:      false,
            images:             [.init(url: imageURL)],
            cognitoToken:       cognitoToken,
            dateAndTime:        dateAndTime)
    }

    enum BLUSubmitError: Error, CustomStringConvertible {
        case noPhoto
        case noAddress
        var description: String {
            switch self {
            case .noPhoto:   return "Photo not available for BLU upload"
            case .noAddress: return "No resolved address for BLU submission"
            }
        }
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
