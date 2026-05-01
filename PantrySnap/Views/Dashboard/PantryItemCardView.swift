import SwiftUI

struct PantryItemCardView: View {
    let item: PantryItem
    let daysRemaining: Double
    let stockLevel: StockLevel

    private var badgeColor: Color { .stockColor(for: stockLevel) }

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail or category icon
            Group {
                if let urlString = item.thumbnailURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        categoryIcon
                    }
                } else {
                    categoryIcon
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline).fontWeight(.medium)
                    .lineLimit(1)
                if let brand = item.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(item.quantity.formatted()) \(item.unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            // Days remaining badge
            VStack(alignment: .trailing, spacing: 2) {
                Text(daysRemainingLabel)
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(badgeColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(badgeColor.opacity(0.12))
                    .clipShape(Capsule())

                if item.isLowStock {
                    Text(stockLevel.label)
                        .font(.caption2)
                        .foregroundStyle(badgeColor)
                }
            }
        }
        .padding(.vertical, 4)
        .background(
            item.isLowStock
                ? badgeColor.opacity(0.05)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var daysRemainingLabel: String {
        let d = Int(daysRemaining.rounded())
        return d == 1 ? "1 day" : "\(max(0, d)) days"
    }

    private var categoryIcon: some View {
        Image(systemName: item.category.systemImage)
            .font(.title3)
            .foregroundStyle(.secondary)
            .frame(width: 44, height: 44)
            .background(Color(.tertiarySystemBackground))
    }
}

// MARK: - Preview

#Preview {
    let item = PantryItem(name: "Whole milk", brand: "Organic Valley", category: .dairy, quantity: 1, unit: "gal")
    return List {
        PantryItemCardView(item: item, daysRemaining: 2, stockLevel: .critical)
        PantryItemCardView(item: item, daysRemaining: 5, stockLevel: .low)
        PantryItemCardView(item: item, daysRemaining: 12, stockLevel: .ok)
    }
}
