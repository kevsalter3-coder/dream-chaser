import SwiftUI
import SwiftData

struct PantryDashboardView: View {
    @Environment(\.modelContext)  private var context
    @EnvironmentObject           private var pantryVM: PantryViewModel
    @Query                       private var allItems: [PantryItem]

    @State private var showScanner     = false
    @State private var showReceipt     = false
    @State private var selectedItem:    PantryItem? = nil
    @State private var reorderItem:     PantryItem? = nil

    private var grouped: [(category: ItemCategory, items: [PantryItem])] {
        pantryVM.grouped(items: allItems)
    }

    var body: some View {
        NavigationStack {
            Group {
                if allItems.isEmpty {
                    emptyState
                } else {
                    itemList
                }
            }
            .navigationTitle("My Pantry")
            .searchable(text: $pantryVM.searchText, prompt: "Search items")
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) { scanFAB }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView()
            }
            .sheet(isPresented: $showReceipt) {
                ReceiptScannerView()
            }
            .sheet(item: $selectedItem) { item in
                PantryItemDetailView(item: item)
                    .environmentObject(pantryVM)
            }
            .sheet(item: $reorderItem) { item in
                ReorderSheetView(items: [item])
            }
        }
    }

    // MARK: - Sub-views

    private var itemList: some View {
        List {
            // Category filter picker
            Section {
                Picker("Category", selection: $pantryVM.selectedCategory) {
                    Text("All").tag(Optional<ItemCategory>.none)
                    ForEach(ItemCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(Optional(cat))
                    }
                }
                .pickerStyle(.menu)

                Picker("Sort", selection: $pantryVM.sortOrder) {
                    ForEach(PantryViewModel.SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
            }
            .listRowBackground(Color(.secondarySystemBackground))

            ForEach(grouped, id: \.category) { group in
                Section(group.category.rawValue) {
                    ForEach(group.items) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            PantryItemCardView(
                                item: item,
                                daysRemaining: pantryVM.daysRemaining(for: item),
                                stockLevel: pantryVM.stockLevel(for: item)
                            )
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                pantryVM.markUsedUp(item, context: context)
                            } label: {
                                Label("Used up", systemImage: "checkmark.circle")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pantryVM.delete(item, context: context)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            if item.isLowStock {
                                Button {
                                    reorderItem = item
                                } label: {
                                    Label("Reorder", systemImage: "cart")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "archivebox")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Your pantry is empty")
                .font(.title3).fontWeight(.semibold)
            Text("Scan a barcode or photograph a receipt to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                showScanner = true
            } label: {
                Label("Scan your first item", systemImage: "barcode.viewfinder")
                    .padding(.horizontal, 24).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scanFAB: some View {
        HStack(spacing: 16) {
            Button {
                showReceipt = true
            } label: {
                Image(systemName: "doc.text.viewfinder")
                    .font(.title3)
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }
            .accessibilityLabel("Scan receipt")

            Button {
                showScanner = true
            } label: {
                Label("Scan item", systemImage: "barcode.viewfinder")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 8, y: 4)
            }
        }
        .padding(.bottom, 8)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    showScanner = true
                } label: {
                    Label("Scan barcode", systemImage: "barcode.viewfinder")
                }
                Button {
                    showReceipt = true
                } label: {
                    Label("Scan receipt", systemImage: "doc.text.viewfinder")
                }
            } label: {
                Image(systemName: "plus")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PantryItem.self, Household.self, configurations: config)

    let items: [PantryItem] = [
        PantryItem(name: "Whole milk", brand: "Organic Valley", category: .dairy, quantity: 1, unit: "gal"),
        PantryItem(name: "Sharp cheddar", brand: "Tillamook", category: .dairy, quantity: 8, unit: "oz"),
        PantryItem(name: "Diced tomatoes", brand: "Muir Glen", category: .pantryStaples, quantity: 1, unit: "can"),
        PantryItem(name: "Eggs", brand: "Pete & Gerry's", category: .produce, quantity: 4, unit: "units"),
    ]
    items.forEach { container.mainContext.insert($0) }

    return PantryDashboardView()
        .modelContainer(container)
        .environmentObject(PantryViewModel())
}
