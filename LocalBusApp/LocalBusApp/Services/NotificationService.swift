import Foundation
import UserNotifications

/// 버스 알림 서비스
final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    /// 알림 권한 요청
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// 버스 출발 알림 예약
    /// - Parameters:
    ///   - busTime: 버스 출발 시간 (HH:mm 형식)
    ///   - minutesBefore: 몇 분 전 알림
    ///   - direction: 방향 이름
    func scheduleBusNotification(busTime: String, minutesBefore: Int, direction: String) {
        let components = busTime.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else { return }

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute - minutesBefore

        // 분이 음수가 되면 시간 조정
        if dateComponents.minute! < 0 {
            dateComponents.hour! -= 1
            dateComponents.minute! += 60
        }

        let content = UNMutableNotificationContent()
        content.title = "버스 출발 알림"
        content.body = "\(direction) \(busTime) 버스가 \(minutesBefore)분 후 출발합니다"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "bus_\(busTime)_\(minutesBefore)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// 특정 버스 알림 취소
    func cancelNotification(busTime: String, minutesBefore: Int) {
        let identifier = "bus_\(busTime)_\(minutesBefore)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// 모든 버스 알림 취소
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// 예약된 알림이 있는지 확인
    func hasScheduledNotification(busTime: String, minutesBefore: Int) async -> Bool {
        let identifier = "bus_\(busTime)_\(minutesBefore)"
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.contains { $0.identifier == identifier }
    }
}
