//
//  LocalBusWidget.swift
//  LocalBusWidget
//

import WidgetKit
import SwiftUI

// MARK: - 위젯 보기 방식 (디자인 캔버스 WidgetSmallSet · WidgetMediumSet)

/// 소형 위젯 보기 (캔버스 A–G). 위젯 편집에서 고른다.
enum SmallWidgetStyle: String {
    case remaining    // A 남은 시간
    case arrival      // B 출발 → 도착
    case list         // C 다음 3대
    case lastBus      // D 막차
    case bothWays     // E 양방향
    case target       // F 도착 목표
    case timeline     // G 세로 타임라인
}

/// 중형 위젯 보기 (캔버스 A–F).
enum MediumWidgetStyle: String {
    case remaining    // A 남은 시간 + 이후 3대
    case arrival      // B 출발 → 도착 타임라인
    case bothWays     // C 양방향
    case hourGrid     // D 시간대 시간표
    case summary      // E 다음 버스 + 하루 요약
    case target       // F 도착 목표
}

/// 대형 위젯 보기 (캔버스 A·B).
enum LargeWidgetStyle: String {
    case list         // A 다음 버스 + 이어지는 버스 표
    case grid         // B 오늘 시간표 그리드
}

/// 잠금 화면 원형 위젯 보기.
enum LockCircularStyle: String {
    case remaining    // 남은 시간 고리
    case departure    // 출발 시각
}

/// 위젯 편집에서 고른 값 묶음. 크기마다 자기 것만 쓴다.
struct WidgetOptions {
    var small: SmallWidgetStyle = .remaining
    var medium: MediumWidgetStyle = .remaining
    var large: LargeWidgetStyle = .list
    var circular: LockCircularStyle = .remaining
    /// 도착 목표 보기(F)의 목표 도착 시각 "HH:mm"
    var targetTime: String = "08:30"

    static let `default` = WidgetOptions()

    /// 양방향 보기면 반대 방향 요약도 필요하다.
    var needsCounterpart: Bool { small == .bothWays || medium == .bothWays }
}

/// "사상에 08:30까지" 계산 결과 (앱의 ArrivalPlanner와 같은 규칙, 위젯 타깃용 재구현)
struct WidgetTargetPlan {
    let target: String
    /// 목표 시각까지 도착하는 마지막 버스 (없으면 nil)
    let best: String?
    let bestArrival: String?
    let slackMinutes: Int?
    /// best 한 대 앞
    let earlier: String?
    let earlierSlack: Int?
    /// best를 놓쳤을 때 (best가 없으면 첫차)
    let later: String?
    let lateMinutes: Int?
}

// MARK: - Shared Data Helper

struct WidgetDataHelper {
    static let defaultRouteKey = "jangyu_to_sasang"
    static let defaultDirection = "장유 → 사상"
    static let koreaTimeZone = TimeZone(identifier: "Asia/Seoul")!
    static let koreaDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = koreaTimeZone
        return formatter
    }()

    /// 출발까지 이 시간 안이면 앱이 공유한 교통 소요시간을 쓴다 (앱과 같은 기준).
    static let trafficWindowMinutes = 60

    static var koreaCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = koreaTimeZone
        return calendar
    }

    static func createEntry(
        for date: Date,
        routeKey: String = defaultRouteKey,
        direction: String = defaultDirection,
        options: WidgetOptions = .default
    ) -> BusEntry {
        // v1.0 무료 출시: IAP 미적용 상태이므로 위젯을 모두에게 개방한다.
        // IAP 도입 시 아래 한 줄을 `EntitlementStore.shared.isPro`로 되돌리면 잠금이 복원된다.
        let isPro = true
        let summary = summary(for: date, routeKey: routeKey, direction: direction)

        var counterpart: WidgetCounterpart?
        if options.needsCounterpart, let opposite = oppositeRoute(of: routeKey) {
            let other = self.summary(for: date, routeKey: opposite.key, direction: opposite.direction)
            counterpart = WidgetCounterpart(
                direction: opposite.direction,
                nextBusTime: other.nextBusTime,
                remainingMinutes: other.remainingMinutes,
                arrivalTime: other.arrivalTime,
                usesTraffic: other.usesTraffic,
                isServiceEnded: other.isServiceEnded,
                firstBusTime: other.firstBusTime
            )
        }

        return BusEntry(
            date: date,
            routeKey: routeKey,
            nextBusTime: summary.nextBusTime,
            remainingMinutes: summary.remainingMinutes,
            direction: direction,
            isServiceEnded: summary.isServiceEnded,
            firstBusTime: summary.firstBusTime,
            lastBusTime: summary.lastBusTime,
            upcomingBuses: summary.upcomingBuses,
            isLastBus: summary.isLastBus,
            isNightBus: summary.isNightBus,
            isVia: summary.isVia,
            arrivalTime: summary.arrivalTime,
            usesTraffic: summary.usesTraffic,
            trafficUpdatedAt: summary.trafficUpdatedAt,
            durationMinutes: summary.durationMinutes,
            baseDurationMinutes: summary.baseDurationMinutes,
            scheduleLabel: summary.scheduleLabel,
            tomorrowLabel: summary.tomorrowLabel,
            todayTimes: summary.todayTimes,
            viaTimes: summary.viaTimes,
            nightFare: summary.nightFare,
            nightFareStartTime: summary.nightFareStartTime,
            tomorrowFirstBusTime: summary.tomorrowFirstBusTime,
            serviceNowMinutes: summary.serviceNowMinutes,
            options: options,
            counterpart: counterpart,
            isPro: isPro
        )
    }

    struct RouteSummary {
        let nextBusTime: String?
        let remainingMinutes: Int
        let isServiceEnded: Bool
        let firstBusTime: String
        let lastBusTime: String
        let upcomingBuses: [WidgetBus]
        let isLastBus: Bool
        let isNightBus: Bool
        let isVia: Bool
        let arrivalTime: String
        let usesTraffic: Bool
        let trafficUpdatedAt: Date?
        let durationMinutes: Int
        let baseDurationMinutes: Int
        let scheduleLabel: String
        let tomorrowLabel: String
        let todayTimes: [String]
        let viaTimes: Set<String>
        let nightFare: Int?
        let nightFareStartTime: String?
        let tomorrowFirstBusTime: String
        /// 운행일 기준 현재 분 (자정 넘긴 막차 계산용)
        let serviceNowMinutes: Int
    }

    static func summary(for date: Date, routeKey: String, direction: String) -> RouteSummary {
        let json = loadTimetableData()
        let route = json?.routes?[routeKey]
        // 자정 직후에 전날 막차(00:10 등)가 남아 있으면 운행일은 아직 어제다
        let yesterday = koreaCalendar.date(byAdding: .day, value: -1, to: date) ?? date
        let schedule = ServiceDaySchedule.resolve(
            todayTimes: loadTimetable(for: date, routeKey: routeKey, json: json),
            yesterdayTimes: loadTimetable(for: yesterday, routeKey: routeKey, json: json),
            clockMinutes: clockMinutes(of: date)
        )
        let serviceDate = schedule.isOvernightTail ? yesterday : date
        let times = schedule.times
        let viaTimes = Set(route?.viaTimes ?? [])
        let baseDuration = route?.durationMinutes ?? 26
        let traffic = EntitlementStore.loadTraffic(routeKey: routeKey)
        let freshTraffic: (minutes: Int, updatedAt: Date)? = traffic.flatMap { $0.isFresh ? ($0.durationMinutes, $0.updatedAt) : nil }
        let firstBusTime = times.first ?? "06:00"
        let lastBusTime = times.last ?? "23:30"
        let scheduleLabel = usesWeekday(serviceDate, holidays: json?.holidays ?? []) ? "평일" : "주말"
        let tomorrow = koreaCalendar.date(byAdding: .day, value: 1, to: serviceDate) ?? date
        let tomorrowLabel = usesWeekday(tomorrow, holidays: json?.holidays ?? []) ? "내일 평일" : "내일 주말"

        // 내일 첫차는 내일 시간표 기준
        let tomorrowTimes = loadTimetable(for: tomorrow, routeKey: routeKey, json: json)
        let tomorrowFirst = tomorrowTimes.first ?? firstBusTime

        func estimate(_ time: String, minutes: Int) -> (arrival: String, usesTraffic: Bool) {
            if let freshTraffic, minutes >= 0, minutes <= trafficWindowMinutes {
                return (timeByAdding(minutes: freshTraffic.minutes, to: time), true)
            }
            return (timeByAdding(minutes: baseDuration, to: time), false)
        }

        guard let nextIndex = schedule.nextIndex else {
            return RouteSummary(
                nextBusTime: nil, remainingMinutes: 0, isServiceEnded: true,
                firstBusTime: tomorrowFirst, lastBusTime: lastBusTime, upcomingBuses: [],
                isLastBus: false, isNightBus: false, isVia: false,
                arrivalTime: timeByAdding(minutes: baseDuration, to: tomorrowFirst),
                usesTraffic: false, trafficUpdatedAt: traffic?.updatedAt,
                durationMinutes: baseDuration, baseDurationMinutes: baseDuration,
                scheduleLabel: scheduleLabel, tomorrowLabel: tomorrowLabel,
                todayTimes: times, viaTimes: viaTimes,
                nightFare: route?.nightFare, nightFareStartTime: route?.nightFareStartTime,
                tomorrowFirstBusTime: tomorrowFirst,
                serviceNowMinutes: schedule.nowMinutes
            )
        }

        let nextBus = times[nextIndex]
        let remaining = schedule.minutesUntil(index: nextIndex)
        let nextEstimate = estimate(nextBus, minutes: remaining)

        var upcoming: [WidgetBus] = []
        for i in (nextIndex + 1)..<min(nextIndex + 5, times.count) {
            let mins = schedule.minutesUntil(index: i)
            let e = estimate(times[i], minutes: mins)
            upcoming.append(WidgetBus(time: times[i], minutes: mins, isVia: viaTimes.contains(times[i]), arrival: e.arrival, usesTraffic: e.usesTraffic))
        }

        return RouteSummary(
            nextBusTime: nextBus,
            remainingMinutes: remaining,
            isServiceEnded: false,
            firstBusTime: firstBusTime,
            lastBusTime: lastBusTime,
            upcomingBuses: upcoming,
            isLastBus: nextIndex == times.count - 1,
            isNightBus: isNightBusTime(nextBus),
            isVia: viaTimes.contains(nextBus),
            arrivalTime: nextEstimate.arrival,
            usesTraffic: nextEstimate.usesTraffic,
            trafficUpdatedAt: nextEstimate.usesTraffic ? freshTraffic?.updatedAt : traffic?.updatedAt,
            durationMinutes: nextEstimate.usesTraffic ? (freshTraffic?.minutes ?? baseDuration) : baseDuration,
            baseDurationMinutes: baseDuration,
            scheduleLabel: scheduleLabel,
            tomorrowLabel: tomorrowLabel,
            todayTimes: times,
            viaTimes: viaTimes,
            nightFare: route?.nightFare,
            nightFareStartTime: route?.nightFareStartTime,
            tomorrowFirstBusTime: tomorrowFirst,
            serviceNowMinutes: schedule.nowMinutes
        )
    }

    /// 목표 도착 시각까지 탈 버스 고르기. 자정 넘긴 막차를 아침 버스로 착각하지 않게 운행일 기준으로 센다.
    static func targetPlan(times: [String], durationMinutes: Int, target: String) -> WidgetTargetPlan {
        let times = times.filter { ServiceDaySchedule.clockMinutes($0) != nil }
        let bestIndex = ServiceDaySchedule.lastIndex(arrivingBy: target, times: times, durationMinutes: durationMinutes)
        let best = bestIndex.map { times[$0] }
        var earlier: String?
        var later: String?
        if let index = bestIndex {
            earlier = index > 0 ? times[index - 1] : nil
            later = index + 1 < times.count ? times[index + 1] : nil
        } else {
            later = times.first
        }
        func minutesBetween(_ from: String, _ to: String) -> Int? {
            guard let a = totalMinutes(from), let b = totalMinutes(to) else { return nil }
            var diff = b - a
            if diff < 0 { diff += 24 * 60 }
            return diff
        }
        let bestArrival = best.map { timeByAdding(minutes: durationMinutes, to: $0) }
        return WidgetTargetPlan(
            target: target,
            best: best,
            bestArrival: bestArrival,
            slackMinutes: bestArrival.flatMap { minutesBetween($0, target) },
            earlier: earlier,
            earlierSlack: earlier.flatMap { minutesBetween(timeByAdding(minutes: durationMinutes, to: $0), target) },
            later: later,
            lateMinutes: later.flatMap { minutesBetween(target, timeByAdding(minutes: durationMinutes, to: $0)) }
        )
    }

    static func totalMinutes(_ time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }

    /// "1시간 12분" 표기
    static func spanText(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)분" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)시간" : "\(hours)시간 \(rest)분"
    }

    static func oppositeRoute(of routeKey: String) -> (key: String, direction: String)? {
        switch routeKey {
        case "jangyu_to_sasang": return ("sasang_to_jangyu", "사상 → 장유")
        case "sasang_to_jangyu": return ("jangyu_to_sasang", "장유 → 사상")
        case "yulha_to_sasang": return ("sasang_to_yulha", "사상 → 율하")
        case "sasang_to_yulha": return ("yulha_to_sasang", "율하 → 사상")
        default: return nil
        }
    }

    /// 시간표 데이터 로드.
    /// 1순위: App Group 공유 캐시(메인 앱이 원격에서 받아 저장) → 앱 업데이트 없이 갱신 반영.
    /// 2순위: 번들 동봉 JSON(빌드 시점 데이터) → 캐시가 아직 없을 때의 폴백.
    static func loadTimetableData() -> WidgetTimetableData? {
        let decoder = JSONDecoder()

        if let cached = EntitlementStore.sharedDefaults.data(forKey: EntitlementStore.timetableCacheKey),
           let json = try? decoder.decode(WidgetTimetableData.self, from: cached) {
            return json
        }

        if let url = Bundle.main.url(forResource: "timetable", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let json = try? decoder.decode(WidgetTimetableData.self, from: data) {
            return json
        }

        return nil
    }

    static func loadTimetable(for date: Date, routeKey: String, json: WidgetTimetableData? = nil) -> [String] {
        guard let json = json ?? loadTimetableData() else {
            return defaultTimes
        }

        let isWeekday = usesWeekday(date, holidays: json.holidays)

        if let route = json.routes?[routeKey] {
            let times = isWeekday ? route.timetable.weekday : route.timetable.weekend
            return times.isEmpty ? (isWeekday ? route.timetable.weekend : route.timetable.weekday) : times
        }
        if let timetable = json.timetable {
            return isWeekday ? timetable.weekday : timetable.weekend
        }
        return defaultTimes
    }

    static func usesWeekday(_ date: Date, holidays: [String]) -> Bool {
        isWeekdayDate(date) && !isHoliday(date, holidays: holidays)
    }

    static var defaultTimes: [String] {
        ["06:00", "06:20", "06:40", "07:00", "07:20", "07:40",
         "08:00", "08:20", "08:40", "09:00", "09:20", "09:40"]
    }

    static func isWeekdayDate(_ date: Date) -> Bool {
        let weekday = koreaCalendar.component(.weekday, from: date)
        return weekday >= 2 && weekday <= 6
    }

    static func isHoliday(_ date: Date, holidays: [String]) -> Bool {
        let dateString = koreaDateFormatter.string(from: date)
        return holidays.contains(dateString)
    }

    /// 지금 시각을 자정부터 센 분 (KST)
    static func clockMinutes(of date: Date) -> Int {
        let calendar = koreaCalendar
        return calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    static func timeByAdding(minutes: Int, to timeString: String) -> String {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return "--:--" }
        var total = (hour * 60 + minute + minutes) % (24 * 60)
        if total < 0 { total += 24 * 60 }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    static func isNightBusTime(_ timeString: String) -> Bool {
        let parts = timeString.split(separator: ":")
        guard let hour = Int(parts.first ?? "") else { return false }
        return hour >= 21 || hour < 4
    }
}

// MARK: - Static Provider (iOS 16 fallback)

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> BusEntry {
        BusEntry.placeholder()
    }

    func getSnapshot(in context: Context, completion: @escaping (BusEntry) -> ()) {
        completion(WidgetDataHelper.createEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BusEntry>) -> ()) {
        let currentDate = Date()
        var entries: [BusEntry] = []

        for minuteOffset in 0..<30 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            entries.append(WidgetDataHelper.createEntry(for: entryDate))
        }

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
        completion(Timeline(entries: entries, policy: .after(nextUpdate)))
    }
}

// MARK: - Models

struct WidgetBus: Hashable {
    let time: String
    let minutes: Int
    let isVia: Bool
    /// "약" 도착 예상
    let arrival: String
    let usesTraffic: Bool
}

/// 중형 C(양방향)의 반대 방향 요약
struct WidgetCounterpart {
    let direction: String
    let nextBusTime: String?
    let remainingMinutes: Int
    let arrivalTime: String
    let usesTraffic: Bool
    let isServiceEnded: Bool
    let firstBusTime: String
}

struct BusEntry: TimelineEntry {
    let date: Date
    let routeKey: String
    let nextBusTime: String?
    let remainingMinutes: Int
    let direction: String
    let isServiceEnded: Bool
    /// 운행 종료 뒤에는 내일 첫차
    let firstBusTime: String
    let lastBusTime: String
    let upcomingBuses: [WidgetBus]
    let isLastBus: Bool
    let isNightBus: Bool
    let isVia: Bool
    /// 다음 버스의 "약" 도착 예상
    let arrivalTime: String
    let usesTraffic: Bool
    let trafficUpdatedAt: Date?
    let durationMinutes: Int
    let baseDurationMinutes: Int
    let scheduleLabel: String
    let tomorrowLabel: String
    /// 오늘 시간표 전체 (그리드 보기)
    let todayTimes: [String]
    let viaTimes: Set<String>
    let nightFare: Int?
    let nightFareStartTime: String?
    /// 내일 시간표의 첫차 (운행 중에도 하루 요약에 쓴다)
    let tomorrowFirstBusTime: String
    /// 운행일 기준 현재 분. 자정을 넘긴 막차(00:10)도 오늘 운행으로 센다
    let serviceNowMinutes: Int
    let options: WidgetOptions
    let counterpart: WidgetCounterpart?
    let isPro: Bool

    var remainingDisplay: String {
        remainingMinutes >= 60 ? String(remainingMinutes / 60) : String(remainingMinutes)
    }

    var remainingUnit: String {
        remainingMinutes >= 60 ? "시간" : "분"
    }

    /// "사상" — 방향 문자열의 도착지
    var destinationName: String {
        direction.components(separatedBy: "→").last?.trimmingCharacters(in: .whitespaces) ?? "사상"
    }

    /// "3,000원" 같은 표기 (없으면 nil)
    var nightFareText: String? {
        guard let nightFare else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "\(formatter.string(from: NSNumber(value: nightFare)) ?? "\(nightFare)")원"
    }

    private var schedule: ServiceDaySchedule {
        ServiceDaySchedule(times: todayTimes, nowMinutes: serviceNowMinutes)
    }

    /// 막차까지 남은 분 (지났으면 0)
    var minutesUntilLastBus: Int {
        schedule.minutesUntilLast ?? 0
    }

    /// 이미 떠난 버스인지 (시간표 그리드에서 어둡게)
    func isPast(_ time: String) -> Bool {
        schedule.isPast(time)
    }

    /// 양방향 보기는 반대 방향에 버스가 남아 있으면 운행 종료 화면으로 바꾸지 않는다.
    func showsBothWays(_ isBothWaysStyle: Bool) -> Bool {
        guard isBothWaysStyle, let counterpart else { return false }
        return !counterpart.isServiceEnded
    }

    /// 두 방향 중 이쪽이 먼저 출발하는지 (먼저 출발하는 쪽만 강조색)
    var departsBeforeCounterpart: Bool {
        guard let counterpart, !counterpart.isServiceEnded else { return true }
        if isServiceEnded { return false }
        return remainingMinutes <= counterpart.remainingMinutes
    }

    var targetPlan: WidgetTargetPlan {
        WidgetDataHelper.targetPlan(times: todayTimes, durationMinutes: durationMinutes, target: options.targetTime)
    }

    static func placeholder(options: WidgetOptions = .default) -> BusEntry {
        BusEntry(
            date: Date(), routeKey: WidgetDataHelper.defaultRouteKey, nextBusTime: "18:30", remainingMinutes: 12,
            direction: WidgetDataHelper.defaultDirection, isServiceEnded: false, firstBusTime: "06:20", lastBusTime: "23:30",
            upcomingBuses: [
                WidgetBus(time: "18:50", minutes: 32, isVia: false, arrival: "19:24", usesTraffic: true),
                WidgetBus(time: "19:10", minutes: 52, isVia: true, arrival: "19:46", usesTraffic: true),
                WidgetBus(time: "19:30", minutes: 72, isVia: false, arrival: "19:56", usesTraffic: false),
                WidgetBus(time: "19:50", minutes: 92, isVia: false, arrival: "20:16", usesTraffic: false),
            ],
            isLastBus: false, isNightBus: false, isVia: false, arrivalTime: "19:04", usesTraffic: true,
            trafficUpdatedAt: Date().addingTimeInterval(-15 * 60), durationMinutes: 34, baseDurationMinutes: 26,
            scheduleLabel: "평일", tomorrowLabel: "내일 평일",
            todayTimes: ["06:20", "06:40", "07:00", "07:20", "07:35", "07:50", "08:05", "08:20", "18:10", "18:30", "18:50", "19:10", "19:30", "19:50", "20:10", "20:30", "20:45", "21:20", "21:40", "22:10", "22:40", "23:10", "23:30"],
            viaTimes: ["19:10"], nightFare: 3000, nightFareStartTime: "22:10", tomorrowFirstBusTime: "06:20",
            serviceNowMinutes: 18 * 60 + 18,
            options: options,
            counterpart: WidgetCounterpart(direction: "사상 → 장유", nextBusTime: "18:40", remainingMinutes: 22, arrivalTime: "19:19", usesTraffic: true, isServiceEnded: false, firstBusTime: "06:20"),
            isPro: true
        )
    }
}

private func formatUpcomingMinutes(_ minutes: Int) -> String {
    if minutes >= 60 {
        let h = minutes / 60
        let m = minutes % 60
        return m > 0 ? "\(h)시간 \(m)분" : "\(h)시간"
    }
    return "\(minutes)분"
}

private func timeLabel(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeZone = WidgetDataHelper.koreaTimeZone
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}

struct WidgetTimetableData: Codable {
    let holidays: [String]
    let timetable: WidgetTimetable?
    let routes: [String: WidgetRouteData]?
}

struct WidgetTimetable: Codable {
    let weekday: [String]
    let weekend: [String]
}

struct WidgetRouteData: Codable {
    let timetable: WidgetTimetable
    let durationMinutes: Int?
    let viaTimes: [String]?
    let nightFare: Int?
    let nightFareStartTime: String?

    enum CodingKeys: String, CodingKey {
        case timetable
        case durationMinutes = "duration_minutes"
        case viaTimes = "via_times"
        case nightFare = "night_fare"
        case nightFareStartTime = "night_fare_start_time"
    }
}

// MARK: - Design Tokens
//
// 위젯 타깃은 앱의 AppTheme를 참조할 수 없어 같은 값을 여기에 둔다 (디자인 캔버스 개선안).
// 평면 서피스 하나, 강조색은 남은 시간 숫자에만.

private enum WidgetTheme {
    private static func dynamic(dark: UIColor, light: UIColor) -> Color {
        Color(UIColor { trait in trait.userInterfaceStyle == .dark ? dark : light })
    }

    /// 위젯 컨테이너 — 앱 히어로 카드와 같은 평면 서피스 (다크 #141414 / 라이트 #FFFFFF)
    static let surface = dynamic(dark: UIColor(white: 0.08, alpha: 1), light: .white)
    /// 서피스 안에서 한 단계 올라온 영역 (#1C1C1C / #EBEBEB)
    static let surfaceSecondary = dynamic(dark: UIColor(white: 0.11, alpha: 1), light: UIColor(white: 0.92, alpha: 1))
    /// 칩·보조 버튼 배경 (#262626 / #EBEBEB)
    static let chip = dynamic(dark: UIColor(white: 0.149, alpha: 1), light: UIColor(white: 0.92, alpha: 1))
    /// 행 구분선 (#222222 / #DCDCDC)
    static let divider = dynamic(dark: UIColor(white: 0.133, alpha: 1), light: UIColor(white: 0.863, alpha: 1))
    /// 타임라인 선 (#333333 / #D9D9D9)
    static let track = dynamic(dark: UIColor(white: 0.2, alpha: 1), light: UIColor(white: 0.85, alpha: 1))
    /// 지난 시각 셀 (#0D0D0D / #F5F5F5)
    static let pastCell = dynamic(dark: UIColor(white: 0.05, alpha: 1), light: UIColor(white: 0.96, alpha: 1))
    /// 제목·시각·값 (#FFFFFF / #0D0D0D)
    static let primaryText = dynamic(dark: .white, light: UIColor(white: 0.05, alpha: 1))
    /// 보조 텍스트 (#A3A3A3 / #525252)
    static let secondaryText = dynamic(dark: UIColor(white: 0.64, alpha: 1), light: UIColor(white: 0.322, alpha: 1))
    /// 3차 텍스트 (#8A8A8A / #616161)
    static let tertiaryText = dynamic(dark: UIColor(white: 0.541, alpha: 1), light: UIColor(white: 0.38, alpha: 1))
    /// 살짝 낮춘 본문 (#D4D4D4 / #333333)
    static let mutedText = dynamic(dark: UIColor(white: 0.83, alpha: 1), light: UIColor(white: 0.2, alpha: 1))
    /// 단일 강조색 — 남은 시간 숫자 (#4ADE80 / #166534)
    static let accent = dynamic(dark: UIColor(red: 74/255, green: 222/255, blue: 128/255, alpha: 1), light: UIColor(red: 22/255, green: 101/255, blue: 52/255, alpha: 1))
    /// 강조색 배경 위 글자 (검정 / 흰색)
    static let accentForeground = dynamic(dark: .black, light: .white)
    /// 선택됨 칩 배경 (흰 / 검정)과 글자
    static let selectedBackground = dynamic(dark: .white, light: UIColor(white: 0.05, alpha: 1))
    static let selectedText = dynamic(dark: .black, light: .white)
    /// 심야 요금 (#FB923C / #C2410C)
    static let nightFare = dynamic(dark: UIColor(red: 251/255, green: 146/255, blue: 60/255, alpha: 1), light: UIColor(red: 194/255, green: 65/255, blue: 12/255, alpha: 1))
    /// 문제 상황 (#FBBF24 / #92400E)
    static let warning = dynamic(dark: UIColor(red: 251/255, green: 191/255, blue: 36/255, alpha: 1), light: UIColor(red: 146/255, green: 64/255, blue: 14/255, alpha: 1))
}

private enum WidgetDeepLink {
    static let scheme = "jangyusasang"
    static let host = "route"
    static let directionQueryItem = "direction"

    static func url(for routeKey: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: directionQueryItem, value: routeKey)]
        return components.url
    }

    /// 잠긴 위젯을 누르면 앱의 Pro 결제 화면으로
    static var paywallURL: URL? {
        URL(string: "\(scheme)://paywall")
    }
}

private extension View {
    func widgetCanvas(alignment: Alignment = .center) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}

struct WidgetContainerBackground: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            Color.clear
        default:
            WidgetTheme.surface.widgetCanvas()
        }
    }
}

// MARK: - Widget Entry View

struct LocalBusWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if entry.isPro {
                currentFamilyView
            } else {
                LockedWidgetView()
            }
        }
        .widgetURL(entry.isPro ? WidgetDeepLink.url(for: entry.routeKey) : WidgetDeepLink.paywallURL)
    }

    @ViewBuilder
    private var currentFamilyView: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        case .accessoryInline:
            AccessoryInlineView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Locked (Non-Pro) Widget View

struct LockedWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("Pro 업그레이드 필요", systemImage: "lock.fill")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                    Text("Pro")
                        .font(.system(size: 9, weight: .semibold))
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                    Text("장유사상버스")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                Text("위젯은 Pro에서 쓸 수 있어요")
                    .font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            homeScreenLocked
        }
    }

    /// 디자인 캔버스 WidgetLocked: 값 자리를 비운 채 "Pro에서 쓸 수 있어요"와 결제 화면 링크 한 줄
    private var homeScreenLocked: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("장유사상버스")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WidgetTheme.secondaryText)
                Spacer(minLength: 0)
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetTheme.secondaryText)
            }

            Spacer(minLength: 0)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("--")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .tracking(-1.5)
                Text("분")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundStyle(WidgetTheme.tertiaryText.opacity(0.5))

            Text("위젯은 Pro에서 쓸 수 있어요")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetTheme.primaryText)
                .padding(.top, 6)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text("눌러서 Pro 보기")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WidgetTheme.accent)
        }
        .padding(16)
        .widgetCanvas(alignment: .topLeading)
    }
}

// MARK: - 공통 조각

/// 남은 시간 숫자 (강조색) + 단위
private struct RemainingHero: View {
    let entry: BusEntry
    var numberSize: CGFloat = 56
    var unitText: String? = nil

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(entry.remainingDisplay)
                .font(.system(size: numberSize, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .tracking(-1.5)
                .foregroundStyle(WidgetTheme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(unitText ?? "\(entry.remainingUnit) 후")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(WidgetTheme.primaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.remainingDisplay)\(entry.remainingUnit) 후 출발")
    }
}

/// "18:30 출발" + 막차/심야 라벨
private struct DepartureLine: View {
    let entry: BusEntry
    let nextTime: String

    var body: some View {
        HStack(spacing: 6) {
            Text("\(nextTime) 출발")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(WidgetTheme.primaryText)
            if entry.isLastBus || entry.isNightBus {
                Text(entry.isLastBus ? "막차" : "심야")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WidgetTheme.nightFare)
            }
        }
        .lineLimit(1)
    }
}

/// 근거 점: 채운 점(교통 반영) · 빈 고리(시간표 기준)
private struct BasisDot: View {
    let usesTraffic: Bool
    var size: CGFloat = 7

    var body: some View {
        if usesTraffic {
            Circle().fill(WidgetTheme.accent).frame(width: size, height: size)
        } else {
            Circle().stroke(WidgetTheme.secondaryText, lineWidth: 1.5).frame(width: size, height: size)
        }
    }
}

private struct BasisLine: View {
    let usesTraffic: Bool
    let updatedAt: Date?

    var body: some View {
        HStack(spacing: 6) {
            BasisDot(usesTraffic: usesTraffic)
            if usesTraffic, let updatedAt {
                Text("교통 반영 · \(timeLabel(updatedAt)) 기준")
            } else {
                Text(usesTraffic ? "교통 반영" : "시간표 기준")
            }
        }
        .font(.system(size: 11, weight: .medium))
        .monospacedDigit()
        .foregroundStyle(WidgetTheme.secondaryText)
        .lineLimit(1)
    }
}

/// 출발 ●──34분──○ 도착 약 (중형 B · 대형)
private struct TimelineStrip: View {
    let entry: BusEntry
    let nextTime: String
    var timeSize: CGFloat = 38

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("출발")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetTheme.secondaryText)
                Text(nextTime)
                    .font(.system(size: timeSize, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .tracking(-1)
                    .foregroundStyle(WidgetTheme.primaryText)
            }

            HStack(spacing: 6) {
                Circle().fill(WidgetTheme.primaryText).frame(width: 6, height: 6)
                Rectangle().fill(WidgetTheme.track).frame(height: 2)
                Text("\(entry.durationMinutes)분")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.secondaryText)
                Rectangle().fill(WidgetTheme.track).frame(height: 2)
                Circle().stroke(WidgetTheme.primaryText, lineWidth: 1.5).frame(width: 6, height: 6)
            }
            .padding(.top, 14)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(entry.destinationName) 도착 약")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetTheme.secondaryText)
                Text(entry.arrivalTime)
                    .font(.system(size: timeSize, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .tracking(-1)
                    .foregroundStyle(WidgetTheme.primaryText)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(nextTime) 출발, \(entry.destinationName) 약 \(entry.arrivalTime) 도착 예상")
    }
}

/// 운행 종료 — 내일 첫차를 먼저 (강조색 없음)
private struct ServiceEndedBlock: View {
    let entry: BusEntry
    var timeSize: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("내일 첫차")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetTheme.secondaryText)
            Text(entry.firstBusTime)
                .font(.system(size: timeSize, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .tracking(-1)
                .foregroundStyle(WidgetTheme.primaryText)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DirectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(WidgetTheme.secondaryText)
            .lineLimit(1)
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: BusEntry

    var body: some View {
        Group {
            if entry.isServiceEnded {
                ended
            } else {
                switch entry.options.small {
                case .remaining: styleA
                case .arrival: styleB
                case .list: styleC
                case .lastBus: styleD
                case .bothWays: styleE
                case .target: styleF
                case .timeline: styleG
                }
            }
        }
        .padding(16)
        .widgetCanvas(alignment: .topLeading)
    }

    private var ended: some View {
        VStack(alignment: .leading, spacing: 0) {
            DirectionLabel(text: entry.direction)
            Spacer(minLength: 4)
            ServiceEndedBlock(entry: entry)
            Spacer(minLength: 4)
            Text("오늘 운행 종료 · \(entry.tomorrowLabel)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.secondaryText)
                .lineLimit(1)
        }
    }

    /// A · 남은 시간 — 지금 나가야 하는지 한눈에
    private var styleA: some View {
        VStack(alignment: .leading, spacing: 0) {
            DirectionLabel(text: entry.direction)
            Spacer(minLength: 4)
            if let nextTime = entry.nextBusTime {
                RemainingHero(entry: entry, unitText: entry.remainingUnit)
                DepartureLine(entry: entry, nextTime: nextTime)
                    .padding(.top, 6)
            }
            Spacer(minLength: 4)
            Text("약 \(entry.arrivalTime) \(entry.destinationName) 도착")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(WidgetTheme.secondaryText)
                .lineLimit(1)
        }
    }

    /// B · 출발 → 도착 — 도착 예상이 필요한 사람용
    private var styleB: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                DirectionLabel(text: entry.direction)
                Spacer(minLength: 4)
                Text("\(formatUpcomingMinutes(entry.remainingMinutes)) 후")
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.accent)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(spacing: 8) {
                HStack(alignment: .lastTextBaseline) {
                    Text("출발").font(.system(size: 12, weight: .semibold)).foregroundStyle(WidgetTheme.secondaryText)
                    Spacer()
                    Text(entry.nextBusTime ?? "--:--")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .tracking(-0.5)
                        .foregroundStyle(WidgetTheme.primaryText)
                }
                Rectangle().fill(WidgetTheme.chip).frame(height: 1)
                HStack(alignment: .lastTextBaseline) {
                    Text("도착 약").font(.system(size: 12, weight: .semibold)).foregroundStyle(WidgetTheme.secondaryText)
                    Spacer()
                    Text(entry.arrivalTime)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .tracking(-0.5)
                        .foregroundStyle(WidgetTheme.primaryText)
                }
            }
            Spacer(minLength: 4)
            BasisLine(usesTraffic: entry.usesTraffic, updatedAt: nil)
        }
    }

    /// C · 다음 3대 — 한 대 놓쳐도 바로 다음이 보임
    private var styleC: some View {
        VStack(alignment: .leading, spacing: 0) {
            DirectionLabel(text: entry.direction)
            Spacer(minLength: 4)
            VStack(spacing: 0) {
                HStack(alignment: .lastTextBaseline) {
                    HStack(spacing: 5) {
                        Text(entry.nextBusTime ?? "--:--")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .tracking(-0.5)
                            .foregroundStyle(WidgetTheme.primaryText)
                        if entry.isVia { ViaChip() }
                    }
                    Spacer()
                    Text(formatUpcomingMinutes(entry.remainingMinutes))
                        .font(.system(size: 15, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.accent)
                }
                .frame(height: 36)

                ForEach(entry.upcomingBuses.prefix(2), id: \.self) { bus in
                    Rectangle().fill(WidgetTheme.chip).frame(height: 1)
                    HStack {
                        HStack(spacing: 5) {
                            Text(bus.time)
                                .font(.system(size: 15, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(WidgetTheme.primaryText)
                            if bus.isVia { ViaChip() }
                        }
                        Spacer()
                        Text(formatUpcomingMinutes(bus.minutes))
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(WidgetTheme.secondaryText)
                    }
                    .frame(height: 32)
                }
            }
        }
        .padding(.bottom, -4)
    }

    /// D · 막차 — 늦게 돌아오는 날 확인용
    private var styleD: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                DirectionLabel(text: entry.direction)
                Spacer(minLength: 4)
                Text("막차")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WidgetTheme.selectedText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(WidgetTheme.selectedBackground))
            }
            Spacer(minLength: 4)
            Text(entry.lastBusTime)
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .tracking(-1)
                .foregroundStyle(WidgetTheme.primaryText)
            Text("\(WidgetDataHelper.spanText(entry.minutesUntilLastBus)) 남음")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(WidgetTheme.primaryText)
                .padding(.top, 6)
            Spacer(minLength: 4)
            if let fare = entry.nightFareText, let start = entry.nightFareStartTime {
                HStack(spacing: 3) {
                    Text("심야").fontWeight(.bold).foregroundStyle(WidgetTheme.nightFare)
                    Text("\(fare) · \(start)부터")
                }
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(WidgetTheme.secondaryText)
                .lineLimit(1)
            } else {
                Text("첫차 \(entry.firstBusTime)")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// E · 양방향 — 작은 칸에서 두 방향 모두. 먼저 출발하는 쪽만 강조색
    private var styleE: some View {
        let counterpart = entry.counterpart
        let thisFirst = counterpart.map { $0.isServiceEnded || entry.remainingMinutes <= $0.remainingMinutes } ?? true
        return VStack(alignment: .leading, spacing: 0) {
            compactDirection(
                direction: entry.direction, time: entry.nextBusTime ?? entry.firstBusTime,
                minutes: entry.remainingMinutes, isEnded: entry.isServiceEnded, highlighted: thisFirst
            )
            Spacer(minLength: 6)
            Rectangle().fill(WidgetTheme.chip).frame(height: 1)
            Spacer(minLength: 6)
            if let counterpart {
                compactDirection(
                    direction: counterpart.direction, time: counterpart.nextBusTime ?? counterpart.firstBusTime,
                    minutes: counterpart.remainingMinutes, isEnded: counterpart.isServiceEnded, highlighted: !thisFirst
                )
            }
        }
        .padding(.vertical, -2)
    }

    private func compactDirection(direction: String, time: String, minutes: Int, isEnded: Bool, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            DirectionLabel(text: direction)
            HStack(alignment: .lastTextBaseline) {
                Text(time)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .tracking(-0.5)
                    .foregroundStyle(WidgetTheme.primaryText)
                Spacer(minLength: 4)
                Text(isEnded ? "내일 첫차" : WidgetDataHelper.spanText(minutes))
                    .font(.system(size: isEnded ? 12 : 15, weight: highlighted ? .bold : .semibold))
                    .monospacedDigit()
                    .foregroundStyle(highlighted && !isEnded ? WidgetTheme.accent : WidgetTheme.secondaryText)
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    /// F · 도착 목표 — 출근 시각을 정해 두는 사람용
    private var styleF: some View {
        let plan = entry.targetPlan
        return VStack(alignment: .leading, spacing: 0) {
            DirectionLabel(text: "\(entry.destinationName)에 \(plan.target)까지")
            Spacer(minLength: 4)
            if let best = plan.best, let arrival = plan.bestArrival {
                Text(best)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .tracking(-1)
                    .foregroundStyle(WidgetTheme.accent)
                Text("이 버스를 타세요")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetTheme.primaryText)
                    .padding(.top, 6)
                Spacer(minLength: 4)
                Text("약 \(arrival) 도착 · \((plan.slackMinutes ?? 0) == 0 ? "딱 맞게" : "\(WidgetDataHelper.spanText(plan.slackMinutes ?? 0)) 여유")")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.secondaryText)
                    .lineLimit(1)
            } else {
                Text(plan.later ?? entry.firstBusTime)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .tracking(-1)
                    .foregroundStyle(WidgetTheme.primaryText)
                Text("그 시각까지 가는 버스가 없어요")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetTheme.primaryText)
                    .padding(.top, 6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Text("첫차 \(plan.later ?? entry.firstBusTime) · \(WidgetDataHelper.spanText(plan.lateMinutes ?? 0)) 늦어요")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// G · 세로 타임라인 — 출발과 도착을 위아래로
    private var styleG: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                DirectionLabel(text: entry.direction)
                Spacer(minLength: 4)
                Text("\(formatUpcomingMinutes(entry.remainingMinutes)) 후")
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.accent)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            HStack(alignment: .center, spacing: 12) {
                VStack(spacing: 0) {
                    Circle().fill(WidgetTheme.primaryText).frame(width: 10, height: 10)
                    Rectangle().fill(WidgetTheme.track).frame(width: 2)
                    Circle().stroke(WidgetTheme.primaryText, lineWidth: 2).frame(width: 10, height: 10)
                }
                .frame(width: 12)
                .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(entry.nextBusTime ?? "--:--")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .tracking(-0.5)
                            .foregroundStyle(WidgetTheme.primaryText)
                        Text("출발")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(WidgetTheme.secondaryText)
                    }
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(entry.arrivalTime)
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .tracking(-0.5)
                            .foregroundStyle(WidgetTheme.primaryText)
                        Text("약 도착")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(WidgetTheme.secondaryText)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Text(entry.usesTraffic ? "예상 소요 \(entry.durationMinutes)분" : "기본 소요 \(entry.durationMinutes)분")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(WidgetTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ViaChip: View {
    var body: some View {
        Text("경유")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(WidgetTheme.mutedText)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(WidgetTheme.chip))
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: BusEntry

    var body: some View {
        Group {
            if entry.isServiceEnded {
                ended
            } else {
                switch entry.options.medium {
                case .remaining: styleA
                case .arrival: styleB
                case .bothWays: styleC
                case .hourGrid: styleD
                case .summary: styleE
                case .target: styleF
                }
            }
        }
        .padding(16)
        .widgetCanvas()
    }

    private var ended: some View {
        VStack(alignment: .leading, spacing: 0) {
            DirectionLabel(text: "\(entry.direction) · \(entry.scheduleLabel)")
            Spacer(minLength: 4)
            ServiceEndedBlock(entry: entry, timeSize: 44)
            Spacer(minLength: 4)
            Text("오늘 운행 종료 · \(entry.tomorrowLabel) · 약 \(entry.arrivalTime) \(entry.destinationName) 도착")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(WidgetTheme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A · 남은 시간 + 이후 3대 (예상 도착 열)
    private var styleA: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                DirectionLabel(text: "\(entry.direction) · \(entry.scheduleLabel)")
                Spacer(minLength: 4)
                RemainingHero(entry: entry)
                Spacer(minLength: 4)
                if let nextTime = entry.nextBusTime {
                    Text("\(nextTime) 출발 · 약 \(entry.arrivalTime) 도착")
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !entry.upcomingBuses.isEmpty {
                VStack(spacing: 0) {
                    HStack {
                        Text("출발")
                        Spacer()
                        Text("예상 도착")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WidgetTheme.secondaryText)
                    .frame(height: 22)

                    ForEach(entry.upcomingBuses.prefix(3), id: \.self) { bus in
                        Rectangle().fill(WidgetTheme.divider).frame(height: 1)
                        HStack {
                            HStack(spacing: 5) {
                                Text(bus.time)
                                    .font(.system(size: 13, weight: .semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(WidgetTheme.primaryText)
                                if bus.isVia {
                                    Circle().fill(WidgetTheme.secondaryText).frame(width: 5, height: 5)
                                }
                            }
                            Spacer()
                            Text("약 \(bus.arrival)")
                                .font(.system(size: 13, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(WidgetTheme.mutedText)
                        }
                        .frame(height: 34)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 148)
            }
        }
    }

    /// B · 출발 → 도착 타임라인 (홈 히어로와 같은 구조)
    private var styleB: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                DirectionLabel(text: "\(entry.direction) · \(entry.scheduleLabel)")
                Spacer(minLength: 4)
                Text("\(formatUpcomingMinutes(entry.remainingMinutes)) 후 출발")
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.accent)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if let nextTime = entry.nextBusTime {
                TimelineStrip(entry: entry, nextTime: nextTime)
            }
            Spacer(minLength: 6)
            HStack {
                BasisLine(usesTraffic: entry.usesTraffic, updatedAt: entry.usesTraffic ? entry.trafficUpdatedAt : nil)
                Spacer(minLength: 4)
                let next = entry.upcomingBuses.prefix(2).map(\.time)
                if !next.isEmpty {
                    Text("다음 " + next.joined(separator: " · "))
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    /// C · 양방향 — 먼저 출발하는 쪽만 강조색
    private var styleC: some View {
        let counterpart = entry.counterpart
        let thisFirst = counterpart.map { $0.isServiceEnded || entry.remainingMinutes <= $0.remainingMinutes } ?? true
        return HStack(alignment: .top, spacing: 14) {
            directionColumn(
                direction: entry.direction, isEnded: entry.isServiceEnded, nextTime: entry.nextBusTime,
                remaining: entry.remainingMinutes, arrival: entry.arrivalTime, firstBus: entry.firstBusTime, highlighted: thisFirst
            )
            Rectangle().fill(WidgetTheme.chip).frame(width: 1)
            if let counterpart {
                directionColumn(
                    direction: counterpart.direction, isEnded: counterpart.isServiceEnded, nextTime: counterpart.nextBusTime,
                    remaining: counterpart.remainingMinutes, arrival: counterpart.arrivalTime, firstBus: counterpart.firstBusTime, highlighted: !thisFirst
                )
            }
        }
    }

    private func directionColumn(direction: String, isEnded: Bool, nextTime: String?, remaining: Int, arrival: String, firstBus: String, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DirectionLabel(text: direction)
            Spacer(minLength: 4)
            if isEnded {
                Text(firstBus)
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .tracking(-1)
                    .foregroundStyle(WidgetTheme.primaryText)
                Spacer(minLength: 4)
                Text("오늘 운행 종료 · 내일 첫차")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WidgetTheme.secondaryText)
            } else {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(remaining >= 60 ? String(remaining / 60) : String(remaining))
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .tracking(-1.5)
                        .foregroundStyle(highlighted ? WidgetTheme.accent : WidgetTheme.primaryText)
                    Text(remaining >= 60 ? "시간" : "분")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(WidgetTheme.primaryText)
                }
                Spacer(minLength: 4)
                Text("\(nextTime ?? "--:--") · 약 \(arrival) 도착")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.primaryText)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// D · 시간대 시간표 — 지금과 다음 시간대의 출발 시각 전체
    private var styleD: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                DirectionLabel(text: "\(entry.direction) · \(entry.scheduleLabel)")
                Spacer(minLength: 4)
                if let next = entry.nextBusTime {
                    Text("\(next) · \(formatUpcomingMinutes(entry.remainingMinutes)) 후")
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.accent)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            HourGrid(entry: entry, maxRows: 2, cellWidth: 46, cellHeight: 34, cornerRadius: 9, fontSize: 15)
            Spacer(minLength: 6)
            Text("막차 \(entry.lastBusTime) · 점은 경유")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(WidgetTheme.secondaryText)
        }
    }

    /// E · 다음 버스 + 하루 요약 — 막차·심야·첫차를 함께
    private var styleE: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                DirectionLabel(text: entry.direction)
                Spacer(minLength: 4)
                RemainingHero(entry: entry)
                Spacer(minLength: 4)
                if let nextTime = entry.nextBusTime {
                    Text("\(nextTime) 출발 · 약 \(entry.arrivalTime) 도착")
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                summaryRow(label: "막차", value: entry.lastBusTime, valueColor: WidgetTheme.primaryText)
                Rectangle().fill(WidgetTheme.divider).frame(height: 1)
                if let start = entry.nightFareStartTime {
                    summaryRow(label: "심야 요금", value: "\(start)부터", valueColor: WidgetTheme.nightFare)
                } else {
                    summaryRow(label: "첫차", value: entry.firstBusTime, valueColor: WidgetTheme.primaryText)
                }
                Rectangle().fill(WidgetTheme.divider).frame(height: 1)
                summaryRow(label: "내일 첫차", value: entry.tomorrowFirstBusTime, valueColor: WidgetTheme.primaryText)
            }
            .frame(width: 132)
        }
    }

    private func summaryRow(label: String, value: String, valueColor: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WidgetTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
        }
        .frame(height: 34)
        .lineLimit(1)
    }

    /// F · 도착 목표 — '도착 시각으로 찾기'를 위젯으로
    private var styleF: some View {
        let plan = entry.targetPlan
        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                DirectionLabel(text: "\(entry.destinationName)에 \(plan.target)까지")
                Spacer(minLength: 4)
                if let best = plan.best, let arrival = plan.bestArrival {
                    Text(best)
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .tracking(-1.5)
                        .foregroundStyle(WidgetTheme.accent)
                    Text("이 버스를 타세요")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WidgetTheme.primaryText)
                        .padding(.top, 4)
                    Spacer(minLength: 4)
                    Text("약 \(arrival) 도착 · \((plan.slackMinutes ?? 0) == 0 ? "딱 맞게" : "\(WidgetDataHelper.spanText(plan.slackMinutes ?? 0)) 여유")")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.secondaryText)
                } else {
                    Text(plan.later ?? entry.firstBusTime)
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .tracking(-1.5)
                        .foregroundStyle(WidgetTheme.primaryText)
                    Text("그 시각까지 가는 버스가 없어요")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WidgetTheme.primaryText)
                        .padding(.top, 4)
                    Spacer(minLength: 4)
                    Text("첫차 \(plan.later ?? entry.firstBusTime) · \(WidgetDataHelper.spanText(plan.lateMinutes ?? 0)) 늦어요")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.secondaryText)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if let earlier = plan.earlier {
                    targetRow(label: "한 대 앞", time: earlier, note: "\(WidgetDataHelper.spanText(plan.earlierSlack ?? 0)) 여유", noteColor: WidgetTheme.secondaryText, noteWeight: .medium)
                    Rectangle().fill(WidgetTheme.divider).frame(height: 1)
                }
                if let later = plan.later, plan.best != nil {
                    targetRow(label: "놓치면", time: later, note: "\(WidgetDataHelper.spanText(plan.lateMinutes ?? 0)) 늦어요", noteColor: WidgetTheme.warning, noteWeight: .semibold)
                }
                Spacer(minLength: 0)
            }
            .frame(width: 148)
        }
    }

    private func targetRow(label: String, time: String, note: String, noteColor: Color, noteWeight: Font.Weight) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WidgetTheme.secondaryText)
                Text(time)
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.primaryText)
            }
            Spacer()
            Text(note)
                .font(.system(size: 12, weight: noteWeight))
                .monospacedDigit()
                .foregroundStyle(noteColor)
        }
        .frame(height: 40)
        .lineLimit(1)
    }
}

/// 시간대별 출발 시각 그리드 (중형 D · 대형 B). 지난 시각은 어둡게, 다음 버스만 강조색, 경유는 점.
private struct HourGrid: View {
    let entry: BusEntry
    let maxRows: Int
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let cornerRadius: CGFloat
    let fontSize: CGFloat
    var maxCellsPerRow: Int = 6

    private var rows: [(hour: String, times: [String])] {
        var order: [String] = []
        var grouped: [String: [String]] = [:]
        for time in entry.todayTimes {
            let hour = String(time.prefix(2))
            if grouped[hour] == nil { order.append(hour) }
            grouped[hour, default: []].append(time)
        }
        // 다음 버스가 있는 시간대부터 보여준다
        let nextHour = entry.nextBusTime.map { String($0.prefix(2)) }
        let start = nextHour.flatMap { order.firstIndex(of: $0) } ?? max(order.count - maxRows, 0)
        return order[start...].prefix(maxRows).map { ($0, Array((grouped[$0] ?? []).prefix(maxCellsPerRow))) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows, id: \.hour) { row in
                HStack(spacing: 6) {
                    Text("\(Int(row.hour) ?? 0)시")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.secondaryText)
                        .frame(width: 38, alignment: .leading)
                    ForEach(row.times, id: \.self) { time in
                        cell(time)
                    }
                    Spacer(minLength: 0)
                }
                .frame(height: cellHeight)
            }
        }
    }

    private func cell(_ time: String) -> some View {
        let isNext = time == entry.nextBusTime
        let isPast = !isNext && entry.isPast(time)
        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isNext ? WidgetTheme.accent : (isPast ? WidgetTheme.pastCell : WidgetTheme.surfaceSecondary))
            Text(String(time.suffix(2)))
                .font(.system(size: fontSize, weight: isNext ? .heavy : .semibold))
                .monospacedDigit()
                .foregroundStyle(isNext ? WidgetTheme.accentForeground : (isPast ? WidgetTheme.tertiaryText : WidgetTheme.primaryText))
                .frame(maxHeight: .infinity)
            if entry.viaTimes.contains(time) {
                Circle()
                    .fill(isNext ? WidgetTheme.accentForeground : WidgetTheme.secondaryText)
                    .frame(width: 4, height: 4)
                    .padding(.bottom, 4)
            }
        }
        .frame(width: cellWidth, height: cellHeight)
        .accessibilityLabel("\(time) 출발\(isNext ? ", 다음 버스" : "")\(entry.viaTimes.contains(time) ? ", 경유" : "")")
    }
}

// MARK: - Large Widget (디자인 캔버스 WidgetLarge)

struct LargeWidgetView: View {
    let entry: BusEntry

    var body: some View {
        switch entry.options.large {
        case .list: listStyle
        case .grid: gridStyle
        }
    }

    /// B · 오늘 시간표 그리드
    private var gridStyle: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                DirectionLabel(text: "\(entry.direction) · \(entry.scheduleLabel) 시간표")
                Spacer(minLength: 4)
                if entry.isServiceEnded {
                    Text("오늘 운행 종료 · 내일 첫차 \(entry.firstBusTime)")
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.primaryText)
                } else if let next = entry.nextBusTime {
                    Text("\(next) · \(formatUpcomingMinutes(entry.remainingMinutes)) 후")
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.accent)
                }
            }
            .lineLimit(1)

            HourGrid(entry: entry, maxRows: 6, cellWidth: 66, cellHeight: 40, cornerRadius: 10, fontSize: 16, maxCellsPerRow: 4)
                .padding(.top, 14)

            Spacer(minLength: 0)

            HStack {
                if let start = entry.nightFareStartTime {
                    HStack(spacing: 0) {
                        Text("막차 \(entry.lastBusTime) · ")
                        Text(start).fontWeight(.bold).foregroundStyle(WidgetTheme.nightFare)
                        Text("부터 심야")
                    }
                } else {
                    Text("첫차 \(entry.firstBusTime) · 막차 \(entry.lastBusTime)")
                }
                Spacer()
                Text("점은 경유")
            }
            .font(.system(size: 11, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(WidgetTheme.secondaryText)
            .lineLimit(1)
        }
        .padding(18)
        .widgetCanvas(alignment: .topLeading)
    }

    /// A · 다음 버스 + 이어지는 버스 표
    private var listStyle: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                DirectionLabel(text: "\(entry.direction) · \(entry.scheduleLabel) 시간표")
                Spacer(minLength: 4)
                if entry.isServiceEnded {
                    Text("오늘 운행 종료")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(WidgetTheme.primaryText)
                } else {
                    Text("\(formatUpcomingMinutes(entry.remainingMinutes)) 후 출발")
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.accent)
                }
            }

            if entry.isServiceEnded {
                HStack(alignment: .bottom) {
                    ServiceEndedBlock(entry: entry, timeSize: 38)
                    Spacer()
                    Text("\(entry.tomorrowLabel) · 약 \(entry.arrivalTime) 도착")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.secondaryText)
                }
                .padding(.top, 14)
            } else if let nextTime = entry.nextBusTime {
                TimelineStrip(entry: entry, nextTime: nextTime)
                    .padding(.top, 14)
            }

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("출발").frame(width: 64, alignment: .leading)
                    Spacer(minLength: 0)
                    Text("예상 도착").frame(width: 84, alignment: .trailing)
                    Text("기준").frame(width: 96, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WidgetTheme.secondaryText)
                .frame(height: 24)

                if entry.upcomingBuses.isEmpty {
                    Rectangle().fill(WidgetTheme.divider).frame(height: 1)
                    HStack {
                        Text(entry.isServiceEnded ? "내일 첫차부터 다시 운행해요" : "오늘 남은 버스가 없어요")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(WidgetTheme.secondaryText)
                        Spacer()
                    }
                    .frame(height: 40)
                } else {
                    ForEach(entry.upcomingBuses.prefix(4), id: \.self) { bus in
                        Rectangle().fill(WidgetTheme.divider).frame(height: 1)
                        HStack(spacing: 0) {
                            Text(bus.time)
                                .font(.system(size: 16, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(WidgetTheme.primaryText)
                                .frame(width: 64, alignment: .leading)
                            if bus.isVia { ViaChip() }
                            Spacer(minLength: 0)
                            Text("약 \(bus.arrival)")
                                .font(.system(size: 14, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(WidgetTheme.primaryText)
                                .frame(width: 84, alignment: .trailing)
                            HStack(spacing: 6) {
                                BasisDot(usesTraffic: bus.usesTraffic)
                                Text(bus.usesTraffic ? "교통 반영" : "시간표 기준")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(bus.usesTraffic ? WidgetTheme.primaryText : WidgetTheme.secondaryText)
                            }
                            .frame(width: 96, alignment: .trailing)
                        }
                        .frame(height: 40)
                    }
                }
            }
            .padding(.top, 16)

            Spacer(minLength: 0)

            HStack {
                Text("첫차 \(entry.isServiceEnded ? entry.firstBusTime : entry.firstBusTime) · 막차 \(entry.lastBusTime)")
                Spacer()
                if entry.usesTraffic, let at = entry.trafficUpdatedAt {
                    Text("교통정보 \(timeLabel(at)) 기준")
                } else {
                    Text("시간표 기준")
                }
            }
            .font(.system(size: 11, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(WidgetTheme.secondaryText)
            .lineLimit(1)
        }
        .padding(18)
        .widgetCanvas(alignment: .topLeading)
    }
}

// MARK: - Accessory (Lock Screen) Widgets — 디자인 캔버스 WidgetLockSet
//
// 시스템이 단색으로 그리므로 강조색 없이 굵기와 크기로만 위계.

struct AccessoryCircularView: View {
    let entry: BusEntry

    var body: some View {
        if entry.options.circular == .departure, !entry.isServiceEnded, let next = entry.nextBusTime {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Text("출발")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(next)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text(entry.destinationName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        } else if entry.isServiceEnded {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Text("내일")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(entry.firstBusTime)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text("첫차")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Gauge(value: Double(min(max(entry.remainingMinutes, 0), 60)), in: 0...60) {
                Image(systemName: "bus.fill")
            } currentValueLabel: {
                VStack(spacing: 0) {
                    Text(entry.remainingDisplay)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text("\(entry.remainingUnit) 후")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .gaugeStyle(.accessoryCircular)
        }
    }
}

struct AccessoryRectangularView: View {
    let entry: BusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.direction)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            if entry.isServiceEnded {
                Text("내일 첫차 \(entry.firstBusTime)")
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
                Text("오늘 운행 종료")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            } else if let nextTime = entry.nextBusTime {
                Text("\(nextTime) 출발 · \(formatUpcomingMinutes(entry.remainingMinutes)) 후")
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
                HStack(spacing: 4) {
                    Text("약 \(entry.arrivalTime) \(entry.destinationName) 도착")
                    if entry.isLastBus || entry.isNightBus {
                        Text(entry.isLastBus ? "· 막차" : "· 심야")
                            .fontWeight(.bold)
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AccessoryInlineView: View {
    let entry: BusEntry

    var body: some View {
        if entry.isServiceEnded {
            Label("\(entry.destinationName)행 내일 첫차 \(entry.firstBusTime)", systemImage: "bus.fill")
        } else if let nextTime = entry.nextBusTime {
            Label("\(entry.destinationName)행 \(nextTime) · \(formatUpcomingMinutes(entry.remainingMinutes)) 후", systemImage: "bus.fill")
        }
    }
}

// MARK: - Widget Configuration

struct LocalBusWidget: Widget {
    let kind: String = "LocalBusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LocalBusWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetContainerBackground()
                }
        }
        .configurationDisplayName("다음 버스 (고정)")
        .description("장유-사상 시외버스 다음 출발 시간을 확인하세요")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    LocalBusWidget()
} timeline: {
    BusEntry.placeholder(options: WidgetOptions(small: .remaining))
    BusEntry.placeholder(options: WidgetOptions(small: .arrival))
    BusEntry.placeholder(options: WidgetOptions(small: .list))
    BusEntry.placeholder(options: WidgetOptions(small: .lastBus))
    BusEntry.placeholder(options: WidgetOptions(small: .bothWays))
    BusEntry.placeholder(options: WidgetOptions(small: .target))
    BusEntry.placeholder(options: WidgetOptions(small: .timeline))
}

#Preview(as: .systemMedium) {
    LocalBusWidget()
} timeline: {
    BusEntry.placeholder(options: WidgetOptions(medium: .remaining))
    BusEntry.placeholder(options: WidgetOptions(medium: .arrival))
    BusEntry.placeholder(options: WidgetOptions(medium: .bothWays))
    BusEntry.placeholder(options: WidgetOptions(medium: .hourGrid))
    BusEntry.placeholder(options: WidgetOptions(medium: .summary))
    BusEntry.placeholder(options: WidgetOptions(medium: .target))
}

#Preview(as: .systemLarge) {
    LocalBusWidget()
} timeline: {
    BusEntry.placeholder(options: WidgetOptions(large: .list))
    BusEntry.placeholder(options: WidgetOptions(large: .grid))
}
