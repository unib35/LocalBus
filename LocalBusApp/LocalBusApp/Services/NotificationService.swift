import Foundation
import UserNotifications

protocol BusNotificationScheduling {
    func requestAuthorization() async -> Bool
    func scheduleBusNotification(departure: TimetableTimeline.Departure, minutesBefore: Int, direction: RouteDirection) async throws
    func cancelNotification(identifier: String)
    func scheduledBusNotificationKeys() async -> Set<String>
}

/// 버스 알림 서비스
final class NotificationService: BusNotificationScheduling {
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

    static func busNotificationIdentifier(departure: Date, direction: RouteDirection, minutesBefore: Int) -> String {
        "bus_v2_\(direction.rawValue)_\(Int(departure.timeIntervalSince1970))_\(minutesBefore)"
    }

    static func reminderComponents(departure: Date, minutesBefore: Int, now: Date = Date()) throws -> DateComponents {
        guard minutesBefore > 0 else { throw ScheduleError.invalidTime }
        let reminder = departure.addingTimeInterval(-Double(minutesBefore) * 60)
        guard reminder > now else { throw ScheduleError.tooLate }
        var components = TimetableTimeline.calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder)
        components.calendar = TimetableTimeline.calendar
        components.timeZone = TimetableTimeline.calendar.timeZone
        return components
    }

    func scheduleBusNotification(departure: TimetableTimeline.Departure, minutesBefore: Int, direction: RouteDirection) async throws {
        let components = try Self.reminderComponents(departure: departure.date, minutesBefore: minutesBefore)
        let content = UNMutableNotificationContent()
        content.title = "버스 출발 알림"
        content.body = "\(direction.displayName) \(departure.time) 버스가 \(minutesBefore)분 후 출발합니다"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: Self.busNotificationIdentifier(departure: departure.date, direction: direction, minutesBefore: minutesBefore),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// 모든 버스 알림 취소
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    enum ScheduleError: LocalizedError {
        case invalidTime, tooLate
        var errorDescription: String? {
            switch self {
            case .invalidTime: return "시간표를 불러온 뒤 다시 시도해주세요."
            case .tooLate: return "출발 5분 전 알림 시각이 지났습니다. 다음 버스를 선택해주세요."
            }
        }
    }

    /// 시각을 하루 안으로 정규화한다. 00:10의 30분 전은 23:40이다.
    static func lastBusReminderComponents(for time: String) throws -> DateComponents {
        let parts = time.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute) else {
            throw ScheduleError.invalidTime
        }
        let minutes = (hour * 60 + minute - 30 + 1440) % 1440
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        components.hour = minutes / 60
        components.minute = minutes % 60
        return components
    }

    func scheduleLastBusNotification(lastBusTime: String, direction: String) async throws {
        let components = try Self.lastBusReminderComponents(for: lastBusTime)
        let content = UNMutableNotificationContent()
        content.title = "막차 알림"
        content.body = "\(direction) 막차(\(lastBusTime))가 30분 후 출발합니다"
        content.sound = .default
        content.userInfo = ["direction": direction, "departure": lastBusTime]
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try await UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: lastBusNotificationIdentifier, content: content, trigger: trigger
        ))
    }

    func lastBusReminderSummary() async -> String? {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        guard let request = requests.first(where: { $0.identifier == lastBusNotificationIdentifier }),
              let trigger = request.trigger as? UNCalendarNotificationTrigger,
              let hour = trigger.dateComponents.hour,
              let minute = trigger.dateComponents.minute,
              (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        let direction = request.content.userInfo["direction"] as? String ?? "기존 노선"
        return "\(direction) · 매일 " + String(format: "%02d:%02d", hour, minute) + " 알림"
    }

    /// 막차 알림 취소
    func cancelLastBusNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [lastBusNotificationIdentifier]
        )
    }

    /// 날짜와 방향을 알 수 없는 구버전 예약은 잘못 울리지 않도록 제거합니다.
    func scheduledBusNotificationKeys() async -> Set<String> {
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        let legacy = requests.filter { $0.identifier.hasPrefix(busNotificationPrefix) && !$0.identifier.hasPrefix("bus_v2_") }
        center.removePendingNotificationRequests(withIdentifiers: legacy.map(\.identifier))
        return Set(requests.filter { $0.identifier.hasPrefix("bus_v2_") }.map(\.identifier))
    }
}
