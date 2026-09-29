import Foundation

/// 사용자가 켜 둔 버스 알림 하나. 방향 + 출발 시각이 키가 된다.
struct BusAlert: Codable, Equatable, Identifiable {
    static let leadOptions = [5, 10, 15, 30]

    let busTime: String
    let direction: RouteDirection
    var leadMinutes: Int
    var repeatsWeekdays: Bool
    var isEnabled: Bool

    init(busTime: String, direction: RouteDirection, leadMinutes: Int = 5, repeatsWeekdays: Bool = false, isEnabled: Bool = true) {
        self.busTime = busTime
        self.direction = direction
        self.leadMinutes = leadMinutes
        self.repeatsWeekdays = repeatsWeekdays
        self.isEnabled = isEnabled
    }

    var id: String { Self.makeID(busTime: busTime, direction: direction) }

    static func makeID(busTime: String, direction: RouteDirection) -> String {
        "\(direction.rawValue)_\(busTime)"
    }

    /// 실제로 울리는 시각 (출발 - lead)
    var alertTime: String {
        DateService.timeByAdding(minutes: -leadMinutes, to: busTime) ?? busTime
    }

    /// "5분 전 · 07:45에 알림" / "5분 전 · 꺼짐"
    var detailText: String {
        isEnabled ? "\(leadMinutes)분 전 · \(alertTime)에 알림" : "\(leadMinutes)분 전 · 꺼짐"
    }

    /// "평일마다 반복" / "오늘 한 번"
    var repeatText: String {
        repeatsWeekdays ? "평일마다 반복" : "오늘 한 번"
    }
}

/// 알림이 실제로 울릴 날짜·시각을 계산한다.
/// 반복 알림은 다음 평일들(공휴일 제외)에 하나씩 예약해서 공휴일에는 울리지 않게 한다.
enum BusAlertScheduler {
    /// 알림 하나에 거는 예약의 최대 개수
    static let maxFireDates = 10

    static func fireDates(for alert: BusAlert, from now: Date, holidays: [String], count: Int = maxFireDates) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!

        let parts = alert.alertTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return [] }

        func fireDate(on day: Date) -> Date? {
            calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
        }

        let today = calendar.startOfDay(for: now)

        if !alert.repeatsWeekdays {
            guard let todayFire = fireDate(on: today) else { return [] }
            if todayFire > now { return [todayFire] }
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
                  let tomorrowFire = fireDate(on: tomorrow) else { return [] }
            return [tomorrowFire]
        }

        var result: [Date] = []
        var offset = 0
        while result.count < count && offset < 60 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { break }
            offset += 1
            guard DateService.shouldUseWeekdaySchedule(day, holidays: holidays),
                  let fire = fireDate(on: day), fire > now else { continue }
            result.append(fire)
        }
        return result
    }
}

/// UserDefaults에 알림 목록을 보관한다.
struct BusAlertStore {
    static let key = "busAlerts"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [BusAlert] {
        guard let data = defaults.data(forKey: Self.key),
              let alerts = try? JSONDecoder().decode([BusAlert].self, from: data) else { return [] }
        return alerts
    }

    func save(_ alerts: [BusAlert]) {
        guard let data = try? JSONEncoder().encode(alerts) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
