//
//  LocalBusWidget.swift
//  LocalBusWidget
//

import WidgetKit
import SwiftUI

// MARK: - 위젯 보기 방식 (디자인 캔버스 WidgetSmallSet · WidgetMediumSet)

/// 위젯 편집에서 고르는 보기. 소형: A 남은 시간 · B 출발 → 도착 · C 다음 3대. 중형: A · B · C 양방향.
enum WidgetStyle: String {
    case remaining
    case arrival
    case list
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
        style: WidgetStyle = .remaining
    ) -> BusEntry {
        // v1.0 무료 출시: IAP 미적용 상태이므로 위젯을 모두에게 개방한다.
        // IAP 도입 시 아래 한 줄을 `EntitlementStore.shared.isPro`로 되돌리면 잠금이 복원된다.
        let isPro = true
        let summary = summary(for: date, routeKey: routeKey, direction: direction)

        var counterpart: WidgetCounterpart?
        if style == .list, let opposite = oppositeRoute(of: routeKey) {
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
            scheduleLabel: summary.scheduleLabel,
            tomorrowLabel: summary.tomorrowLabel,
            style: style,
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
        let scheduleLabel: String
        let tomorrowLabel: String
    }

    static func summary(for date: Date, routeKey: String, direction: String) -> RouteSummary {
        let json = loadTimetableData()
        let route = json?.routes?[routeKey]
        let times = loadTimetable(for: date, routeKey: routeKey, json: json)
        let viaTimes = Set(route?.viaTimes ?? [])
        let baseDuration = route?.durationMinutes ?? 26
        let traffic = EntitlementStore.loadTraffic(routeKey: routeKey)
        let freshTraffic: (minutes: Int, updatedAt: Date)? = traffic.flatMap { $0.isFresh ? ($0.durationMinutes, $0.updatedAt) : nil }
        let firstBusTime = times.first ?? "06:00"
        let lastBusTime = times.last ?? "23:30"
        let scheduleLabel = usesWeekday(date, holidays: json?.holidays ?? []) ? "평일" : "주말"
        let tomorrow = koreaCalendar.date(byAdding: .day, value: 1, to: date) ?? date
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

        guard let nextIndex = findNextBusIndex(times: times, from: date) else {
            return RouteSummary(
                nextBusTime: nil, remainingMinutes: 0, isServiceEnded: true,
                firstBusTime: tomorrowFirst, lastBusTime: lastBusTime, upcomingBuses: [],
                isLastBus: false, isNightBus: false, isVia: false,
                arrivalTime: timeByAdding(minutes: baseDuration, to: tomorrowFirst),
                usesTraffic: false, trafficUpdatedAt: traffic?.updatedAt,
                durationMinutes: baseDuration, scheduleLabel: scheduleLabel, tomorrowLabel: tomorrowLabel
            )
        }

        let nextBus = times[nextIndex]
        let remaining = minutesUntil(timeString: nextBus, from: date) ?? 0
        let nextEstimate = estimate(nextBus, minutes: remaining)

        var upcoming: [WidgetBus] = []
        for i in (nextIndex + 1)..<min(nextIndex + 5, times.count) {
            if let mins = minutesUntil(timeString: times[i], from: date) {
                let e = estimate(times[i], minutes: mins)
                upcoming.append(WidgetBus(time: times[i], minutes: mins, isVia: viaTimes.contains(times[i]), arrival: e.arrival, usesTraffic: e.usesTraffic))
            }
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
            scheduleLabel: scheduleLabel,
            tomorrowLabel: tomorrowLabel
        )
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

    static func findNextBusIndex(times: [String], from date: Date) -> Int? {
        let calendar = koreaCalendar
        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)
        let currentTotal = currentHour * 60 + currentMinute

        for (index, time) in times.enumerated() {
            let parts = time.split(separator: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]) else { continue }
            if hour * 60 + minute >= currentTotal { return index }
        }
        return nil
    }

    static func minutesUntil(timeString: String, from date: Date) -> Int? {
        let calendar = koreaCalendar
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let targetHour = Int(parts[0]),
              let targetMinute = Int(parts[1]) else { return nil }

        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)
        return (targetHour * 60 + targetMinute) - (currentHour * 60 + currentMinute)
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
        return hour >= 21
    }
}

// MARK: - Static Provider (iOS 16 fallback)

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> BusEntry {
        BusEntry.placeholder(style: .remaining)
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
    let scheduleLabel: String
    let tomorrowLabel: String
    let style: WidgetStyle
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

    static func placeholder(style: WidgetStyle) -> BusEntry {
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
            trafficUpdatedAt: Date().addingTimeInterval(-15 * 60), durationMinutes: 34, scheduleLabel: "평일", tomorrowLabel: "내일 평일",
            style: style,
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

    enum CodingKeys: String, CodingKey {
        case timetable
        case durationMinutes = "duration_minutes"
        case viaTimes = "via_times"
    }
}

// MARK: - Design Tokens
//
// 위젯 타깃은 앱의 AppTheme를 참조할 수 없어 같은 값을 여기에 둔다 (디자인 캔버스 개선안).
// 평면 서피스 하나, 강조색은 남은 시간 숫자에만.

private enum WidgetTheme {
    /// 위젯 컨테이너 — 앱 히어로 카드와 같은 평면 서피스 (#141414)
    static let surface = Color(white: 0.08)
    /// 서피스 안에서 한 단계 올라온 영역 (#1C1C1C)
    static let surfaceSecondary = Color(white: 0.11)
    /// 칩 배경 (#262626)
    static let chip = Color(white: 0.149)
    /// 행 구분선 (#222222)
    static let divider = Color(white: 0.133)
    /// 보조 텍스트 (#A3A3A3, 7.3:1)
    static let secondaryText = Color(white: 0.64)
    /// 3차 텍스트 (#7A7A7A)
    static let tertiaryText = Color(white: 0.478)
    /// 읽은 항목 등 살짝 낮춘 흰색 (#D4D4D4)
    static let mutedText = Color(white: 0.83)
    /// 단일 강조색 — 남은 시간 숫자 (#4ADE80)
    static let accent = Color(red: 74/255, green: 222/255, blue: 128/255)
    /// 심야·막차 라벨
    static let nightFare = Color(red: 251/255, green: 146/255, blue: 60/255)
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
            .foregroundStyle(Color(white: 0.23))

            Text("위젯은 Pro에서 쓸 수 있어요")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
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
                .foregroundStyle(.white)
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
                .foregroundStyle(.white)
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
                    .foregroundStyle(.white)
            }

            HStack(spacing: 6) {
                Circle().fill(.white).frame(width: 6, height: 6)
                Rectangle().fill(Color(white: 0.2)).frame(height: 2)
                Text("\(entry.durationMinutes)분")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.secondaryText)
                Rectangle().fill(Color(white: 0.2)).frame(height: 2)
                Circle().stroke(.white, lineWidth: 1.5).frame(width: 6, height: 6)
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
                    .foregroundStyle(.white)
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
                .foregroundStyle(.white)
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
                switch entry.style {
                case .remaining: styleA
                case .arrival: styleB
                case .list: styleC
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
                        .foregroundStyle(.white)
                }
                Rectangle().fill(WidgetTheme.chip).frame(height: 1)
                HStack(alignment: .lastTextBaseline) {
                    Text("도착 약").font(.system(size: 12, weight: .semibold)).foregroundStyle(WidgetTheme.secondaryText)
                    Spacer()
                    Text(entry.arrivalTime)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .tracking(-0.5)
                        .foregroundStyle(.white)
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
                            .foregroundStyle(.white)
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
                                .foregroundStyle(.white)
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
                switch entry.style {
                case .remaining: styleA
                case .arrival: styleB
                case .list: styleC
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
                        .foregroundStyle(.white)
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
                                    .foregroundStyle(.white)
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
                    .foregroundStyle(.white)
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
                        .foregroundStyle(highlighted ? WidgetTheme.accent : .white)
                    Text(remaining >= 60 ? "시간" : "분")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 4)
                Text("\(nextTime ?? "--:--") · 약 \(arrival) 도착")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Large Widget (디자인 캔버스 WidgetLarge)

struct LargeWidgetView: View {
    let entry: BusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                DirectionLabel(text: "\(entry.direction) · \(entry.scheduleLabel) 시간표")
                Spacer(minLength: 4)
                if entry.isServiceEnded {
                    Text("오늘 운행 종료")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
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
                                .foregroundStyle(.white)
                                .frame(width: 64, alignment: .leading)
                            if bus.isVia { ViaChip() }
                            Spacer(minLength: 0)
                            Text("약 \(bus.arrival)")
                                .font(.system(size: 14, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .frame(width: 84, alignment: .trailing)
                            HStack(spacing: 6) {
                                BasisDot(usesTraffic: bus.usesTraffic)
                                Text(bus.usesTraffic ? "교통 반영" : "시간표 기준")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(bus.usesTraffic ? .white : WidgetTheme.secondaryText)
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
        if entry.isServiceEnded {
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
    BusEntry.placeholder(style: .remaining)
    BusEntry.placeholder(style: .arrival)
    BusEntry.placeholder(style: .list)
}

#Preview(as: .systemMedium) {
    LocalBusWidget()
} timeline: {
    BusEntry.placeholder(style: .remaining)
    BusEntry.placeholder(style: .arrival)
    BusEntry.placeholder(style: .list)
}

#Preview(as: .systemLarge) {
    LocalBusWidget()
} timeline: {
    BusEntry.placeholder(style: .remaining)
}
