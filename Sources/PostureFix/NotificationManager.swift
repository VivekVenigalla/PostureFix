import UserNotifications

enum NotificationManager {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func sendSlouchAlert() {
        let content = UNMutableNotificationContent()
        content.title = "Posture check"
        content.body = "You've been slouching for a while — sit up straight."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "posture-slouch-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
