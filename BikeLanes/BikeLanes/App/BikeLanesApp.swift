// BikeLanes/App/BikeLanesApp.swift
import SwiftUI
import SwiftData

@main
@MainActor
struct BikeLanesApp: App {
    let reportVM: ReportViewModel
    let historyVM: HistoryViewModel

    init() {
        let container = AppContainers.shared.container
        let repo = CaseRepository(container: container)
        let api = DenverAPIClient()
        let detector = (try? VehicleDetector()) ?? {
            fatalError("YOLO model failed to load — rebuild clean.")
        }()
        self.reportVM = ReportViewModel(
            exif: ExifService(),
            geocode: GeocodeService(),
            detector: detector,
            plateOCR: PlateOCRService(),
            color: ColorService(),
            api: api,
            repository: repo)
        self.historyVM = HistoryViewModel(repo: repo)
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack { ReportView(vm: reportVM) }
                    .tabItem { Label("Report", systemImage: "camera.viewfinder") }
                NavigationStack { HistoryView(vm: historyVM) }
                    .tabItem { Label("History", systemImage: "list.bullet") }
            }
            .modelContainer(AppContainers.shared.container)
        }
    }
}
