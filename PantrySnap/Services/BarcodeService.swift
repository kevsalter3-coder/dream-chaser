import Foundation
import OSLog

private let logger = Logger(subsystem: "com.reup365", category: "BarcodeService")

struct ProductLookupResult {
    let name: String
    let brand: String?
    let category: ItemCategory
    let imageURL: URL?
}

// Maps Open Food Facts category tag keywords to our ItemCategory enum.
private let categoryKeywordMap: [String: ItemCategory] = [
    "dairy":       .dairy,
    "milk":        .dairy,
    "cheese":      .dairy,
    "yogurt":      .dairy,
    "egg":         .dairy,
    "fruit":       .produce,
    "vegetable":   .produce,
    "produce":     .produce,
    "fresh":       .produce,
    "frozen":      .frozen,
    "ice":         .frozen,
    "beverage":    .beverages,
    "drink":       .beverages,
    "juice":       .beverages,
    "water":       .beverages,
    "soda":        .beverages,
    "household":   .household,
    "cleaning":    .household,
    "detergent":   .household,
]

final class BarcodeService {
    private let client = APIClient()

    // Cache barcode → result to avoid repeat API calls.
    private var cache: [String: ProductLookupResult] = [:]

    func lookup(barcode: String) async throws -> ProductLookupResult? {
        if let cached = cache[barcode] { return cached }

        guard let url = URL(string: "\(Constants.API.openFoodFactsBase)/product/\(barcode).json") else {
            throw APIError.invalidURL
        }

        let headers = ["User-Agent": Constants.API.openFoodFactsAgent]

        let response: OFFProductResponse
        do {
            response = try await client.get(url: url, headers: headers)
        } catch {
            logger.warning("Barcode lookup failed for \(barcode): \(error.localizedDescription)")
            return nil
        }

        guard response.status == 1, let product = response.product else {
            logger.info("No product found for barcode \(barcode)")
            return nil
        }

        let name   = product.product_name?.trimmingCharacters(in: .whitespaces) ?? ""
        let brand  = product.brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }

        let category = Self.mapCategory(tags: product.categories_tags ?? [])
        let imageURL = product.image_url.flatMap { URL(string: $0) }

        let result = ProductLookupResult(name: name, brand: brand, category: category, imageURL: imageURL)
        cache[barcode] = result
        return result
    }

    private static func mapCategory(tags: [String]) -> ItemCategory {
        let normalized = tags.joined(separator: " ").lowercased()
        for (keyword, category) in categoryKeywordMap {
            if normalized.contains(keyword) { return category }
        }
        return .pantryStaples
    }
}

// MARK: - Decodable response types

private struct OFFProductResponse: Decodable {
    let status: Int
    let product: OFFProduct?
}

private struct OFFProduct: Decodable {
    let product_name: String?
    let brands: String?
    let categories_tags: [String]?
    let image_url: String?
}
