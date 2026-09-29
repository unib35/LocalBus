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
        content.title = NotificationCopy.busTitle(busTime: busTime, leadMinutes: minutesBefore)
        content.body = direction
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: busNotificationIdentifier(busTime: busTime, minutesBefore: minutesBefore),
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - BusAlert 기반 예약 (방향 포함, 평일 반복 지원)

    private let alertPrefix = "alert_"

    /// 알림 하나를 (다시) 예약한다. 반복 알림은 공휴일을 뺀 다음 평일들에 하나씩 건다.
    /// - Parameters:
    ///   - platformNumber: 탑승홈 ("20번 홈"). 있으면 본문에 정류장 이름 대신 쓴다.
    ///   - boardingStopName: 타는 정류장 이름
    func schedule(
        _ alert: BusAlert,
        holidays: [String],
        platformNumber: String? = nil,
        boardingStopName: String? = nil,
        now: Date = Date()
    ) {
        cancel(alertID: alert.id)
        guard alert.isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = NotificationCopy.busTitle(busTime: alert.busTime, leadMinutes: alert.leadMinutes)
        content.body = NotificationCopy.busBody(
            direction: alert.direction,
            platformNumber: platformNumber,
            boardingStopName: boardingStopName
        )
        content.sound = .default

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let dates = BusAlertScheduler.fireDates(for: alert, from: now, holidays: holidays)
        for (index, date) in dates.enumerated() {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.requestIdentifier(alertID: alert.id, index: index),
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    /// 알림 하나의 예약을 모두 지운다.
    /// 예약 목록을 조회한 뒤 지우면 그 사이에 새로 건 예약까지 지워지므로, 가능한 식별자를 바로 지운다.
    func cancel(alertID: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: Self.requestIdentifiers(alertID: alertID)
        )
    }

    /// 알림 하나가 가질 수 있는 예약 식별자 전부 (반복 알림은 다음 평일 10일치)
    static func requestIdentifiers(alertID: String) -> [String] {
        (0..<BusAlertScheduler.maxFireDates).map { requestIdentifier(alertID: alertID, index: $0) }
    }

    static func requestIdentifier(alertID: String, index: Int) -> String {
        "alert_\(alertID)_\(index)"
    }

    /// 아직 예약이 남아 있는 알림 id 집합. 예전 방식(bus_ 접두사) 예약은 정리한다.
    func pendingAlertIDs() async -> Set<String> {
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        let legacy = requests.map(\.identifier).filter { $0.hasPrefix(busNotificationPrefix) }
        if !legacy.isEmpty { center.removePendingNotificationRequests(withIdentifiers: legacy) }

        return Set(requests.compactMap { request -> String? in
            let identifier = request.identifier
            guard identifier.hasPrefix(alertPrefix),
                  let underscore = identifier.lastIndex(of: "_") else { return nil }
            return String(identifier[identifier.index(identifier.startIndex, offsetBy: alertPrefix.count)..<underscore])
        })
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

    /// 막차 30분 전 매일 반복 알림 예약. 알림 모아보기가 같은 내용을 기록할 수 있게 정보를 저장해 둔다.
    func scheduleLastBusNotification(_ info: LastBusAlertInfo) {
        // 자정을 넘는 막차(00:10)는 전날 23:40에 울린다
        let parts = info.alertTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }

        var dateComponents = DateComponents()
        dateComponents.hour = parts[0]
        dateComponents.minute = parts[1]

        let content = UNMutableNotificationContent()
        content.title = NotificationCopy.lastBusTitle
        content.body = NotificationCopy.lastBusBody(direction: info.direction, busTime: info.busTime, nightFare: info.nightFare)
        content.userInfo = [
            LastBusAlertInfo.userInfoDirectionKey: info.direction.rawValue,
            LastBusAlertInfo.userInfoBusTimeKey: info.busTime
        ]
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: lastBusNotificationIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
        info.save()
    }

    /// 막차 알림이 예약돼 있는지
    func hasPendingLastBusNotification() async -> Bool {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.contains { $0.identifier == lastBusNotificationIdentifier }
    }

    /// 막차 알림 취소
    func cancelLastBusNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [lastBusNotificationIdentifier]
        )
        LastBusAlertInfo.clear()
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
