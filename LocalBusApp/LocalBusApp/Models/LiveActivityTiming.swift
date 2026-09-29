import Foundation

/// Live Activity의 단계와 시각 계산. 화면(위젯 타깃)과 서비스(앱 타깃)가 같은 규칙을 쓴다.
///
/// 앱이 백그라운드에 있으면 단계 전환을 직접 보낼 수 없으므로, 화면이 다시 그려질 때
/// 시각만으로 단계를 다시 계산할 수 있게 규칙을 한곳에 둔다.
enum LiveActivityTiming {
    /// 출발 이만큼 전부터 잠금 화면에 표시
    static let startLead: TimeInterval = 20 * 60
    /// 출발 이만큼 전부터 "곧 출발"
    static let departingSoonLead: TimeInterval = 5 * 60

    enum Stage: Equatable {
        case waiting
        case departingSoon
        case inTransit
        case finished
    }

    static func stage(now: Date, departure: Date, arrival: Date) -> Stage {
        if now >= arrival { return .finished }
        if now >= departure { return .inTransit }
        if departure.timeIntervalSince(now) <= departingSoonLead { return .departingSoon }
        return .waiting
    }

    /// 다음 단계로 넘어가는 시각 (끝났으면 nil)
    static func nextTransition(after now: Date, departure: Date, arrival: Date) -> Date? {
        switch stage(now: now, departure: departure, arrival: arrival) {
        case .waiting: return departure.addingTimeInterval(-departingSoonLead)
        case .departingSoon: return departure
        case .inTransit: return arrival
        case .finished: return nil
        }
    }

    /// 표시 내용이 낡는 시각. 출발 전에는 출발 시각, 출발 뒤에는 도착 예상 시각.
    /// 이 시각에 시스템이 화면을 다시 그리므로, 앱이 꺼져 있어도 멈춘 카운트다운 대신 도착 예상이 보인다.
    static func staleDate(now: Date, departure: Date, arrival: Date) -> Date? {
        switch stage(now: now, departure: departure, arrival: arrival) {
        case .waiting, .departingSoon: return departure
        case .inTransit: return arrival
        case .finished: return nil
        }
    }

    /// 지금 표시를 시작해도 되는지 (출발 20분 전 ~ 출발 시각)
    static func shouldStart(now: Date, departure: Date) -> Bool {
        let remaining = departure.timeIntervalSince(now)
        return remaining > 0 && remaining <= startLead
    }

    /// "HH:mm"을 지금 기준 가장 가까운 다가올 출발 시각으로 바꾼다.
    /// 자정을 넘긴 버스(23:50에 보는 00:10)는 내일 날짜가 된다. 이미 지난 낮 버스는 오늘 날짜 그대로 둔다.
    static func departureDate(for time: String, now: Date, calendar: Calendar = koreaCalendar) -> Date? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2,
              let today = calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: calendar.startOfDay(for: now)) else { return nil }
        // 12시간 넘게 지난 시각은 어제 버스가 아니라 자정 넘어 올 버스로 본다
        if now.timeIntervalSince(today) > 12 * 60 * 60 {
            return calendar.date(byAdding: .day, value: 1, to: today)
        }
        return today
    }

    static var koreaCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }
}
