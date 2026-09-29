import Foundation

// MARK: - 받은 알림 기록 (디자인 캔버스 AlertsHub)
//
// iOS는 받은 알림 기록을 앱에 남겨주지 않으므로 앱이 직접 저장한다.
// 버스 알림은 울릴 시각이 지나면 기록으로 옮기고, 공지·시간표 업데이트는 앱이 알게 된 순간 기록한다.

enum AppNotificationKind: String, Codable, CaseIterable {
    case bus
    case lastBus
    case notice
    case timetable

    var label: String {
        switch self {
        case .bus: return "버스 출발"
        case .lastBus: return "막차"
        case .notice: return "공지사항"
        case .timetable: return "시간표 업데이트"
        }
    }

    /// 외곽선 아이콘. 막차도 버스 알림의 한 종류라 같은 버스 아이콘을 쓴다.
    var systemImage: String {
        switch self {
        case .bus, .lastBus: return "bus"
        case .notice: return "megaphone"
        case .timetable: return "calendar"
        }
    }
}

// MARK: - 알림 문구
//
// 시스템 알림과 앱 안 기록(알림 모아보기)이 같은 문구를 쓰도록 한곳에서 만든다.

enum NotificationCopy {
    /// "07:50 버스가 5분 후 출발해요"
    static func busTitle(busTime: String, leadMinutes: Int) -> String {
        "\(busTime) 버스가 \(leadMinutes)분 후 출발해요"
    }

    /// "장유 → 사상 · 갑을장유병원정류소 승차" / "사상 → 장유 · 20번 홈 승차"
    static func busBody(direction: RouteDirection, platformNumber: String?, boardingStopName: String?) -> String {
        let boarding = [platformNumber, boardingStopName]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        guard let boarding else { return direction.displayName }
        return "\(direction.displayName) · \(boarding) 승차"
    }

    static let lastBusTitle = "막차가 \(LastBusAlertInfo.leadMinutes)분 후 출발해요"

    /// "장유 → 사상 23:30 · 심야 요금 3,000원"
    static func lastBusBody(direction: RouteDirection, busTime: String, nightFare: Int?) -> String {
        let head = "\(direction.displayName) \(busTime)"
        guard let nightFare else { return head }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        let fare = formatter.string(from: NSNumber(value: nightFare)) ?? "\(nightFare)"
        return "\(head) · 심야 요금 \(fare)원"
    }
}

// MARK: - 막차 알림 정보
//
// 막차 알림은 매일 반복되는 시스템 알림 하나라, 앱을 열지 않은 날의 기록을 만들려면
// 어느 방향·몇 시 막차로 예약했는지 따로 기억해야 한다.

struct LastBusAlertInfo: Codable, Equatable {
    static let key = "lastBusAlertInfo"
    static let leadMinutes = 30
    static let userInfoDirectionKey = "direction"
    static let userInfoBusTimeKey = "bus_time"

    let direction: RouteDirection
    let busTime: String
    /// 막차가 심야 요금일 때만 값이 있다
    let nightFare: Int?
    let scheduledAt: Date

    /// 실제로 울리는 시각 (막차 - 30분). 자정을 넘는 막차는 전날 밤 시각이 된다.
    var alertTime: String {
        DateService.timeByAdding(minutes: -Self.leadMinutes, to: busTime) ?? busTime
    }

    /// 예약한 뒤 이미 울린 시각들. 오늘과 어제만 본다 (최신순).
    func firedDates(now: Date) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let parts = alertTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return [] }

        let today = calendar.startOfDay(for: now)
        return [0, -1].compactMap { offset -> Date? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day),
                  fire <= now, fire > scheduledAt else { return nil }
            return fire
        }
    }

    func historyItem(firedAt: Date) -> AppNotification {
        AppNotification(
            id: Self.historyID(for: firedAt),
            kind: .lastBus,
            title: NotificationCopy.lastBusTitle,
            body: NotificationCopy.lastBusBody(direction: direction, busTime: busTime, nightFare: nightFare),
            receivedAt: firedAt,
            target: .bus(direction: direction, time: busTime)
        )
    }

    /// 하루에 한 번 울리므로 날짜가 id가 된다. 시스템 알림 경로와 같은 id라 두 번 기록되지 않는다.
    static func historyID(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyyMMdd"
        return "lastbus_\(formatter.string(from: date))"
    }

    static func load(from defaults: UserDefaults = .standard) -> LastBusAlertInfo? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(LastBusAlertInfo.self, from: data)
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }

    static func clear(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

/// 알림을 눌렀을 때 갈 곳
enum AppNotificationTarget: Codable, Equatable {
    case bus(direction: RouteDirection, time: String)
    case notice(id: String)
    case timetable
}

struct AppNotification: Codable, Identifiable, Equatable {
    let id: String
    let kind: AppNotificationKind
    let title: String
    let body: String
    let receivedAt: Date
    var isRead: Bool
    let target: AppNotificationTarget?

    init(id: String, kind: AppNotificationKind, title: String, body: String, receivedAt: Date, isRead: Bool = false, target: AppNotificationTarget? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.receivedAt = receivedAt
        self.isRead = isRead
        self.target = target
    }
}

/// 알림 기록 보관소. UserDefaults에 JSON으로 저장하고 30일이 지난 항목은 지운다.
@MainActor
final class NotificationHistoryStore: ObservableObject {
    static let shared = NotificationHistoryStore()
    static let key = "notificationHistory"
    static let retentionDays = 30

    @Published private(set) var items: [AppNotification] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, now: Date = Date()) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([AppNotification].self, from: data) {
            items = Self.pruned(decoded, now: now)
        }
    }

    var unreadCount: Int { items.filter { !$0.isRead }.count }

    /// 같은 id가 이미 있으면 무시한다 (같은 알림을 두 번 기록하지 않기 위해).
    @discardableResult
    func record(_ notification: AppNotification, now: Date = Date()) -> Bool {
        guard !items.contains(where: { $0.id == notification.id }) else { return false }
        items.append(notification)
        items = Self.pruned(items, now: now)
        save()
        return true
    }

    func markRead(id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }), !items[index].isRead else { return }
        items[index].isRead = true
        save()
    }

    func markAllRead() {
        guard items.contains(where: { !$0.isRead }) else { return }
        for index in items.indices { items[index].isRead = true }
        save()
    }

    func removeAll() {
        items = []
        save()
    }

    /// 최신순, 30일 이내
    static func pruned(_ items: [AppNotification], now: Date) -> [AppNotification] {
        let cutoff = now.addingTimeInterval(-Double(retentionDays) * 24 * 60 * 60)
        return items
            .filter { $0.receivedAt >= cutoff }
            .sorted { $0.receivedAt > $1.receivedAt }
    }

    /// "오늘" / "어제" / "9월 25일"
    static func dayLabel(for date: Date, now: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        if calendar.isDate(date, inSameDayAs: now) { return "오늘" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "어제" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "M월 d일"
        return formatter.string(from: date)
    }

    static func timeLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

// MARK: - 시스템 알림 → 기록 변환

extension AppNotification {
    /// UNNotification의 identifier·userInfo로 기록 항목을 만든다. 알 수 없는 알림은 nil.
    static func from(identifier: String, title: String, body: String, userInfo: [AnyHashable: Any], receivedAt: Date) -> AppNotification? {
        if identifier.hasPrefix("alert_") {
            // alert_<direction>_<HH:mm>_<index> — direction rawValue 자체에 밑줄이 있으므로 뒤에서부터 자른다.
            var rest = String(identifier.dropFirst("alert_".count))
            if let indexUnderscore = rest.lastIndex(of: "_") { rest = String(rest[..<indexUnderscore]) }
            var target: AppNotificationTarget?
            if let timeUnderscore = rest.lastIndex(of: "_") {
                let time = String(rest[rest.index(after: timeUnderscore)...])
                let directionRaw = String(rest[..<timeUnderscore])
                if let direction = RouteDirection(rawValue: directionRaw) {
                    target = .bus(direction: direction, time: time)
                }
            }
            // 앱을 켰을 때 기록하는 "오늘 울린 알림"(bus_<alertID>_<yyyyMMdd>)과 같은 id를 써서 중복을 막는다.
            let dayFormatter = DateFormatter()
            dayFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")
            dayFormatter.dateFormat = "yyyyMMdd"
            return AppNotification(id: "bus_\(rest)_\(dayFormatter.string(from: receivedAt))", kind: .bus, title: title, body: body, receivedAt: receivedAt, target: target)
        }
        if identifier == "last_bus_daily_notification" {
            var target: AppNotificationTarget?
            if let directionRaw = userInfo[LastBusAlertInfo.userInfoDirectionKey] as? String,
               let direction = RouteDirection(rawValue: directionRaw),
               let time = userInfo[LastBusAlertInfo.userInfoBusTimeKey] as? String {
                target = .bus(direction: direction, time: time)
            }
            return AppNotification(id: LastBusAlertInfo.historyID(for: receivedAt), kind: .lastBus, title: title, body: body, receivedAt: receivedAt, target: target)
        }
        if userInfo["gcm.message_id"] != nil || userInfo["notice_id"] != nil {
            let noticeID = userInfo["notice_id"] as? String
            let messageID = (userInfo["gcm.message_id"] as? String) ?? noticeID ?? UUID().uuidString
            return AppNotification(
                id: "push_\(messageID)",
                kind: .notice,
                title: title,
                body: body,
                receivedAt: receivedAt,
                target: noticeID.map { .notice(id: $0) }
            )
        }
        return nil
    }
}
