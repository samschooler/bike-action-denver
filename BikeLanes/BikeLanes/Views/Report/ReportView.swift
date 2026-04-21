// BikeLanes/Views/Report/ReportView.swift
import SwiftUI
import PhotosUI

struct ReportView: View {
    @Bindable var vm: ReportViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingPicker = false
    @State private var editing: EditTarget?
    private let backgroundColor = Color(red: 250/255, green: 250/255, blue: 247/255)

    enum EditTarget: Identifiable {
        case plate, vehicle, address, dateTime, notes
        var id: Int { switch self { case .plate: 0; case .vehicle: 1; case .address: 2; case .dateTime: 3; case .notes: 4 } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Report")
                        .font(.custom("Fraunces", size: 28).weight(.medium))
                    Spacer()
                    NavigationLink(destination: SettingsView(repo: CaseRepository(container: AppContainers.shared.container))) {
                        Circle().fill(Color(red: 240/255, green: 237/255, blue: 226/255))
                            .frame(width: 36, height: 36)
                            .overlay(Image(systemName: "gearshape").foregroundStyle(.secondary))
                    }
                }
                .padding(.horizontal, 20)

                PhotoCard(
                    image: vm.draft.photoURL.flatMap { UIImage(contentsOfFile: $0.path) },
                    bbox: vm.draft.detectedCarBBox,
                    heading: vm.draft.heading,
                    onRetake: { showingPicker = true })
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
                             onEdit: { editing = .plate }) {
                        Text(vm.draft.plateState?.code ?? "??")
                            .font(.system(size: 11, weight: .bold))
                    }
                    divider
                    FieldRow(label: "Vehicle",
                             value: vehicleValue,
                             caption: vehicleCaption,
                             missing: vm.draft.vehicleType == nil
                                   || vm.draft.vehicleColor == nil
                                   || vm.draft.locationOfVehicle == nil
                                   || vm.draft.blockingDriveway == nil,
                             onEdit: { editing = .vehicle }) {
                        Circle().fill(colorCategory(vm.draft.vehicleColor))
                            .frame(width: 22, height: 22)
                    }
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

                SubmitButton(enabled: vm.draft.isSubmittable && !vm.isSubmitting) {
                    Task { try? await vm.submit() }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .padding(.vertical, 16)
        }
        .background(backgroundColor)
        .photosPicker(isPresented: $showingPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, new in
            guard let new else { return }
            Task { await loadPicked(new) }
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
        .task {
            if vm.draft.photoURL == nil { showingPicker = true }
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

    private var vehicleValue: String? {
        let c = vm.draft.vehicleColor
        let t = vm.draft.vehicleType?.wireValue
        switch (c, t) {
        case let (c?, t?): return "\(c) \(t.lowercased())"
        case let (c?, nil): return c
        case let (nil, t?): return t
        default: return nil
        }
    }

    private var vehicleCaption: String? {
        var bits: [String] = []
        if let lv = vm.draft.locationOfVehicle { bits.append(lv.wireValue) }
        if let bd = vm.draft.blockingDriveway { bits.append(bd ? "blocking driveway" : "not blocking driveway") }
        return bits.isEmpty ? nil : bits.joined(separator: " · ")
    }

    private func colorCategory(_ name: String?) -> Color {
        switch name?.lowercased() {
        case "blue":             return Color(red: 58/255, green: 90/255, blue: 154/255)
        case "red":              return Color(red: 200/255, green: 50/255, blue: 50/255)
        case "black":            return Color(red: 30/255, green: 30/255, blue: 30/255)
        case "white":            return Color(red: 240/255, green: 240/255, blue: 240/255)
        case "gray", "silver":   return Color(red: 140/255, green: 140/255, blue: 140/255)
        case "green":            return Color(red: 50/255, green: 140/255, blue: 80/255)
        case "yellow", "gold":   return Color(red: 220/255, green: 190/255, blue: 60/255)
        case "orange":           return Color(red: 235/255, green: 130/255, blue: 30/255)
        default:                 return Color(red: 180/255, green: 180/255, blue: 180/255)
        }
    }

    private func relativeDate(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .short
        return f.localizedString(for: d, relativeTo: .now)
    }
}
