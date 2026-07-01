// BikeLanes/Views/Veo/VeoReportView.swift
import SwiftUI
import PhotosUI

struct VeoReportView: View {
    @Bindable var vm: VeoReportViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingLibraryPicker = false
    @State private var showingCamera = false
    @State private var showingScanner = false
    @State private var scanPickerItem: PhotosPickerItem?
    @State private var showingScanFromPhoto = false
    private let bg = Color.appBackground

    init(vm: VeoReportViewModel) { self.vm = vm }

    private let vehicleOptions: [QuickPickOption<VeoVehicleType>] =
        VeoVehicleType.allCases.map { .init(label: $0.display, value: $0) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if vm.draft.photoURL == nil {
                    PhotoSourcePanel(onTakePhoto: { showingCamera = true },
                                     onChoosePhoto: { showingLibraryPicker = true })
                        .padding(.top, 12)
                    VeoParkingGuide()
                        .padding(.top, 8)
                } else {
                    form
                }
            }
            .padding(.vertical, 16)
        }
        .background(bg)
        .navigationTitle("Report to Veo")
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: $showingLibraryPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, new in guard let new else { return }; Task { await loadPicked(new) } }
        .photosPicker(isPresented: $showingScanFromPhoto, selection: $scanPickerItem, matching: .images)
        .onChange(of: scanPickerItem) { _, new in guard let new else { return }; Task { await scanFromPhoto(new) } }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker(onCaptured: { url in Task { await vm.load(photoURL: url) } }).ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingScanner) {
            VeoScannerScreen(onScanned: { vm.draft.vehicleNumber = $0 })
        }
        .fullScreenCover(isPresented: Binding(get: { vm.didSubmit }, set: { if !$0 { vm.didSubmit = false } })) {
            VeoSuccessView(onDone: { vm.didSubmit = false; vm.draft = .init() })
        }
    }

    @ViewBuilder private var form: some View {
        PhotoCard(image: vm.draft.photoURL.flatMap { UIImage(contentsOfFile: $0.path) },
                  bbox: nil, plateBBox: nil, plateStatus: nil, heading: nil,
                  coordinate: vm.draft.coordinates,
                  onTakePhoto: { showingCamera = true },
                  onChoosePhoto: { showingLibraryPicker = true })
            .padding(.horizontal, 20)

        card { labeledField("Location (address or cross streets)",
                            text: $vm.draft.addressText, placeholder: "1300 Knox Ct, Denver, CO") }

        card { QuickPickRow(label: "Vehicle type",
                            options: vehicleOptions, selection: $vm.draft.vehicleType) }

        card { vehicleNumberRow }

        card { yesNoPicker("On private property / blocking a walkway, street or parking spot?",
                           selection: $vm.draft.onPrivateOrBlocking) }
        card { yesNoPicker("Blocking an accessibility ramp?", selection: $vm.draft.blockingRamp) }

        card { labeledField("Notes", text: $vm.draft.notes, placeholder: "Describe what you saw") }

        if let err = vm.lastError {
            Text(err).font(.system(size: 13)).foregroundStyle(Color.dangerRed)
                .padding(.horizontal, 20)
        }

        SubmitButton(enabled: vm.draft.isSubmittable && !vm.isSubmitting,
                     isLoading: vm.isSubmitting,
                     title: "Submit to Veo",
                     captionOverride: "Files a support request with Veo. No Denver account needed.") {
            Task { await vm.submit() }
        }
        .padding(.horizontal, 20).padding(.top, 4)
    }

    private var vehicleNumberRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VEHICLE NUMBER").font(.system(size: 11, weight: .medium)).kerning(0.88)
                .foregroundStyle(Color.mutedLabel)
            HStack {
                TextField(VeoReportDraft.vehicleNumberFallback, text: $vm.draft.vehicleNumber)
                    .textFieldStyle(.roundedBorder)
                Menu {
                    Button { showingScanner = true } label: { Label("Scan with camera", systemImage: "qrcode.viewfinder") }
                    Button { showingScanFromPhoto = true } label: { Label("Scan from photo", systemImage: "photo") }
                } label: {
                    Image(systemName: "qrcode.viewfinder").font(.system(size: 20))
                        .foregroundStyle(Color.brandGreen)
                }
            }
            Text("Located under the QR code in the center of the handlebars, if available.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased()).font(.system(size: 11, weight: .medium)).kerning(0.88)
                .foregroundStyle(Color.mutedLabel)
            TextField(placeholder, text: text, axis: .vertical).textFieldStyle(.roundedBorder)
        }
    }

    private func yesNoPicker(_ label: String, selection: Binding<Bool?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased()).font(.system(size: 11, weight: .medium)).kerning(0.88)
                .foregroundStyle(Color.mutedLabel)
            Picker(label, selection: Binding(
                get: { selection.wrappedValue },
                set: { selection.wrappedValue = $0 })) {
                    Text("Select").tag(Bool?.none)
                    Text("Yes").tag(Bool?.some(true))
                    Text("No").tag(Bool?.some(false))
                }
                .pickerStyle(.segmented)
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 20)
    }

    private func loadPicked(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("veo-pick-\(UUID()).jpg")
        try? data.write(to: url)
        await vm.load(photoURL: url)
    }

    private func scanFromPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data), let value = VeoPhotoQR.scan(image) else {
            vm.lastError = "No code found in that photo."
            return
        }
        vm.draft.vehicleNumber = value
    }
}

struct VeoSuccessView: View {
    let onDone: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 64))
                .foregroundStyle(Color.brandGreen)
            Text("Reported to Veo").font(.system(size: 22, weight: .semibold))
            Text("Your report was filed with Veo support. Thanks for keeping the sidewalks clear.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal, 40)
            Button(action: onDone) {
                Text("Done").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .padding(.vertical, 16).frame(maxWidth: .infinity)
                    .background(Color.brandGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}
