// BikeLanes/App/BikeLanesApp.swift
import SwiftUI

@main
@MainActor
struct BikeLanesApp: App {
    let reportVM: ReportViewModel
    let historyVM: HistoryViewModel
    let auth: AuthService
    let blu: BLUAuthService
    let bluSettings: BLUSettings

    init() {
        let isDryRun = ProcessInfo.processInfo.environment["BIKE_LANES_DRY_RUN"] == "1"

        let authService = AuthService()
        self.auth = authService
        let bluService = BLUAuthService()
        self.blu = bluService
        let bluSettings = BLUSettings()
        self.bluSettings = bluSettings

        let liveAPI = DenverAPIClient(tokenProvider: { [weak authService] in
            (try? await authService?.currentIdToken()) ?? nil
        })
        let api: CaseSubmitting = isDryRun ? DryRunSubmit() : liveAPI
        if isDryRun { print("[BikeLanes] DRY RUN MODE — no real Denver submits") }

        let detector = (try? VehicleDetector()) ?? {
            fatalError("YOLO model failed to load — rebuild clean.")
        }()
        self.reportVM = ReportViewModel(
            exif: ExifService(),
            geocode: GeocodeService(),
            detector: detector,
            plateDetector: try? PlateDetector(),
            plateOCR: PlateOCRService(),
            color: ColorService(),
            api: api,
            auth: authService,
            blu: bluService,
            bluSettings: bluSettings)

        let statusService = CaseStatusService(
            tokenProvider: { [weak authService] in try await authService?.currentIdToken() },
            onInvalidated: { [weak authService] in
                await MainActor.run { authService?.invalidate() }
            })
        self.historyVM = HistoryViewModel(status: statusService, auth: authService)
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack { ReportView(vm: reportVM, auth: auth, blu: blu, bluSettings: bluSettings) }
                    .tabItem { Label("Report", systemImage: "camera.viewfinder") }
                NavigationStack { HistoryView(vm: historyVM, auth: auth, bluMirror: reportVM.bluMirror) }
                    .tabItem { Label("History", systemImage: "list.bullet") }
            }
            .task { await auth.restore() }
        }
    }
}
