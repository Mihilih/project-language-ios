import Foundation
import UIKit
import UserNotifications
import FirebaseMessaging

/**
 * Friend-activity notifications (requests, suggestions, accepts) — notifications/AppNotifications.kt
 * and messaging/ProjectLanguageMessagingService.kt on Android.
 *
 * Push delivery on iOS goes through APNs, which needs a paid Apple Developer account and the
 * Push Notifications capability (see README). Everything here is ready for that; without it
 * the permission prompt still works but no pushes arrive.
 */
final class AppNotifications: NSObject, UNUserNotificationCenterDelegate, MessagingDelegate {
    static let shared = AppNotifications()

    /** Call once at launch. */
    func install() {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
    }

    /** Asks for permission, then registers with APNs so FCM can get a token. */
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    /** Whether notifications can be shown (Android's canPost). */
    func canPost() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    /** Re-registers with APNs at launch if the user already allowed notifications. */
    func registerIfAuthorized() {
        Task {
            if await canPost() {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            }
        }
    }

    // MARK: MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        FcmTokenRegistrar.registerToken(fcmToken)
    }

    // MARK: UNUserNotificationCenterDelegate

    /**
     * A notification arrived while the app is open. Android posts it itself so it isn't lost;
     * on iOS we ask the system to show it the same way.
     */
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    /** Tapped: remember where it should go; the main screen opens the right Friends section. */
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            NotificationRouter.shared.handle(userInfo: userInfo)
            completionHandler()
        }
    }
}

/** Remembers that we've already asked for the notification permission (we only ask once). */
enum NotificationPrefs {
    private static let keyAsked = "notifications.permission_asked_v1"

    static func hasAsked() -> Bool { UserDefaults.standard.bool(forKey: keyAsked) }

    static func markAsked() { UserDefaults.standard.set(true, forKey: keyAsked) }
}
