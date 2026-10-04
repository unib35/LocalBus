import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    /// 공지사항 푸시 토픽. Firebase 콘솔에서 이 이름으로 발송한다.
    static let noticeTopic = "notices"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        guard !PreviewRuntime.isRunning else { return true }
        FirebaseApp.configure()

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        application.registerForRemoteNotifications()

        // 토픽 구독은 여기서 하지 않는다. APNs 토큰이 아직 도착하지 않아
        // FCM이 "No APNS token specified before fetching FCM Token"으로 거부한다.
        // FCM 토큰이 발급된 뒤(didReceiveRegistrationToken)에 구독한다.

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
        UserDefaults.standard.set(token, forKey: "fcmToken")


        // 이 콜백은 APNs 토큰이 확보된 뒤에 불리므로 여기서 구독해야 성공한다.
        // 설정에서 끈 사용자는 제외한다.
        let isSubscribed = UserDefaults.standard.object(forKey: "noticeAlertEnabled") as? Bool ?? false
        guard isSubscribed else { return }

        Messaging.messaging().subscribe(toTopic: Self.noticeTopic) { error in
            #if DEBUG
            if let error {
                print("'\(Self.noticeTopic)' 토픽 구독 실패: \(error.localizedDescription)")
            } else {
                print("'\(Self.noticeTopic)' 토픽 구독 완료")
            }
            #endif
        }
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
