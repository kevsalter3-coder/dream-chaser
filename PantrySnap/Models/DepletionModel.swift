import Foundation

enum DepletionModel {
    /// Returns estimated days of stock remaining for the given item.
    /// Uses rolling average of usage history when ≥ 3 entries exist;
    /// otherwise falls back to per-category defaults.
    static func daysRemaining(for item: PantryItem) -> Double {
        guard item.quantity > 0 else { return 0 }

        let history = item.usageHistory
        if history.count >= 3 {
            let totalConsumed = history.reduce(0) { $0 + $1.quantityConsumed }
            guard
                let earliest = history.map(\.date).min(),
                let latest   = history.map(\.date).max()
            else { return item.category.defaultDaysRemaining }

            let spanDays = Calendar.current.dateComponents([.day], from: earliest, to: latest).day ?? 1
            let days = max(1, spanDays)
            let avgDailyConsumption = totalConsumed / Double(days)
            guard avgDailyConsumption > 0 else { return item.category.defaultDaysRemaining }
            return item.quantity / avgDailyConsumption
        }

        return item.category.defaultDaysRemaining
    }

    static func stockColor(daysRemaining days: Double) -> StockLevel {
        switch days {
        case ..<3:  return .critical
        case 3..<7: return .low
        default:    return .ok
        }
    }
}

enum StockLevel {
    case ok, low, critical

    var label: String {
        switch self {
        case .ok:       return "OK"
        case .low:      return "Low"
        case .critical: return "Critical"
        }
    }
}
