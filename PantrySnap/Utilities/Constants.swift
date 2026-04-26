import Foundation

enum Constants {
    enum API {
        static let openFoodFactsBase    = "https://world.openfoodfacts.org/api/v2"
        static let instacartBase        = "https://connect.instacart.com/v2"
        // Polite identification header for Open Food Facts (not a secret)
        static let openFoodFactsAgent   = "PantrySnap/1.0 (iOS; contact@pantrysnap.app)"
    }

    enum Keychain {
        static let instacartAPIKey = "com.pantrysnap.instacart_api_key"
    }

    enum Notification {
        static let lowStockCategory     = "LOW_STOCK_ALERT"
        static let itemIDKey            = "itemID"
    }

    enum AppStorage {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    enum Depletion {
        static let defaultReorderThreshold: Double = 3.0
    }
}
