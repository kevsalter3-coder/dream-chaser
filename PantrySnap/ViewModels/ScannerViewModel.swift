import AVFoundation
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.pantrysnap", category: "ScannerViewModel")

@MainActor
final class ScannerViewModel: NSObject, ObservableObject {
    @Published var captureSession = AVCaptureSession()
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var scannedBarcode: String? = nil
    @Published var isSessionRunning = false
    @Published var error: ScannerError? = nil

    private let supportedTypes: [AVMetadataObject.ObjectType] = [
        .ean13, .ean8, .upce, .code128
    ]
    private let sessionQueue = DispatchQueue(label: "com.pantrysnap.camera", qos: .userInitiated)
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    override init() {
        super.init()
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    // MARK: - Permission

    func requestCameraPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        authorizationStatus = granted ? .authorized : .denied
        if granted { await configureSession() }
    }

    // MARK: - Session lifecycle (always called on sessionQueue)

    func startSession() {
        guard authorizationStatus == .authorized else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                Task { @MainActor in self.isSessionRunning = true }
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                Task { @MainActor in self.isSessionRunning = false }
            }
        }
    }

    func resumeScanning() {
        scannedBarcode = nil
        startSession()
    }

    // MARK: - Session configuration

    private func configureSession() async {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.beginConfiguration()
            defer { self.captureSession.commitConfiguration() }

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device)
            else {
                Task { @MainActor in self.error = .deviceUnavailable }
                return
            }

            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
            }

            let metadataOutput = AVCaptureMetadataOutput()
            if self.captureSession.canAddOutput(metadataOutput) {
                self.captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
                metadataOutput.metadataObjectTypes = self.supportedTypes
            } else {
                Task { @MainActor in self.error = .outputUnavailable }
            }
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension ScannerViewModel: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue
        else { return }

        Task { @MainActor [weak self] in
            guard let self, self.scannedBarcode == nil else { return }
            self.feedbackGenerator.impactOccurred()
            self.stopSession()
            self.scannedBarcode = value
            logger.info("Barcode scanned: \(value)")
        }
    }
}

enum ScannerError: LocalizedError {
    case deviceUnavailable
    case outputUnavailable
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .deviceUnavailable:  return "Camera device is unavailable."
        case .outputUnavailable:  return "Could not configure metadata output."
        case .permissionDenied:   return "Camera access was denied."
        }
    }
}
