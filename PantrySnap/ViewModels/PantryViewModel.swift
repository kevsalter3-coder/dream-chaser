import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.pantrysnap", category: "PantryViewModel")

@MainActor
final class PantryViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedCategory: ItemCategory? = nil
    @Published var sortOrder: SortOrder = .byDaysRemaining
    @Published var pendingReorderItem: PantryItem? = nil

    enum SortOrder: String, CaseIterable {
        case byName          = "By Name"
        case byDaysRemaining = "By Days Remaining"
    }

    private let notificationService = NotificationService.shared

    // MARK: - Derived helpers

    func daysRemaining(for item: PantryItem) -> Double {
        DepletionModel.daysRemaining(for: item)
    }

    func stockLevel(for item: PantryItem) -> StockLevel {
        DepletionModel.stockColor(daysRemaining: daysRemaining(for: item))
    }

    // MARK: - Mutations

    func markUsedUp(_ item: PantryItem, context: ModelContext) {
        let consumed = item.quantity
        item.logUsage(quantity: consumed)
        item.quantity = 0
        item.lastModified = Date()
        item.notificationScheduled = false

        try? context.save()
        logger.info("Marked \(item.name) as used up")
        Task { await notificationService.cancelAlert(for: item.id) }
    }

    func delete(_ item: PantryItem, context: ModelContext) {
        Task { await notificationService.cancelAlert(for: item.id) }
        context.delete(item)
        try? context.save()
    }

    func addItem(_ result: ProductLookupResult, barcode: String?, quantity: Double, unit: String, context: ModelContext) {
        let item = PantryItem(
            name: result.name,
            brand: result.brand,
            barcode: barcode,
            category: result.category,
            quantity: quantity,
            unit: unit,
            thumbnailURL: result.imageURL?.absoluteString
        )
        context.insert(item)
        try? context.save()
        scheduleLowStockNotificationIfNeeded(item)
        logger.info("Added pantry item: \(item.name)")
    }

    func addManualItem(name: String, barcode: String?, category: ItemCategory, quantity: Double, unit: String, context: ModelContext) {
        let item = PantryItem(
            name: name,
            barcode: barcode,
            category: category,
            quantity: quantity,
            unit: unit
        )
        context.insert(item)
        try? context.save()
        scheduleLowStockNotificationIfNeeded(item)
    }

    func addItems(_ names: [String], context: ModelContext) {
        for name in names {
            let item = PantryItem(name: name)
            context.insert(item)
        }
        try? context.save()
    }

    func updateQuantity(_ item: PantryItem, to newQuantity: Double, context: ModelContext) {
        let diff = item.quantity - newQuantity
        if diff > 0 { item.logUsage(quantity: diff) }
        item.quantity = newQuantity
        item.lastModified = Date()
        try? context.save()
        scheduleLowStockNotificationIfNeeded(item)
    }

    // MARK: - Filtering / grouping

    func filtered(items: [PantryItem]) -> [PantryItem] {
        var result = items

        if let cat = selectedCategory {
            result = result.filter { $0.category == cat }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.brand?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        result.sort { a, b in
            let aLow = a.isLowStock
            let bLow = b.isLowStock
            if aLow != bLow { return aLow }           // low-stock floats to top
            switch sortOrder {
            case .byName:          return a.name < b.name
            case .byDaysRemaining: return daysRemaining(for: a) < daysRemaining(for: b)
            }
        }
        return result
    }

    func grouped(items: [PantryItem]) -> [(category: ItemCategory, items: [PantryItem])] {
        let filtered = filtered(items: items)
        return ItemCategory.allCases.compactMap { cat in
            let catItems = filtered.filter { $0.category == cat }
            return catItems.isEmpty ? nil : (category: cat, items: catItems)
        }
    }

    // MARK: - Notifications

    private func scheduleLowStockNotificationIfNeeded(_ item: PantryItem) {
        let days = DepletionModel.daysRemaining(for: item)
        guard item.isLowStock, !item.notificationScheduled else { return }
        item.notificationScheduled = true
        Task { await notificationService.scheduleLowStockAlert(for: item, daysRemaining: days) }
    }
}
