import SwiftUI
import AVFoundation
import Vision
import UIKit

/// Decodes a QR/barcode from a still image via Vision.
enum VeoPhotoQR {
    static func scan(_ image: UIImage) -> String? {
        guard let cg = image.cgImage else { return nil }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr, .aztec, .code128, .code39, .dataMatrix, .ean13]
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try? handler.perform([request])
        let payload = (request.results as? [VNBarcodeObservation])?
            .compactMap { $0.payloadStringValue }.first
        return payload.map(VeoCodeParser.parseVehicleNumber)
    }
}

/// Full-screen live QR/barcode scanner with an aiming reticle, instructions, and
/// a close button. Calls `onScanned` with the parsed vehicle number and dismisses.
struct VeoScannerScreen: View {
    let onScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraScannerView(onScanned: { value in
                onScanned(value)
                dismiss()
            })
            .ignoresSafeArea()

            // Dimmed surround with a clear square cutout in the center.
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height) * 0.68
                let rect = CGRect(x: (geo.size.width - side) / 2,
                                  y: (geo.size.height - side) / 2,
                                  width: side, height: side)
                ZStack {
                    Color.black.opacity(0.55)
                        .mask {
                            Rectangle()
                                .overlay {
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .frame(width: side, height: side)
                                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                                        .blendMode(.destinationOut)
                                }
                                .compositingGroup()
                        }
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: side, height: side)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    reticleCorners(in: rect)
                }
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                topBar
                Spacer()
                instructions
                    .padding(.bottom, 60)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .accessibilityLabel("Close scanner")
            Spacer()
            Text("Scan vehicle QR")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 40, height: 40) // balance the X
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var instructions: some View {
        VStack(spacing: 6) {
            Text("Point at the vehicle's QR code")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Text("It's in the center of the handlebars. Hold steady until it scans.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .shadow(color: .black.opacity(0.6), radius: 6)
    }

    /// Four green corner brackets hugging the reticle for a "scanner" cue.
    private func reticleCorners(in rect: CGRect) -> some View {
        let len: CGFloat = 26
        let lw: CGFloat = 4
        let green = Color.brandGreen
        return ZStack {
            corner(len: len, lw: lw, color: green, rotation: 0)
                .position(x: rect.minX + len/2, y: rect.minY + len/2)
            corner(len: len, lw: lw, color: green, rotation: 90)
                .position(x: rect.maxX - len/2, y: rect.minY + len/2)
            corner(len: len, lw: lw, color: green, rotation: 270)
                .position(x: rect.minX + len/2, y: rect.maxY - len/2)
            corner(len: len, lw: lw, color: green, rotation: 180)
                .position(x: rect.maxX - len/2, y: rect.maxY - len/2)
        }
    }

    private func corner(len: CGFloat, lw: CGFloat, color: Color, rotation: Double) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: len))
            p.addLine(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: len, y: 0))
        }
        .stroke(color, style: StrokeStyle(lineWidth: lw, lineCap: .round))
        .frame(width: len, height: len)
        .rotationEffect(.degrees(rotation))
    }
}

/// Live camera preview that decodes QR/barcodes and reports the parsed value
/// once. Presentation/dismissal is owned by the hosting `VeoScannerScreen`.
struct CameraScannerView: UIViewControllerRepresentable {
    let onScanned: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let c = ScannerController()
        c.onScanned = { raw in context.coordinator.deliverOnce(raw) }
        return c
    }
    func updateUIViewController(_ vc: ScannerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onScanned: onScanned) }

    final class Coordinator {
        private let onScanned: (String) -> Void
        private var delivered = false
        init(onScanned: @escaping (String) -> Void) { self.onScanned = onScanned }
        func deliverOnce(_ raw: String) {
            guard !delivered else { return }
            delivered = true
            onScanned(VeoCodeParser.parseVehicleNumber(from: raw))
        }
    }

    final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onScanned: ((String) -> Void)?
        private let session = AVCaptureSession()
        private let metadataOutput = AVCaptureMetadataOutput()

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            session.addInput(input)
            guard session.canAddOutput(metadataOutput) else { return }
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = [.qr, .aztec, .code128, .code39, .dataMatrix, .ean13]
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.layer.bounds
            view.layer.addSublayer(preview)
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            if !session.isRunning {
                DispatchQueue.global(qos: .userInitiated).async { [session] in session.startRunning() }
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            // Break the AVCaptureMetadataOutput -> delegate (self) strong reference
            // so the controller + capture graph deallocate instead of leaking.
            metadataOutput.setMetadataObjectsDelegate(nil, queue: nil)
            if session.isRunning { session.stopRunning() }
        }

        nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput objects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let obj = objects.first as? AVMetadataMachineReadableCodeObject,
                  let value = obj.stringValue else { return }
            Task { @MainActor in self.onScanned?(value) }
        }
    }
}
