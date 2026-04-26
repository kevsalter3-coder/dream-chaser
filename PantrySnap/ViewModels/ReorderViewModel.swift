import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.reup365", category: "ReorderViewModel")

@MainActor
final class ReorderViewModel: ObservableObject {
    @Published var isLoading     = false
    @Published var errorMessage: String? = nil
    @Published var cartURL: URL? = nil
    @Published var didSendToCart = false

    private let instacartService = InstacartService()
    private let errorFeedback    = UINotificationFeedbackGenerator()

    func sendToInstacart(items: [PantryItem]) async {
        isLoading = true
        errorMessage = nil

        let cartItems = items.map {
            InstacartCartItem(name: $0.name, quantity: max(1, Int($0.quantity)), upc: $0.barcode)
        }

        do {
            let url = try await instacartService.createCart(items: cartItems)
            cartURL = url
            didSendToCart = true
            await instacartService.openCart(url: url)
            logger.info("Cart sent to Instacart: \(url.absoluteString)")
        } catch {
            errorMessage = error.localizedDescription
            errorFeedback.notificationOccurred(.error)
            logger.error("Instacart cart creation failed: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func suggestedQuantity(for item: PantryItem) -> Int {
        // Re-order roughly enough to last one typical cycle based on depletion history.
        guard item.usageHistory.count >= 2 else { return 1 }
        let avgDailyConsumption = item.usageHistory.reduce(0) { $0 + $1.quantityConsumed }
            / Double(item.usageHistory.count)
        let targetDays: Double = 14
        return max(1, Int((avgDailyConsumption * targetDays).rounded(.up)))
    }
}
