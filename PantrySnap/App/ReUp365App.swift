import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.reup365", category: "App")

@main
struct ReUp365App: App {
    @AppStorage(Constants.AppStorage.hasCompletedOnboarding) private var hasCompletedOnboarding = false

    @StateObject private var pantryVM = PantryViewModel()

    @State private var reorderItemID: UUID? = nil
    @State private var showReorderSheet = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                        .environmentObject(pantryVM)
                } else {
                    OnboardingView()
                }
            }
            .modelContainer(sharedModelContainer)
            // Observe the singleton's @Published property via onReceive
            .onReceive(NotificationService.shared.$pendingItemID) { id in
                guard let id else { return }
                reorderItemID = id
                showReorderSheet = true
            }
        }
    }

    // MARK: - SwiftData container

    private var sharedModelContainer: ModelContainer = {
        let schema = Schema([PantryItem.self, Household.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            logger.fault("Failed to create ModelContainer: \(error.localizedDescription)")
            fatalError("Could not initialize SwiftData: \(error)")
        }
    }()
}

// MARK: - Root tab view

struct ContentView: View {
    @EnvironmentObject private var pantryVM: PantryViewModel
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            PantryDashboardView()
                .tabItem { Label("Pantry", systemImage: "refrigerator") }

            AlertsView()
                .tabItem { Label("Alerts", systemImage: "bell.badge") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

// MARK: - Alerts tab (low-stock items quick view)

struct AlertsView: View {
    @EnvironmentObject private var pantryVM: PantryViewModel
    @Query private var allItems: [PantryItem]

    @State private var reorderItem: PantryItem? = nil

    private var lowStockItems: [PantryItem] {
        allItems.filter(\.isLowStock).sorted {
            DepletionModel.daysRemaining(for: $0) < DepletionModel.daysRemaining(for: $1)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if lowStockItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 56))
                            .foregroundStyle(.green)
                        Text("All stocked up")
                            .font(.title3).fontWeight(.semibold)
                        Text("No items are running low right now.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(lowStockItems) { item in
                        HStack {
                            PantryItemCardView(
                                item: item,
                                daysRemaining: pantryVM.daysRemaining(for: item),
                                stockLevel: pantryVM.stockLevel(for: item)
                            )
                            Button {
                                reorderItem = item
                            } label: {
                                Image(systemName: "cart.badge.plus")
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Alerts")
            .sheet(item: $reorderItem) { item in
                ReorderSheetView(items: [item])
            }
        }
        .badge(lowStockItems.count)
    }
}
