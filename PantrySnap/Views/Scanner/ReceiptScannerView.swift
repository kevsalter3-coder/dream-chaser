import SwiftUI
import AVFoundation
import UIKit

struct ReceiptScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var pantryVM: PantryViewModel
    @Environment(\.modelContext) private var context

    @State private var parseResult: ReceiptParseResult? = nil
    @State private var isProcessing = false
    @State private var showReview   = false
    @State private var showDateWarning = false
    @State private var capturedImage: UIImage? = nil
    @State private var showPicker   = true

    var body: some View {
        NavigationStack {
            Group {
                if isProcessing {
                    processingView
                } else {
                    cameraCaptureView
                }
            }
            .navigationTitle("Scan receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showReview) {
            if let result = parseResult {
                ReceiptReviewView(result: result) { confirmedNames in
                    pantryVM.addItems(confirmedNames, context: context)
                    dismiss()
                }
            }
        }
        .alert("Old receipt detected", isPresented: $showDateWarning) {
            Button("Import anyway") { showReview = true }
            Button("Cancel", role: .cancel) { capturedImage = nil }
        } message: {
            Text("This receipt appears to be more than 7 days old. Items may already be depleted.")
        }
    }

    // MARK: - Sub-views

    private var cameraCaptureView: some View {
        VStack(spacing: 20) {
            Spacer()

            // Receipt alignment guide
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [8]))
                    .frame(width: 260, height: 400)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("Align receipt here")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            }

            Spacer()

            Button {
                showPicker = true
            } label: {
                Label("Take photo", systemImage: "camera")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 32).padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showPicker) {
            ReceiptImagePicker { image in
                capturedImage = image
                Task { await processReceipt(image: image) }
            }
        }
    }

    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.8)
            Text("Reading receipt…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - OCR processing

    private func processReceipt(image: UIImage) async {
        isProcessing = true
        let service = OCRService()
        do {
            let result = try await service.parseReceipt(from: image)
            parseResult = result
            isProcessing = false

            if let date = result.detectedDate, date.isOlderThanOneWeek {
                showDateWarning = true
            } else {
                showReview = true
            }
        } catch {
            isProcessing = false
        }
    }
}

// MARK: - Receipt image picker (UIImagePickerController wrapper)

struct ReceiptImagePicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = AVCaptureDevice.isInputAvailable(for: .video) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
