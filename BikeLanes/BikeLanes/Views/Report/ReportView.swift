// BikeLanes/Views/Report/ReportView.swift
import SwiftUI
import PhotosUI

struct ReportView: View {
    @Bindable var vm: ReportViewModel
    let auth: AuthService?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingLibraryPicker = false
    @State private var showingCamera = false
    @State private var showingLogin = false
    @State private var showingDemoLogin = false
    @State private var showingSubmitConfirm = false
    @State private var editing: EditTarget?
    @State private var showingSuccess = false
    private let backgroundColor = Color(red: 250/255, green: 250/255, blue: 247/255)

    init(vm: ReportViewModel, auth: AuthService? = nil) {
        self.vm = vm
        self.auth = auth
    }

    enum EditTarget: Identifiable {
        case plate, vehicle, address, dateTime, notes
        var id: Int { switch self { case .plate: 0; case .vehicle: 1; case .address: 2; case .dateTime: 3; case .notes: 4 } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                OnboardingBanner()

                if let name = auth?.profile?.displayLabel {
                    Text("Reporting as \(name)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                }

                if !isSignedIn {
                    SignInPrompt(
                        onSignIn: { showingLogin = true },
                        onDemoSignIn: { showingDemoLogin = true })
                        .padding(.top, 12)
                    ExplainerCard()
                        .padding(.top, 4)
                } else if vm.draft.photoURL == nil {
                    PhotoSourcePanel(
                        onTakePhoto: { showingCamera = true },
                        onChoosePhoto: { showingLibraryPicker = true })
                        .padding(.top, 12)
                    ExplainerCard()
                        .padding(.top, 4)
                } else {
                    photoContent
                }
            }
            .padding(.vertical, 16)
        }
        .background(backgroundColor)
        .navigationTitle("Report")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: SettingsView(auth: auth)) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .photosPicker(isPresented: $showingLibraryPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, new in
            guard let new else { return }
            Task { await loadPicked(new) }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker(onCaptured: { url in
                Task { try? await vm.load(photoURL: url) }
            })
            .ignoresSafeArea()
        }
        .sheet(item: $editing) { target in
            switch target {
            case .plate:   EditPlateSheet(draft: $vm.draft)
            case .vehicle: EditVehicleSheet(draft: $vm.draft)
            case .address: EditAddressSheet(draft: $vm.draft)
            case .dateTime: EditDateTimeSheet(draft: $vm.draft)
            case .notes:   EditNotesSheet(draft: $vm.draft)
            }
        }
        .fullScreenCover(isPresented: $showingSuccess) {
            if let receipt = vm.lastSavedCase {
                SubmissionResultView(receipt: receipt, onDone: {
                    showingSuccess = false
                    vm.draft = .init()
                })
            }
        }
        .sheet(isPresented: $showingLogin) {
            if let auth { LoginSheet(auth: auth) }
        }
        .sheet(isPresented: $showingDemoLogin) {
            if let auth { DemoLoginSheet(auth: auth) }
        }
    }

    private var isSignedIn: Bool { auth?.isSignedIn == true }

    @ViewBuilder
    private var photoContent: some View {
        PhotoCard(
            image: vm.draft.photoURL.flatMap { UIImage(contentsOfFile: $0.path) },
            bbox: vm.draft.detectedCarBBox,
            plateBBox: vm.draft.detectedPlateBBox,
            plateStatus: vm.draft.plateDetectorStatus,
            heading: vm.draft.heading,
            coordinate: vm.draft.coordinates ?? vm.draft.resolvedAddress?.coordinate,
            onTakePhoto: { showingCamera = true },
            onChoosePhoto: { showingLibraryPicker = true })
            .padding(.horizontal, 20)

        if vm.draft.photoURL != nil && vm.draft.coordinates == nil {
            Button(action: { editing = .address }) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color(red: 179/255, green: 58/255, blue: 58/255))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No location in photo").font(.system(size: 13, weight: .semibold))
                        Text("Tap to add an address")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color(red: 253/255, green: 237/255, blue: 233/255))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }

        VStack(spacing: 0) {
            FieldRow(label: "Where",
                     value: vm.draft.resolvedAddress?.line1,
                     caption: locationCaption,
                     missing: vm.draft.resolvedAddress == nil,
                     onEdit: { editing = .address }) {
                Text("📍").font(.system(size: 16))
            }
            divider
            FieldRow(label: "Plate",
                     value: plateValue,
                     caption: vm.draft.plate.map { _ in "Read from photo" },
                     missing: vm.draft.plate?.isEmpty != false,
                     leadingWidth: vm.draft.plateCropImageURL == nil ? 44 : 86,
                     onEdit: { editing = .plate }) {
                if let url = vm.draft.plateCropImageURL,
                   let ui = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Text(vm.draft.plateState?.code ?? "??")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            divider
            VehicleSection(draft: $vm.draft)
                .id(vm.draft.photoURL)
            divider
            FieldRow(label: "Observed",
                     value: vm.draft.observedAt.map { relativeDate($0) },
                     caption: vm.draft.observedAt.map { _ in "From photo timestamp" },
                     missing: vm.draft.observedAt == nil,
                     onEdit: { editing = .dateTime }) {
                Text("🕒").font(.system(size: 16))
            }
            divider
            FieldRow(label: "Notes · optional",
                     value: vm.draft.notes,
                     caption: nil,
                     missing: false,
                     onEdit: { editing = .notes }) {
                Text("＋").font(.system(size: 18)).foregroundStyle(.secondary)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 20)

        SubmitButton(enabled: vm.draft.isSubmittable && !vm.isSubmitting,
                     isLoading: vm.isSubmitting,
                     signedInAs: auth?.profile?.displayLabel) {
            showingSubmitConfirm = true
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .alert("File this report with Denver?", isPresented: $showingSubmitConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("File Report", role: .destructive) {
                Task {
                    do {
                        try await vm.submit()
                        if vm.lastSavedCase != nil {
                            showingSuccess = true
                        }
                    } catch {
                        // surfaced via vm.lastError
                    }
                }
            }
        } message: {
            Text("This will file a real Denver 311 case under your PocketGov account. Do not file fake or duplicate reports, and only report vehicles that are currently parked in the bike lane.")
        }
    }

    private var divider: some View {
        Rectangle().fill(Color(red: 242/255, green: 239/255, blue: 229/255))
            .frame(height: 1).padding(.horizontal, 16)
    }

    private func loadPicked(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("pick-\(UUID().uuidString).heic")
            try data.write(to: tmp)
            try await vm.load(photoURL: tmp)
        } catch {
            vm.lastError = error.localizedDescription
        }
    }

    private var locationCaption: String? {
        guard let a = vm.draft.resolvedAddress else { return nil }
        let accuracy = vm.draft.horizontalAccuracy.map { "±\(Int($0))m" } ?? ""
        return "\(a.city), \(a.state) \(a.zip) \(accuracy)".trimmingCharacters(in: .whitespaces)
    }

    private var plateValue: String? {
        guard let p = vm.draft.plate, !p.isEmpty else { return nil }
        let state = vm.draft.plateState?.display ?? ""
        return "\(p) · \(state)"
    }

    private func relativeDate(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .short
        return f.localizedString(for: d, relativeTo: .now)
    }
}
