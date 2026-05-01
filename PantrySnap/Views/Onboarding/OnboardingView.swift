import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @AppStorage(Constants.AppStorage.hasCompletedOnboarding) private var hasCompleted = false

    @State private var currentPage = 0
    @State private var cameraPermissionGranted = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                WelcomePage().tag(0)
                ScanExplainerPage().tag(1)
                CameraPermissionPage(isGranted: $cameraPermissionGranted).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)

            // Navigation buttons
            HStack {
                if currentPage > 0 {
                    Button("Back") { currentPage -= 1 }
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if currentPage < 2 {
                    Button("Next") { currentPage += 1 }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Get started") {
                        hasCompleted = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentPage == 2 && !cameraPermissionGranted)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            // App icon placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.accentColor.gradient)
                    .frame(width: 100, height: 100)
                Image(systemName: "refrigerator")
                    .font(.system(size: 50))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 12) {
                Text("ReUp365")
                    .font(.largeTitle).fontWeight(.bold)
                Text("Your pantry, on autopilot.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text("Scan groceries, track what you have, and reorder before you run out — all in one tap.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Page 2: Scan explainer

private struct ScanExplainerPage: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("Scan anything")
                .font(.largeTitle).fontWeight(.bold)

            // Mock camera preview illustration
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 220, height: 160)

                VStack(spacing: 8) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentColor)
                    Text("Barcode or receipt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "barcode.viewfinder", title: "Barcode scanner",
                           detail: "Instantly identifies any grocery product")
                FeatureRow(icon: "doc.text.viewfinder", title: "Receipt OCR",
                           detail: "Photograph a receipt to bulk-import items")
                FeatureRow(icon: "bell.badge", title: "Smart alerts",
                           detail: "Get notified before you run out, not after")
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Page 3: Camera permission

private struct CameraPermissionPage: View {
    @Binding var isGranted: Bool

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: isGranted ? "camera.fill" : "camera")
                .font(.system(size: 70))
                .foregroundStyle(isGranted ? .green : Color.accentColor)
                .animation(.spring(), value: isGranted)

            VStack(spacing: 12) {
                Text(isGranted ? "Camera ready" : "Allow camera access")
                    .font(.largeTitle).fontWeight(.bold)
                    .animation(.default, value: isGranted)

                Text(isGranted
                    ? "You're all set! Tap Get started to begin scanning."
                    : "ReUp365 needs camera access to scan barcodes and receipts. Your camera is only used when you actively scan."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .animation(.default, value: isGranted)
            }

            if !isGranted {
                Button("Allow camera access") {
                    Task {
                        let granted = await AVCaptureDevice.requestAccess(for: .video)
                        await MainActor.run { isGranted = granted }
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()
            Spacer()
        }
        .onAppear {
            isGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
