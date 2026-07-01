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

/// Full-screen live camera QR/barcode scanner. Calls `onScanned` with the parsed
/// vehicle number once, then dismisses.
struct VeoScannerView: UIViewControllerRepresentable {
    let onScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> ScannerController {
        let c = ScannerController()
        c.onScanned = { value in
            context.coordinator.deliverOnce(value)
        }
        return c
    }
    func updateUIViewController(_ vc: ScannerController, context: Context) {}
    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned, dismiss: { dismiss() })
    }

    final class Coordinator {
        private let onScanned: (String) -> Void
        private let dismiss: () -> Void
        private var delivered = false
        init(onScanned: @escaping (String) -> Void, dismiss: @escaping () -> Void) {
            self.onScanned = onScanned; self.dismiss = dismiss
        }
        func deliverOnce(_ raw: String) {
            guard !delivered else { return }
            delivered = true
            onScanned(VeoCodeParser.parseVehicleNumber(from: raw))
            dismiss()
        }
    }

    final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onScanned: ((String) -> Void)?
        private let session = AVCaptureSession()

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            session.addInput(input)
            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr, .aztec, .code128, .code39, .dataMatrix, .ean13]
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
