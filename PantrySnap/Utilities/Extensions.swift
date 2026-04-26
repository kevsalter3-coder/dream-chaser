import SwiftUI

extension Color {
    static func stockColor(for level: StockLevel) -> Color {
        switch level {
        case .ok:       return Color(.systemGreen)
        case .low:      return Color(.systemOrange)
        case .critical: return Color(.systemRed)
        }
    }
}

extension View {
    /// Applies a rounded card style using system background and border.
    func cardStyle(padding: CGFloat = 12) -> some View {
        self
            .padding(padding)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension Double {
    var daysRemainingText: String {
        let d = Int(self.rounded())
        return d == 1 ? "1 day left" : "\(d) days left"
    }
}

extension Date {
    var isOlderThanOneWeek: Bool {
        Calendar.current.dateComponents([.day], from: self, to: Date()).day ?? 0 >= 7
    }
}
