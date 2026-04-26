import SwiftUI

/// Displayed after a successful Instacart cart creation to confirm handoff.
struct InstacartHandoffView: View {
    @Environment(\.dismiss) private var dismiss
    let cartURL: URL
    let itemCount: Int

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "cart.badge.plus")
                .font(.system(size: 64))
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text("Cart updated")
                    .font(.title2).fontWeight(.bold)
                Text("\(itemCount) item\(itemCount == 1 ? "" : "s") added to your Instacart cart.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("Open your Instacart app to review and checkout.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    UIApplication.shared.open(cartURL, options: [.universalLinksOnly: true]) { opened in
                        if !opened { UIApplication.shared.open(cartURL) }
                    }
                } label: {
                    Label("Open in Instacart", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)

                Button("Done") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)
        }
        .presentationDetents([.medium])
    }
}
