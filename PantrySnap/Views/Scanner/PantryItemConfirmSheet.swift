import SwiftUI

struct PantryItemConfirmSheet: View {
    let result: ProductLookupResult
    let barcode: String?
    let onConfirm: (Double, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var quantity: Double = 1
    @State private var unit: String = "units"

    private let selectionFeedback = UISelectionFeedbackGenerator()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Item summary
                HStack(spacing: 16) {
                    Group {
                        if let url = result.imageURL {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color(.tertiarySystemBackground)
                            }
                        } else {
                            Color(.tertiarySystemBackground)
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.name)
                            .font(.headline)
                        if let brand = result.brand {
                            Text(brand)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(result.category.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    Spacer(minLength: 0)
                }
                .padding()
                .background(Color(.secondarySystemBackground))

                Form {
                    Section("Quantity") {
                        Stepper(value: $quantity, in: 0.5...99, step: 1) {
                            HStack {
                                Text("Amount")
                                Spacer()
                                Text("\(quantity.formatted())")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onChange(of: quantity) { _, _ in selectionFeedback.selectionChanged() }

                        HStack {
                            Text("Unit")
                            Spacer()
                            TextField("e.g. cans, oz, lbs", text: $unit)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let barcode {
                        Section {
                            LabeledContent("Barcode", value: barcode)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add to pantry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onConfirm(quantity, unit)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            // Pre-fill unit from category heuristic
            unit = defaultUnit(for: result.category)
        }
    }

    private func defaultUnit(for category: ItemCategory) -> String {
        switch category {
        case .produce:       return "lbs"
        case .dairy:         return "units"
        case .pantryStaples: return "cans"
        case .frozen:        return "units"
        case .beverages:     return "bottles"
        case .household:     return "units"
        }
    }
}

// MARK: - Preview

#Preview {
    PantryItemConfirmSheet(
        result: ProductLookupResult(
            name: "Organic Whole Milk",
            brand: "Organic Valley",
            category: .dairy,
            imageURL: nil
        ),
        barcode: "093966001100"
    ) { qty, unit in
        print("Confirmed: \(qty) \(unit)")
    }
}
