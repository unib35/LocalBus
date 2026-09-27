//
//  LocalBusWidget.swift
//  LocalBusWidget
//

import WidgetKit
import SwiftUI

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

    static var koreaCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = koreaTimeZone
        return calendar
    }

    static func createEntry(for date: Date, routeKey: String = defaultRouteKey, direction: String = defaultDirection) -> BusEntry {
        // v1.0 무료 출시: IAP 미적용 상태이므로 위젯을 모두에게 개방한다.
        // IAP 도입 시 아래 한 줄을 `EntitlementStore.shared.isPro`로 되돌리면 잠금이 복원된다.
        let isPro = true
        let times = loadTimetable(for: date, routeKey: routeKey)
        let firstBusTime = times.first ?? "06:00"

        guard let nextIndex = findNextBusIndex(times: times, from: date) else {
            return BusEntry(
                date: date,
                routeKey: routeKey,
                nextBusTime: nil,
                remainingMinutes: 0,
                direction: direction,
                isServiceEnded: true,
                firstBusTime: firstBusTime,
                upcomingBuses: [],
                isLastBus: false,
                isNightBus: false,
                isPro: isPro
            )
        }

        let nextBus = times[nextIndex]
        let remaining = minutesUntil(timeString: nextBus, from: date) ?? 0

        var upcoming: [(String, Int)] = []
        for i in (nextIndex + 1)..<min(nextIndex + 5, times.count) {
            if let mins = minutesUntil(timeString: times[i], from: date) {
                upcoming.append((times[i], mins))
            }
        }

        return BusEntry(
            date: date,
            routeKey: routeKey,
            nextBusTime: nextBus,
            remainingMinutes: remaining,
            direction: direction,
            isServiceEnded: false,
            firstBusTime: firstBusTime,
            upcomingBuses: upcoming,
            isLastBus: (nextIndex == times.count - 1),
            isNightBus: isNightBusTime(nextBus),
            isPro: isPro
        )
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

    static func loadTimetable(for date: Date, routeKey: String) -> [String] {
        guard let json = loadTimetableData() else {
            return defaultTimes
        }

        let isWeekday = isWeekdayDate(date) && !isHoliday(date, holidays: json.holidays)

        if let route = json.routes?[routeKey] {
            return isWeekday ? route.timetable.weekday : route.timetable.weekend
        }
        if let timetable = json.timetable {
            return isWeekday ? timetable.weekday : timetable.weekend
        }
        return defaultTimes
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
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!

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
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!

        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let targetHour = Int(parts[0]),
              let targetMinute = Int(parts[1]) else { return nil }

        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)
        return (targetHour * 60 + targetMinute) - (currentHour * 60 + currentMinute)
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
        BusEntry(
            date: Date(),
            routeKey: WidgetDataHelper.defaultRouteKey,
            nextBusTime: "07:00",
            remainingMinutes: 15,
            direction: WidgetDataHelper.defaultDirection,
            isServiceEnded: false,
            firstBusTime: "06:00",
            upcomingBuses: [("07:20", 35), ("07:40", 55), ("08:00", 75), ("08:20", 95)],
            isLastBus: false,
            isNightBus: false,
            isPro: true
        )
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

struct BusEntry: TimelineEntry {
    let date: Date
    let routeKey: String
    let nextBusTime: String?
    let remainingMinutes: Int
    let direction: String
    let isServiceEnded: Bool
    let firstBusTime: String
    let upcomingBuses: [(String, Int)]
    let isLastBus: Bool
    let isNightBus: Bool
    let isPro: Bool

    var remainingDisplay: String {
        remainingMinutes >= 60 ? String(remainingMinutes / 60) : String(remainingMinutes)
    }

    var remainingUnit: String {
        remainingMinutes >= 60 ? "시간" : "분"
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
    /// 행 구분선 (#222222)
    static let divider = Color(white: 0.133)
    /// 보조 텍스트 (#A3A3A3, 7.3:1)
    static let secondaryText = Color(white: 0.64)
    /// 3차 텍스트 (#7A7A7A)
    static let tertiaryText = Color(white: 0.478)
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
        .widgetURL(WidgetDeepLink.url(for: entry.routeKey))
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
                    Text("장유시외버스")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                Text("위젯은 Pro 전용 기능입니다")
                    .font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            homeScreenLocked
        }
    }

    private var homeScreenLocked: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            Text("Pro 업그레이드")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Text("위젯은 앱에서 Pro를 시작하면 켜져요")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .widgetCanvas(alignment: .topLeading)
    }
}

// MARK: - 공통 조각

/// 남은 시간이 주인공. "12" + "분" (또는 "1" + "시간").
private struct RemainingHero: View {
    let entry: BusEntry
    var numberSize: CGFloat = 56

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(entry.remainingDisplay)
                .font(.system(size: numberSize, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .tracking(-1.5)
                .foregroundStyle(WidgetTheme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(entry.remainingUnit) 후")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.remainingDisplay)\(entry.remainingUnit) 후 출발")
    }
}

/// "07:20 출발" + 막차/심야 라벨
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

/// 운행 종료 — 내일 첫차
private struct ServiceEndedBlock: View {
    let entry: BusEntry
    var timeSize: CGFloat = 32

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("오늘 운행 종료")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WidgetTheme.secondaryText)
            Text(entry.firstBusTime)
                .font(.system(size: timeSize, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .tracking(-1)
                .foregroundStyle(.white)
            Text("내일 첫차")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.secondaryText)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: BusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.direction)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WidgetTheme.secondaryText)
                .lineLimit(1)

            Spacer(minLength: 4)

            if entry.isServiceEnded {
                ServiceEndedBlock(entry: entry)
            } else if let nextTime = entry.nextBusTime {
                RemainingHero(entry: entry)
                DepartureLine(entry: entry, nextTime: nextTime)
                    .padding(.top, 2)
            }

            Spacer(minLength: 4)

            if !entry.isServiceEnded {
                let next = entry.upcomingBuses.prefix(2).map(\.0)
                if !next.isEmpty {
                    Text("다음 " + next.joined(separator: " · "))
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .widgetCanvas(alignment: .topLeading)
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: BusEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            leftPanel
                .frame(maxWidth: .infinity, alignment: .leading)

            if !entry.isServiceEnded && !entry.upcomingBuses.isEmpty {
                upcomingPanel
                    .frame(width: 132)
            }
        }
        .padding(16)
        .widgetCanvas()
    }

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.direction)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WidgetTheme.secondaryText)
                .lineLimit(1)

            Spacer(minLength: 4)

            if entry.isServiceEnded {
                ServiceEndedBlock(entry: entry, timeSize: 36)
            } else if let nextTime = entry.nextBusTime {
                RemainingHero(entry: entry)
                DepartureLine(entry: entry, nextTime: nextTime)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
    }

    private var upcomingPanel: some View {
        let buses = Array(entry.upcomingBuses.prefix(3))
        return VStack(spacing: 0) {
            ForEach(Array(buses.enumerated()), id: \.offset) { index, bus in
                HStack {
                    Text(bus.0)
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Spacer()
                    Text(formatUpcomingMinutes(bus.1))
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.secondaryText)
                }
                .frame(height: 34)

                if index < buses.count - 1 {
                    Rectangle()
                        .fill(WidgetTheme.divider)
                        .frame(height: 1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: BusEntry

    var body: some View {
        VStack(spacing: 0) {
            heroSection
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 160, alignment: .topLeading)

            upcomingList
        }
        .widgetCanvas()
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.direction)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WidgetTheme.secondaryText)

            Spacer(minLength: 6)

            if entry.isServiceEnded {
                ServiceEndedBlock(entry: entry, timeSize: 44)
            } else if let nextTime = entry.nextBusTime {
                RemainingHero(entry: entry, numberSize: 64)
                DepartureLine(entry: entry, nextTime: nextTime)
                    .padding(.top, 2)
            }
        }
    }

    private var upcomingList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("이어지는 버스")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(WidgetTheme.secondaryText)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 6)

            if entry.upcomingBuses.isEmpty {
                HStack {
                    Text("오늘 남은 버스가 없습니다")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(WidgetTheme.secondaryText)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
            } else {
                let buses = Array(entry.upcomingBuses.prefix(4))
                ForEach(Array(buses.enumerated()), id: \.offset) { index, bus in
                    HStack(alignment: .center) {
                        Text(bus.0)
                            .font(.system(size: 17, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                        Spacer()
                        Text(formatUpcomingMinutes(bus.1) + " 후")
                            .font(.system(size: 14, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(WidgetTheme.secondaryText)
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 44)

                    if index < buses.count - 1 {
                        Rectangle()
                            .fill(WidgetTheme.divider)
                            .frame(height: 1)
                            .padding(.leading, 18)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WidgetTheme.surfaceSecondary)
    }
}

// MARK: - Accessory (Lock Screen) Widgets

struct AccessoryCircularView: View {
    let entry: BusEntry

    var body: some View {
        if entry.isServiceEnded {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 14))
                    Text("종료")
                        .font(.system(size: 9, weight: .semibold))
                }
            }
        } else {
            Gauge(value: Double(min(entry.remainingMinutes, 60)), in: 0...60) {
                Image(systemName: "bus.fill")
            } currentValueLabel: {
                Text(entry.remainingDisplay)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircular)
        }
    }
}

struct AccessoryRectangularView: View {
    let entry: BusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "bus.fill")
                    .font(.system(size: 10))
                Text(entry.direction)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.secondary)

            if entry.isServiceEnded {
                Text("운행 종료 · 첫차 \(entry.firstBusTime)")
                    .font(.system(size: 14, weight: .medium))
            } else if let nextTime = entry.nextBusTime {
                Text("\(nextTime) 출발 · \(formatUpcomingMinutes(entry.remainingMinutes)) 후")
                    .font(.system(size: 15, weight: .bold))

                if entry.isLastBus || entry.isNightBus {
                    Text(entry.isLastBus ? "막차" : "심야")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AccessoryInlineView: View {
    let entry: BusEntry

    var body: some View {
        if entry.isServiceEnded {
            Label("운행 종료", systemImage: "bus.fill")
        } else if let nextTime = entry.nextBusTime {
            Label("\(nextTime) · \(formatUpcomingMinutes(entry.remainingMinutes)) 후", systemImage: "bus.fill")
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
    BusEntry(date: .now, routeKey: WidgetDataHelper.defaultRouteKey, nextBusTime: "07:20", remainingMinutes: 15, direction: "장유 → 사상",
             isServiceEnded: false, firstBusTime: "06:00",
             upcomingBuses: [("07:40", 35), ("08:00", 55)],
             isLastBus: false, isNightBus: false, isPro: true)
    BusEntry(date: .now, routeKey: WidgetDataHelper.defaultRouteKey, nextBusTime: "07:20", remainingMinutes: 2, direction: "장유 → 사상",
             isServiceEnded: false, firstBusTime: "06:00",
             upcomingBuses: [], isLastBus: true, isNightBus: false, isPro: true)
    BusEntry(date: .now, routeKey: WidgetDataHelper.defaultRouteKey, nextBusTime: nil, remainingMinutes: 0, direction: "장유 → 사상",
             isServiceEnded: true, firstBusTime: "06:00",
             upcomingBuses: [], isLastBus: false, isNightBus: false, isPro: true)
    BusEntry(date: .now, routeKey: WidgetDataHelper.defaultRouteKey, nextBusTime: "07:20", remainingMinutes: 15, direction: "장유 → 사상",
             isServiceEnded: false, firstBusTime: "06:00",
             upcomingBuses: [], isLastBus: false, isNightBus: false, isPro: false)
}

#Preview(as: .systemMedium) {
    LocalBusWidget()
} timeline: {
    BusEntry(date: .now, routeKey: WidgetDataHelper.defaultRouteKey, nextBusTime: "07:20", remainingMinutes: 15, direction: "장유 → 사상",
             isServiceEnded: false, firstBusTime: "06:00",
             upcomingBuses: [("07:40", 35), ("08:00", 55), ("08:20", 75)],
             isLastBus: false, isNightBus: false, isPro: true)
    BusEntry(date: .now, routeKey: WidgetDataHelper.defaultRouteKey, nextBusTime: "21:40", remainingMinutes: 8, direction: "장유 → 사상",
             isServiceEnded: false, firstBusTime: "06:00",
             upcomingBuses: [("22:00", 28)], isLastBus: false, isNightBus: true, isPro: true)
    BusEntry(date: .now, routeKey: WidgetDataHelper.defaultRouteKey, nextBusTime: nil, remainingMinutes: 0, direction: "장유 → 사상",
             isServiceEnded: true, firstBusTime: "06:00",
             upcomingBuses: [], isLastBus: false, isNightBus: false, isPro: true)
    BusEntry(date: .now, routeKey: WidgetDataHelper.defaultRouteKey, nextBusTime: "07:20", remainingMinutes: 15, direction: "장유 → 사상",
             isServiceEnded: false, firstBusTime: "06:00",
             upcomingBuses: [], isLastBus: false, isNightBus: false, isPro: false)
}

#Preview(as: .systemLarge) {
    LocalBusWidget()
} timeline: {
    BusEntry(date: .now, routeKey: WidgetDataHelper.defaultRouteKey, nextBusTime: "07:20", remainingMinutes: 15, direction: "장유 → 사상",
             isServiceEnded: false, firstBusTime: "06:00",
             upcomingBuses: [("07:40", 35), ("08:00", 55), ("08:20", 75), ("08:40", 95)],
             isLastBus: false, isNightBus: false, isPro: true)
    BusEntry(date: .now, routeKey: WidgetDataHelper.defaultRouteKey, nextBusTime: "07:20", remainingMinutes: 15, direction: "장유 → 사상",
             isServiceEnded: false, firstBusTime: "06:00",
             upcomingBuses: [], isLastBus: false, isNightBus: false, isPro: false)
}
