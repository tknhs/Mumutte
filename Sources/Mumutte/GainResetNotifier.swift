import Foundation
@preconcurrency import UserNotifications

@MainActor
final class GainResetNotifier: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func notifyGainReset(deviceName: String) {
        Task { @MainActor in
            let settings = await center.notificationSettings()
            let authorized: Bool

            switch settings.authorizationStatus {
            case .authorized, .provisional:
                authorized = true
            case .notDetermined:
                authorized = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            default:
                authorized = false
            }

            guard authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = "入力ゲインを下げました"
            content.body = "\(deviceName) の入力ゲインを0%にしました。"
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "gain-reset-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
