import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject           private var pantryVM: PantryViewModel

    @StateObject private var scannerVM = ScannerViewModel()
    @State private var lookupResult: ProductLookupResult? = nil
    @State private var isLookingUp = false
    @State private var showConfirmSheet = false
    @State private var lookupFailed = false
    @State private var manualName = ""

    private let barcodeService = BarcodeService()

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview or permission gate
                switch scannerVM.authorizationStatus {
                case .authorized:
                    cameraLayer
                case .notDetermined:
                    permissionPrompt
                default:
                    deniedView
                }
            }
            .ignoresSafeArea(edges: .all)
            .navigationTitle("Scan item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            if scannerVM.authorizationStatus == .authorized {
                await scannerVM.requestCameraPermission()
            }
        }
        .onChange(of: scannerVM.scannedBarcode) { _, barcode in
            guard let barcode else { return }
            Task { await handleScan(barcode: barcode) }
        }
        .sheet(isPresented: $showConfirmSheet, onDismiss: { scannerVM.resumeScanning() }) {
            if let result = lookupResult {
                PantryItemConfirmSheet(result: result, barcode: scannerVM.scannedBarcode) { qty, unit in
                    pantryVM.addItem(result, barcode: scannerVM.scannedBarcode, quantity: qty, unit: unit, context: context)
                    dismiss()
                }
            } else {
                manualEntrySheet
            }
        }
    }

    // MARK: - Camera layer

    private var cameraLayer: some View {
        ZStack {
            CameraPreviewLayer(session: scannerVM.captureSession)

            // Frosted scanning reticle
            VStack {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.8), lineWidth: 2)
                        .frame(width: 260, height: 140)

                    // Corner accent marks
                    ScannerReticle()
                        .frame(width: 260, height: 140)
                }
                .shadow(color: .black.opacity(0.3), radius: 8)

                Text(isLookingUp ? "Looking up…" : "Point at a barcode")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.top, 16)

                Spacer()
            }

            if isLookingUp {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
        .onAppear  { scannerVM.startSession() }
        .onDisappear { scannerVM.stopSession() }
    }

    // MARK: - Permission / denied views

    private var permissionPrompt: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Camera access required")
                .font(.title2).fontWeight(.semibold)
            Text("PantrySnap uses the camera to scan grocery barcodes and add them to your pantry automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Allow camera access") {
                Task { await scannerVM.requestCameraPermission() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.slash").font(.system(size: 56)).foregroundStyle(.secondary)
            Text("Camera access denied")
                .font(.title3).fontWeight(.semibold)
            Text("Open Settings to allow camera access for PantrySnap.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Manual entry sheet (fallback when lookup fails)

    private var manualEntrySheet: some View {
        NavigationStack {
            Form {
                Section("Item not found in database") {
                    TextField("Item name", text: $manualName)
                }
            }
            .navigationTitle("Name this item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !manualName.isEmpty else { return }
                        pantryVM.addManualItem(
                            name: manualName,
                            barcode: scannerVM.scannedBarcode,
                            category: .pantryStaples,
                            quantity: 1,
                            unit: "units",
                            context: context
                        )
                        dismiss()
                    }
                    .disabled(manualName.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { scannerVM.resumeScanning(); showConfirmSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Lookup

    private func handleScan(barcode: String) async {
        isLookingUp = true
        do {
            lookupResult = try await barcodeService.lookup(barcode: barcode)
        } catch {
            lookupResult = nil
        }
        lookupFailed = lookupResult == nil
        isLookingUp = false
        showConfirmSheet = true
    }
}

// MARK: - Camera preview UIViewRepresentable

struct CameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        context.coordinator.previewLayer = layer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Scanning reticle

private struct ScannerReticle: View {
    private let length: CGFloat = 20
    private let lineWidth: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Path { path in
                // Top-left
                path.move(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: length, y: 0))
                // Top-right
                path.move(to: CGPoint(x: w - length, y: 0))
                path.addLine(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: length))
                // Bottom-left
                path.move(to: CGPoint(x: 0, y: h - length))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: length, y: h))
                // Bottom-right
                path.move(to: CGPoint(x: w - length, y: h))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: w, y: h - length))
            }
            .stroke(Color.accentColor, lineWidth: lineWidth)
        }
    }
}
