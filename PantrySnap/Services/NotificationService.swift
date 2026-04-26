import UserNotifications
import Combine
import OSLog

private let logger = Logger(subsystem: "com.reup365", category: "NotificationService")

final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        registerCategories()
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            logger.info("Notification permission \(granted ? "granted" : "denied")")
            return granted
        } catch {
            logger.error("Notification permission request error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Scheduling

    func scheduleLowStockAlert(for item: PantryItem, daysRemaining: Double) async {
        let content = UNMutableNotificationContent()
        content.title = "🛒 Running low on \(item.name)"
        content.body  = "You have about \(Int(daysRemaining)) day(s) left. Tap to reorder."
        content.sound = .default
        content.categoryIdentifier = Constants.Notification.lowStockCategory
        content.userInfo = [Constants.Notification.itemIDKey: item.id.uuidString]

        // Fire once, tomorrow at 9 AM, so we don't spam immediately.
        var trigger: UNNotificationTrigger?
        if let fireDate = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 9, minute: 0),
            matchingPolicy: .nextTime
        ) {
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }

        let request = UNNotificationRequest(
            identifier: notificationID(for: item.id),
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.info("Scheduled low-stock notification for \(item.name)")
        } catch {
            logger.error("Failed to schedule notification: \(error.localizedDescription)")
        }
    }

    func cancelAlert(for itemID: UUID) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID(for: itemID)])
        center.removeDeliveredNotifications(withIdentifiers: [notificationID(for: itemID)])
    }

    // MARK: - Deep-link handling

    /// The item ID from a notification tap, published so the app can route to it.
    @Published var pendingItemID: UUID?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let idString = response.notification.request.content.userInfo[Constants.Notification.itemIDKey] as? String,
           let id = UUID(uuidString: idString) {
            Task { @MainActor in pendingItemID = id }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Helpers

    private func notificationID(for itemID: UUID) -> String {
        "reup365.lowstock.\(itemID.uuidString)"
    }

    private func registerCategories() {
        let reorderAction = UNNotificationAction(
            identifier: "REORDER_ACTION",
            title: "Reorder",
            options: .foreground
        )
        let category = UNNotificationCategory(
            identifier: Constants.Notification.lowStockCategory,
            actions: [reorderAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
