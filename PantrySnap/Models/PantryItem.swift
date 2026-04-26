import Foundation
import SwiftData

enum ItemCategory: String, Codable, CaseIterable {
    case produce        = "Produce"
    case dairy          = "Dairy"
    case pantryStaples  = "Pantry Staples"
    case frozen         = "Frozen"
    case beverages      = "Beverages"
    case household      = "Household"

    var defaultDaysRemaining: Double {
        switch self {
        case .produce:       return 3
        case .dairy:         return 5
        case .pantryStaples: return 30
        case .frozen:        return 60
        case .beverages:     return 14
        case .household:     return 45
        }
    }

    var systemImage: String {
        switch self {
        case .produce:       return "leaf"
        case .dairy:         return "cup.and.saucer"
        case .pantryStaples: return "cabinet"
        case .frozen:        return "snowflake"
        case .beverages:     return "drop"
        case .household:     return "house"
        }
    }
}

struct UsageEntry: Codable {
    var date: Date
    var quantityConsumed: Double
}

@Model
class PantryItem {
    var id: UUID
    var name: String
    var brand: String?
    var barcode: String?
    var category: ItemCategory
    var quantity: Double
    var unit: String
    var thumbnailURL: String?
    var dateAdded: Date
    var lastModified: Date
    var lastModifiedBy: String?
    var usageHistory: [UsageEntry]
    var reorderThreshold: Double
    var notificationScheduled: Bool

    var isLowStock: Bool {
        DepletionModel.daysRemaining(for: self) <= reorderThreshold
    }

    init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        barcode: String? = nil,
        category: ItemCategory = .pantryStaples,
        quantity: Double = 1,
        unit: String = "units",
        thumbnailURL: String? = nil,
        reorderThreshold: Double = 3.0,
        lastModifiedBy: String? = nil
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.thumbnailURL = thumbnailURL
        self.dateAdded = Date()
        self.lastModified = Date()
        self.lastModifiedBy = lastModifiedBy
        self.usageHistory = []
        self.reorderThreshold = reorderThreshold
        self.notificationScheduled = false
    }

    func logUsage(quantity consumed: Double) {
        usageHistory.append(UsageEntry(date: Date(), quantityConsumed: consumed))
        lastModified = Date()
    }
}
