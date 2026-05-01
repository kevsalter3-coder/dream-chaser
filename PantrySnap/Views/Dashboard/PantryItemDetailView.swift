import SwiftUI
import SwiftData

struct PantryItemDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var pantryVM: PantryViewModel

    @Bindable var item: PantryItem
    @State private var showReorder = false
    @State private var editingQuantity: Double

    private let selectionFeedback = UISelectionFeedbackGenerator()

    init(item: PantryItem) {
        self.item = item
        _editingQuantity = State(initialValue: item.quantity)
    }

    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name).font(.title3).fontWeight(.semibold)
                            if let brand = item.brand {
                                Text(brand).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        stockBadge
                    }
                    .padding(.vertical, 4)
                }

                // Quantity stepper
                Section("Quantity") {
                    HStack {
                        Text("On hand")
                        Spacer()
                        Stepper(
                            value: $editingQuantity,
                            in: 0...999,
                            step: 1,
                            onEditingChanged: { _ in }
                        ) {
                            Text("\(editingQuantity.formatted()) \(item.unit)")
                                .monospacedDigit()
                        }
                        .onChange(of: editingQuantity) { _, _ in
                            selectionFeedback.selectionChanged()
                        }
                    }

                    LabeledContent("Reorder below") {
                        Stepper(
                            value: $item.reorderThreshold,
                            in: 1...30,
                            step: 1
                        ) {
                            Text("\(Int(item.reorderThreshold)) days")
                        }
                    }
                }

                // Details
                Section("Details") {
                    LabeledContent("Category", value: item.category.rawValue)
                    LabeledContent("Added", value: item.dateAdded.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Last updated", value: item.lastModified.formatted(date: .abbreviated, time: .shortened))
                    if let who = item.lastModifiedBy {
                        LabeledContent("Updated by", value: who)
                    }
                    if let barcode = item.barcode {
                        LabeledContent("Barcode", value: barcode)
                    }
                }

                // Usage history
                if !item.usageHistory.isEmpty {
                    Section("Usage history") {
                        ForEach(item.usageHistory.sorted { $0.date > $1.date }.prefix(10), id: \.date) { entry in
                            HStack {
                                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("−\(entry.quantityConsumed.formatted()) \(item.unit)")
                                    .monospacedDigit()
                            }
                            .font(.subheadline)
                        }
                    }
                }

                // Reorder button
                if item.isLowStock {
                    Section {
                        Button {
                            showReorder = true
                        } label: {
                            Label("Reorder now", systemImage: "cart")
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.white)
                        }
                        .listRowBackground(Color.accentColor)
                    }
                }
            }
            .navigationTitle("Item details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showReorder) {
                ReorderSheetView(items: [item])
            }
        }
    }

    private var stockBadge: some View {
        let level = pantryVM.stockLevel(for: item)
        let color = Color.stockColor(for: level)
        return Text("\(Int(pantryVM.daysRemaining(for: item))) days left")
            .font(.caption).fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func saveChanges() {
        pantryVM.updateQuantity(item, to: editingQuantity, context: context)
        dismiss()
    }
}
