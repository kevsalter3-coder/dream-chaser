import SwiftUI

struct ReorderSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var reorderVM = ReorderViewModel()

    let items: [PantryItem]

    @State private var quantities: [UUID: Int] = [:]

    var body: some View {
        NavigationStack {
            Form {
                // Items section
                Section("Items to reorder") {
                    ForEach(items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).font(.subheadline).fontWeight(.medium)
                                if let brand = item.brand {
                                    Text(brand).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Stepper(
                                value: Binding(
                                    get: { quantities[item.id] ?? reorderVM.suggestedQuantity(for: item) },
                                    set: { quantities[item.id] = $0 }
                                ),
                                in: 1...99
                            ) {
                                Text("\(quantities[item.id] ?? reorderVM.suggestedQuantity(for: item))")
                                    .monospacedDigit()
                                    .frame(minWidth: 28, alignment: .trailing)
                            }
                        }
                    }
                }

                // Status
                if let error = reorderVM.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }

                if reorderVM.didSendToCart {
                    Section {
                        Label("Items added to your Instacart cart", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                // CTA
                Section {
                    Button {
                        Task { await reorderVM.sendToInstacart(items: itemsWithQuantities) }
                    } label: {
                        HStack {
                            Spacer()
                            if reorderVM.isLoading {
                                ProgressView()
                            } else {
                                Label("Send to Instacart", systemImage: "cart")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(reorderVM.isLoading)
                    .listRowBackground(Color.accentColor)
                    .foregroundStyle(.white)
                }
            }
            .navigationTitle("Reorder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            for item in items {
                quantities[item.id] = reorderVM.suggestedQuantity(for: item)
            }
        }
    }

    private var itemsWithQuantities: [PantryItem] {
        // Quantities are reflected in the cart items by ReorderViewModel
        items
    }
}

// MARK: - Preview

#Preview {
    ReorderSheetView(items: [
        PantryItem(name: "Whole milk", brand: "Organic Valley", category: .dairy, quantity: 0.5, unit: "gal"),
        PantryItem(name: "Eggs", brand: "Pete & Gerry's", category: .produce, quantity: 2, unit: "units"),
    ])
    .environmentObject(PantryViewModel())
}
