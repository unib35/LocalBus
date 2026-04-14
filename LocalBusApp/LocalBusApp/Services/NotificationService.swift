import Foundation
import UserNotifications

/// 버스 알림 서비스
final class NotificationService {
    static let shared = NotificationService()
    private let busNotificationPrefix = "bus_"
    private let lastBusNotificationIdentifier = "last_bus_daily_notification"

    private init() {}

    /// 현재 알림 권한 상태 반환
    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

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
            identifier: busNotificationIdentifier(busTime: busTime, minutesBefore: minutesBefore),
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// 특정 버스 알림 취소
    func cancelNotification(busTime: String, minutesBefore: Int) {
        let identifier = busNotificationIdentifier(busTime: busTime, minutesBefore: minutesBefore)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// 모든 버스 알림 취소
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// 막차 30분 전 매일 반복 알림 예약
    func scheduleLastBusNotification(lastBusTime: String, direction: String) {
        let components = lastBusTime.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else { return }

        var notifyMinute = minute - 30
        var notifyHour = hour
        if notifyMinute < 0 {
            notifyHour -= 1
            notifyMinute += 60
        }

        var dateComponents = DateComponents()
        dateComponents.hour = notifyHour
        dateComponents.minute = notifyMinute

        let content = UNMutableNotificationContent()
        content.title = "막차 알림"
        content.body = "\(direction) 막차(\(lastBusTime))가 30분 후 출발합니다"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: lastBusNotificationIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// 막차 알림 취소
    func cancelLastBusNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [lastBusNotificationIdentifier]
        )
    }

    /// 예약된 알림이 있는지 확인
    func hasScheduledNotification(busTime: String, minutesBefore: Int) async -> Bool {
        let identifier = busNotificationIdentifier(busTime: busTime, minutesBefore: minutesBefore)
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.contains { $0.identifier == identifier }
    }

    /// 예약된 개별 버스 알림 키 목록 반환
    func scheduledBusNotificationKeys() async -> Set<String> {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return Set(
            requests.compactMap { request in
                let identifier = request.identifier
                guard identifier.hasPrefix(busNotificationPrefix) else { return nil }
                return String(identifier.dropFirst(busNotificationPrefix.count))
            }
        )
    }

    private func busNotificationIdentifier(busTime: String, minutesBefore: Int) -> String {
        "\(busNotificationPrefix)\(busTime)_\(minutesBefore)"
    }
}
