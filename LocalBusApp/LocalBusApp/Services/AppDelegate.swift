import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        application.registerForRemoteNotifications()

        // 공지사항 토픽 기본 구독 (설정에서 해제 가능)
        let isSubscribed = UserDefaults.standard.object(forKey: "noticeAlertEnabled") as? Bool ?? true
        if isSubscribed {
            Messaging.messaging().subscribe(toTopic: "notices")
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("FCM Token: \(token)")
        UserDefaults.standard.set(token, forKey: "fcmToken")
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// 포그라운드에서 알림 수신 시 배너 표시 + 기록
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        record(notification, isRead: false)
        completionHandler([.banner, .sound, .badge])
    }

    /// 알림 탭 처리: 기록에 남기고 읽음 처리
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        record(response.notification, isRead: true)
        completionHandler()
    }

    /// iOS는 받은 알림 기록을 앱에 남겨주지 않으므로 앱이 직접 저장한다 (알림 모아보기).
    private func record(_ notification: UNNotification, isRead: Bool) {
        let content = notification.request.content
        guard var item = AppNotification.from(
            identifier: notification.request.identifier,
            title: content.title,
            body: content.body,
            userInfo: content.userInfo,
            receivedAt: notification.date
        ) else { return }
        item.isRead = isRead
        Task { @MainActor in
            NotificationHistoryStore.shared.record(item)
        }
    }
}
