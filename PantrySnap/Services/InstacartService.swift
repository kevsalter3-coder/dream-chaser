import Foundation
import UIKit
import OSLog

private let logger = Logger(subsystem: "com.pantrysnap", category: "InstacartService")

struct InstacartCartItem {
    let name: String
    let quantity: Int
    let upc: String?
}

final class InstacartService {
    private var apiKey: String? { KeychainService.load(key: Constants.Keychain.instacartAPIKey) }
    private let client = APIClient()

    /// Creates an Instacart cart and returns the handoff URL.
    /// Falls back to a deep-link search URL if the API is unavailable or key is missing.
    func createCart(items: [InstacartCartItem], partnerName: String = "PantrySnap") async throws -> URL {
        guard let key = apiKey, !key.isEmpty else {
            logger.warning("No Instacart API key — falling back to deep link")
            return deepLinkURL(for: items.first?.name ?? "")
        }

        guard let url = URL(string: "\(Constants.API.instacartBase)/partners/carts") else {
            throw APIError.invalidURL
        }

        let lineItems = items.map { CartRequestItem(name: $0.name, quantity: $0.quantity, upc: $0.upc) }
        let body = CartRequest(partner_name: partnerName, line_items: lineItems)

        let response: CartResponse = try await client.post(
            url: url,
            body: body,
            headers: [
                "Authorization": "Bearer \(key)",
                "Accept": "application/json"
            ]
        )

        guard let cartURL = URL(string: response.cart_url) else {
            throw APIError.invalidURL
        }

        return cartURL
    }

    /// Opens the handoff URL, preferring universal links then falling back to https.
    func openCart(url: URL) async {
        await MainActor.run {
            UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { opened in
                if !opened {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    // Constructs `instacart://search?q=<name>` deep link for graceful fallback.
    private func deepLinkURL(for name: String) -> URL {
        var components = URLComponents()
        components.scheme = "instacart"
        components.host   = "search"
        components.queryItems = [URLQueryItem(name: "q", value: name)]
        return components.url ?? URL(string: "https://www.instacart.com")!
    }
}

// MARK: - Codable request / response shapes

private struct CartRequest: Encodable {
    let partner_name: String
    let line_items: [CartRequestItem]
}

private struct CartRequestItem: Encodable {
    let name: String
    let quantity: Int
    let upc: String?
}

private struct CartResponse: Decodable {
    let cart_url: String
}
