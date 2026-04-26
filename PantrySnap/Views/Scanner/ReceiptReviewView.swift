import SwiftUI

struct ReceiptReviewView: View {
    @Environment(\.dismiss) private var dismiss

    let result: ReceiptParseResult
    let onConfirm: ([String]) -> Void

    @State private var items: [ReceiptLineItem]

    init(result: ReceiptParseResult, onConfirm: @escaping ([String]) -> Void) {
        self.result = result
        self.onConfirm = onConfirm
        _items = State(initialValue: result.items)
    }

    private var selectedCount: Int { items.filter(\.isSelected).count }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    itemList
                }
            }
            .navigationTitle("Review receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selectedCount)") {
                        let names = items.filter(\.isSelected).map(\.name)
                        onConfirm(names)
                        dismiss()
                    }
                    .disabled(selectedCount == 0)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sub-views

    private var itemList: some View {
        List {
            if let date = result.detectedDate {
                Section {
                    LabeledContent("Receipt date", value: date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                }
            }

            Section {
                Button(selectedCount == items.count ? "Deselect all" : "Select all") {
                    let allSelected = selectedCount == items.count
                    for i in items.indices { items[i].isSelected = !allSelected }
                }
                .font(.subheadline)
            }

            Section("Detected items (\(items.count))") {
                ForEach(items.indices, id: \.self) { i in
                    HStack {
                        Image(systemName: items[i].isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(items[i].isSelected ? Color.accentColor : .secondary)
                        Text(items[i].name)
                            .font(.subheadline)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { items[i].isSelected.toggle() }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("No items detected")
                .font(.title3).fontWeight(.semibold)
            Text("We couldn't find any grocery items in this receipt. Try a clearer photo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}
