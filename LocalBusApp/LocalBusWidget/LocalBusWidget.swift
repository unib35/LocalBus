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
                isNightBus: false
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
            isNightBus: isNightBusTime(nextBus)
        )
    }

    static func loadTimetable(for date: Date, routeKey: String) -> [String] {
        guard let url = Bundle.main.url(forResource: "timetable", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONDecoder().decode(WidgetTimetableData.self, from: data) else {
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
            isNightBus: false
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

private enum WidgetTheme {
    /// 히어로 배경 — AppTheme.Color.heroStart → pure black.
    /// OLED에서 순수 black 이 non-black 과 확실히 구분됨.
    static let bgGradient = LinearGradient(
        colors: [
            Color(white: 0.12),  // #1E1E1E — heroStart보다 살짝 밝아 그라디언트 깊이 강조
            Color.black          // #000000 — OLED 순수 black
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 히어로 카드 오버레이 원 — AppTheme.Color.heroOverlay 와 동일.
    static let bgOverlay = Color.white.opacity(0.04)

    /// 심야/막차 배지 색상 — AppTheme.Color.nightFare(dark) 와 동일.
    static let nightFare = Color(red: 251/255, green: 146/255, blue: 60/255)

    /// 2차 텍스트 — AppTheme.Color.secondaryText dark(~54% white) 근사값.
    static let secondaryText = Color.white.opacity(0.54)

    /// 3차 텍스트 — AppTheme.Color.tertiaryText dark(~33% white) 근사값.
    static let tertiaryText = Color.white.opacity(0.33)

    /// 구분선 — AppTheme.Color.border dark(white 18%) 근사값.
    static let divider = Color(white: 0.18)

    // 긴급도에 따른 카운트다운 색상 (semantic)
    static func urgencyColor(minutes: Int) -> Color {
        if minutes <= 3 { return Color(red: 248/255, green: 113/255, blue: 113/255) } // destructive
        if minutes <= 7 { return Color(red: 251/255, green: 191/255, blue: 36/255) }  // amber
        return Color(red: 74/255, green: 222/255, blue: 128/255)                       // departureGreen
    }

    static func timeColor(minutes: Int) -> Color {
        if minutes <= 3 { return Color(red: 248/255, green: 113/255, blue: 113/255) }
        if minutes <= 7 { return Color(red: 251/255, green: 191/255, blue: 36/255) }
        return .white
    }
}

private enum WidgetDeepLink {
    static let scheme = "localbus"
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
            ZStack(alignment: .topTrailing) {
                WidgetTheme.bgGradient.widgetCanvas()
                // 앱 히어로 카드와 동일한 오버레이 원형 데코레이션
                Circle()
                    .fill(WidgetTheme.bgOverlay)
                    .frame(width: 140, height: 140)
                    .offset(x: 50, y: -60)
            }
        }
    }
}

// MARK: - Widget Entry View

struct LocalBusWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        currentFamilyView
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

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: BusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "bus.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("시외버스")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(WidgetTheme.secondaryText)

            Spacer()

            if entry.isServiceEnded {
                serviceEndedContent
            } else if let nextTime = entry.nextBusTime {
                activeContent(nextTime: nextTime)
            }

            Spacer()

            Text(entry.direction)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WidgetTheme.secondaryText)
                .lineLimit(1)
        }
        .padding(14)
        .widgetCanvas(alignment: .topLeading)
    }

    private var serviceEndedContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("운행 종료")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(WidgetTheme.secondaryText)

            VStack(alignment: .leading, spacing: 1) {
                Text("내일 첫차")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WidgetTheme.tertiaryText)
                Text(entry.firstBusTime)
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
    }

    private func activeContent(nextTime: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            // 출발 시각이 주인공
            Text(nextTime)
                .font(.system(size: 40, weight: .black, design: .monospaced))
                .foregroundStyle(WidgetTheme.timeColor(minutes: entry.remainingMinutes))
                .monospacedDigit()
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            // 카운트다운 + 상태
            HStack(spacing: 5) {
                Circle()
                    .fill(WidgetTheme.urgencyColor(minutes: entry.remainingMinutes))
                    .frame(width: 6, height: 6)
                Text("\(entry.remainingDisplay)\(entry.remainingUnit) 후")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetTheme.secondaryText)

                if entry.isLastBus || entry.isNightBus {
                    statusLabel
                }
            }
        }
    }

    private var statusLabel: some View {
        let isLast = entry.isLastBus
        let label = isLast ? "막차" : "심야"
        let color: Color = isLast ? WidgetTheme.nightFare : WidgetTheme.nightFare
        return Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.18)))
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: BusEntry

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            leftPanel
                .frame(maxWidth: .infinity, alignment: .leading)

            if !entry.isServiceEnded && !entry.upcomingBuses.isEmpty {
                upcomingPanel
                    .frame(width: 104)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .widgetCanvas()
    }

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "bus.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("다음 버스")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(WidgetTheme.secondaryText)

            Spacer()

            if entry.isServiceEnded {
                mediumServiceEnded
            } else if let nextTime = entry.nextBusTime {
                mediumActive(nextTime: nextTime)
            }

            Spacer()

            Text(entry.direction)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WidgetTheme.secondaryText)
                .lineLimit(1)
        }
    }

    private var mediumServiceEnded: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("운행 종료")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(WidgetTheme.secondaryText)
            VStack(alignment: .leading, spacing: 1) {
                Text("내일 첫차")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WidgetTheme.tertiaryText)
                Text(entry.firstBusTime)
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
    }

    private func mediumActive(nextTime: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(nextTime)
                .font(.system(size: 44, weight: .black, design: .monospaced))
                .foregroundStyle(WidgetTheme.timeColor(minutes: entry.remainingMinutes))
                .monospacedDigit()
                .minimumScaleFactor(0.8)
                .lineLimit(1)

            HStack(spacing: 5) {
                Circle()
                    .fill(WidgetTheme.urgencyColor(minutes: entry.remainingMinutes))
                    .frame(width: 6, height: 6)
                Text("\(entry.remainingDisplay)\(entry.remainingUnit) 후")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WidgetTheme.secondaryText)

                if entry.isLastBus || entry.isNightBus {
                    let isLast = entry.isLastBus
                    let label = isLast ? "막차" : "심야"
                    let color: Color = isLast ? WidgetTheme.nightFare : WidgetTheme.nightFare
                    Text(label)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(color.opacity(0.18)))
                }
            }
        }
    }

    private var upcomingPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("이후 버스")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WidgetTheme.secondaryText)
                .padding(.bottom, 9)

            let buses = Array(entry.upcomingBuses.prefix(3))
            ForEach(Array(buses.enumerated()), id: \.offset) { index, bus in
                VStack(alignment: .leading, spacing: 1) {
                    Text(bus.0)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(formatUpcomingMinutes(bus.1) + " 후")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(WidgetTheme.tertiaryText)
                }
                .padding(.bottom, index < buses.count - 1 ? 8 : 0)
            }

            Spacer()
        }
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: BusEntry
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            heroSection
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 152, alignment: .bottomLeading)

            upcomingList
        }
        .widgetCanvas()
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "bus.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("다음 버스")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(WidgetTheme.secondaryText)
            .padding(.bottom, 10)

            if entry.isServiceEnded {
                largeServiceEnded
            } else if let nextTime = entry.nextBusTime {
                largeActive(nextTime: nextTime)
            }
        }
    }

    private var largeServiceEnded: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("운행 종료")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(WidgetTheme.secondaryText)
            VStack(alignment: .leading, spacing: 1) {
                Text("내일 첫차")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WidgetTheme.tertiaryText)
                Text(entry.firstBusTime)
                    .font(.system(size: 44, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            Text(entry.direction)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.tertiaryText)
                .padding(.top, 2)
        }
    }

    private func largeActive(nextTime: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(nextTime)
                .font(.system(size: 52, weight: .black, design: .monospaced))
                .foregroundStyle(WidgetTheme.timeColor(minutes: entry.remainingMinutes))
                .monospacedDigit()
                .minimumScaleFactor(0.8)
                .lineLimit(1)

            HStack(spacing: 6) {
                Circle()
                    .fill(WidgetTheme.urgencyColor(minutes: entry.remainingMinutes))
                    .frame(width: 7, height: 7)
                Text("\(entry.remainingDisplay)\(entry.remainingUnit) 후 출발")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetTheme.secondaryText)

                if entry.isLastBus || entry.isNightBus {
                    let isLast = entry.isLastBus
                    let label = isLast ? "막차" : "심야"
                    let color: Color = isLast ? WidgetTheme.nightFare : WidgetTheme.nightFare
                    Text(label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(color.opacity(0.18)))
                }
            }

            Text(entry.direction)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.secondaryText)
                .padding(.top, 1)
        }
    }

    private var upcomingList: some View {
        let listBg = Color(white: 0.08)   // #141414 — cardBackground dark

        return VStack(spacing: 0) {
            HStack {
                Text("이후 시간표")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WidgetTheme.secondaryText)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 10)

            if entry.upcomingBuses.isEmpty {
                HStack {
                    Text("오늘 남은 버스가 없습니다")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(WidgetTheme.secondaryText)
                    Spacer()
                }
                .padding(.horizontal, 18)
            } else {
                let buses = Array(entry.upcomingBuses.prefix(4))
                ForEach(Array(buses.enumerated()), id: \.offset) { index, bus in
                    HStack(alignment: .center) {
                        Text(bus.0)
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(formatUpcomingMinutes(bus.1) + " 후")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(WidgetTheme.secondaryText)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)

                    if index < buses.count - 1 {
                        Rectangle()
                            .fill(WidgetTheme.divider)
                            .frame(height: 1)
                            .padding(.horizontal, 18)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(listBg)
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

                if entry.isLastBus {
                    Text("막차")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.orange)
                } else if entry.isNightBus {
                    Text("심야")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.purple)
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
             isLastBus: false, isNightBus: false)
    BusEntry(date: .now, routeKey: WidgetDataHelper.defaultRouteKey, nextBusTime: "07:20", remainingMinutes: 2, direction: "장유 → 사상",
             isServiceEnded: false, firstBusTime: "06:00",
             upcomingBuses: [], isLastBus: true, isNightBus: false)
    BusEntry(date: .now, routeKey: WidgetDataHelper.defaultRouteKey, nextBusTime: nil, remainingMinutes: 0, direction: "장유 → 사상",
             isServiceEnded: true, firstBusTime: "06:00",
             upcomingBuses: [], isLastBus: false, isNightBus: false)
}

#Preview(as: .systemMedium) {
    LocalBusWidget()
} timeline: {
    BusEntry(date: .now, routeKey: WidgetDataHelper.defaultRouteKey, nextBusTime: "07:20", remainingMinutes: 15, direction: "장유 → 사상",
             isServiceEnded: false, firstBusTime: "06:00",
             upcomingBuses: [("07:40", 35), ("08:00", 55), ("08:20", 75)],
             isLastBus: false, isNightBus: false)
    BusEntry(date: .now, routeKey: WidgetDataHelper.defaultRouteKey, nextBusTime: "21:40", remainingMinutes: 8, direction: "장유 → 사상",
             isServiceEnded: false, firstBusTime: "06:00",
             upcomingBuses: [("22:00", 28)], isLastBus: false, isNightBus: true)
    BusEntry(date: .now, routeKey: WidgetDataHelper.defaultRouteKey, nextBusTime: nil, remainingMinutes: 0, direction: "장유 → 사상",
             isServiceEnded: true, firstBusTime: "06:00",
             upcomingBuses: [], isLastBus: false, isNightBus: false)
}

#Preview(as: .systemLarge) {
    LocalBusWidget()
} timeline: {
    BusEntry(date: .now, routeKey: WidgetDataHelper.defaultRouteKey, nextBusTime: "07:20", remainingMinutes: 15, direction: "장유 → 사상",
             isServiceEnded: false, firstBusTime: "06:00",
             upcomingBuses: [("07:40", 35), ("08:00", 55), ("08:20", 75), ("08:40", 95)],
             isLastBus: false, isNightBus: false)
}
