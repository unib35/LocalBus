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

    static func createEntry(for date: Date, routeKey: String = defaultRouteKey, direction: String = defaultDirection) -> BusEntry {
        let times = loadTimetable(for: date, routeKey: routeKey)
        let firstBusTime = times.first ?? "06:00"

        guard let nextIndex = findNextBusIndex(times: times, from: date) else {
            return BusEntry(
                date: date,
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
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday >= 2 && weekday <= 6
    }

    static func isHoliday(_ date: Date, holidays: [String]) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        let dateString = formatter.string(from: date)
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

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
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
    let nextBusTime: String?
    let remainingMinutes: Int
    let direction: String
    let isServiceEnded: Bool
    let firstBusTime: String
    let upcomingBuses: [(String, Int)]
    let isLastBus: Bool
    let isNightBus: Bool
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
    static let heroGradientDark = LinearGradient(
        colors: [
            Color(red: 6/255,  green: 18/255, blue: 46/255),
            Color(red: 12/255, green: 24/255, blue: 52/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let heroGradientLight = LinearGradient(
        colors: [
            Color(red: 30/255, green: 64/255,  blue: 175/255),
            Color(red: 29/255, green: 78/255,  blue: 216/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func countdownColor(minutes: Int) -> Color {
        if minutes <= 3 { return Color(red: 239/255, green: 68/255, blue: 68/255) }
        if minutes <= 7 { return Color(red: 251/255, green: 146/255, blue: 60/255) }
        return .white
    }
}

// MARK: - Widget Entry View

struct LocalBusWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: BusEntry
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            heroBackground

            // 장식 원
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 90, height: 90)
                .offset(x: 30, y: -35)

            VStack(alignment: .leading, spacing: 0) {
                // 헤더
                HStack(spacing: 5) {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("시외버스")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.white.opacity(0.55))

                Spacer()

                if entry.isServiceEnded {
                    serviceEndedContent
                } else if let nextTime = entry.nextBusTime {
                    activeContent(nextTime: nextTime)
                }

                Spacer()

                // 방향 푸터
                Text(entry.direction)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.38))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
    }

    private var serviceEndedContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("운행 종료")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("내일 첫차")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.55))
            Text(entry.firstBusTime)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private func activeContent(nextTime: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(entry.remainingMinutes)")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(WidgetTheme.countdownColor(minutes: entry.remainingMinutes))
                    .monospacedDigit()
                Text("분")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .padding(.bottom, 7)
            }

            Text("\(nextTime) 출발")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.82))

            if entry.isLastBus || entry.isNightBus {
                statusBadge
                    .padding(.top, 5)
            }
        }
    }

    private var statusBadge: some View {
        let isLast = entry.isLastBus
        let color: Color = isLast ? .orange : .purple
        return Text(isLast ? "막차" : "심야")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.22)))
    }

    private var heroBackground: some View {
        Group {
            if colorScheme == .dark {
                WidgetTheme.heroGradientDark
            } else {
                WidgetTheme.heroGradientLight
            }
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: BusEntry
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            heroBackground

            // 장식 원
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 130, height: 130)
                .offset(x: 44, y: -55)

            HStack(spacing: 0) {
                leftPanel
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !entry.isServiceEnded && !entry.upcomingBuses.isEmpty {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1)
                        .padding(.vertical, 18)

                    rightPanel
                        .frame(width: 108)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "bus.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("다음 버스")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color.white.opacity(0.55))

            Spacer()

            if entry.isServiceEnded {
                mediumServiceEnded
            } else if let nextTime = entry.nextBusTime {
                mediumActive(nextTime: nextTime)
            }

            Spacer()

            Text(entry.direction)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.38))
        }
    }

    private var mediumServiceEnded: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("운행 종료")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("내일 첫차  \(entry.firstBusTime)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.7))
        }
    }

    private func mediumActive(nextTime: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(entry.remainingMinutes)")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(WidgetTheme.countdownColor(minutes: entry.remainingMinutes))
                    .monospacedDigit()
                Text("분")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .padding(.bottom, 8)
            }

            Text("\(nextTime) 출발")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.82))

            if entry.isLastBus || entry.isNightBus {
                mediumStatusBadge
                    .padding(.top, 5)
            }
        }
    }

    private var mediumStatusBadge: some View {
        let isLast = entry.isLastBus
        let color: Color = isLast ? .orange : .purple
        return Text(isLast ? "막차" : "심야")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.22)))
    }

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("이후 버스")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.45))
                .padding(.bottom, 10)

            let displayBuses = Array(entry.upcomingBuses.prefix(3))
            ForEach(Array(displayBuses.enumerated()), id: \.offset) { index, bus in
                HStack(alignment: .center) {
                    Text(bus.0)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.9))
                    Spacer()
                    Text("\(bus.1)분")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.48))
                }
                .padding(.bottom, index < displayBuses.count - 1 ? 8 : 0)
            }

            Spacer()
        }
        .padding(.leading, 14)
        .padding(.vertical, 14)
    }

    private var heroBackground: some View {
        Group {
            if colorScheme == .dark {
                WidgetTheme.heroGradientDark
            } else {
                WidgetTheme.heroGradientLight
            }
        }
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: BusEntry
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // 상단 히어로 섹션
            ZStack(alignment: .topTrailing) {
                heroBackground

                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 130, height: 130)
                    .offset(x: 44, y: -50)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 5) {
                            Image(systemName: "bus.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("다음 버스")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Color.white.opacity(0.55))
                        .padding(.bottom, 10)

                        if entry.isServiceEnded {
                            largeServiceEnded
                        } else if let nextTime = entry.nextBusTime {
                            largeActive(nextTime: nextTime)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .frame(height: 148)

            // 이후 버스 목록
            upcomingList
        }
    }

    private var largeServiceEnded: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("운행 종료")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("내일 첫차  \(entry.firstBusTime)")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.7))
            Text(entry.direction)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.38))
                .padding(.top, 2)
        }
    }

    private func largeActive(nextTime: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text("\(entry.remainingMinutes)")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundStyle(WidgetTheme.countdownColor(minutes: entry.remainingMinutes))
                    .monospacedDigit()
                Text("분")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .padding(.bottom, 10)
            }
            HStack(spacing: 8) {
                Text("\(nextTime) 출발")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.82))

                if entry.isLastBus || entry.isNightBus {
                    let isLast = entry.isLastBus
                    let color: Color = isLast ? .orange : .purple
                    Text(isLast ? "막차" : "심야")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(color.opacity(0.22)))
                }
            }
            Text(entry.direction)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.38))
                .padding(.top, 2)
        }
    }

    private var upcomingList: some View {
        let cardBg = colorScheme == .dark
            ? Color(red: 11/255, green: 15/255, blue: 24/255)
            : Color.white
        let border = colorScheme == .dark
            ? Color(red: 31/255, green: 41/255, blue: 55/255)
            : Color(red: 191/255, green: 219/255, blue: 254/255)
        let secondaryText = colorScheme == .dark
            ? Color(red: 156/255, green: 163/255, blue: 175/255)
            : Color(red: 55/255, green: 65/255, blue: 81/255)
        let primaryText = colorScheme == .dark ? Color.white : Color(red: 15/255, green: 23/255, blue: 42/255)

        return VStack(spacing: 0) {
            HStack {
                Text("이후 시간표")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(secondaryText)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            if entry.upcomingBuses.isEmpty {
                HStack {
                    Text("오늘 남은 버스가 없습니다")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(secondaryText)
                    Spacer()
                }
                .padding(.horizontal, 16)
            } else {
                let displayBuses = Array(entry.upcomingBuses.prefix(4))
                ForEach(Array(displayBuses.enumerated()), id: \.offset) { index, bus in
                    HStack {
                        Text(bus.0)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(primaryText)
                        Spacer()
                        Text("\(bus.1)분 후")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(secondaryText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if index < displayBuses.count - 1 {
                        Rectangle()
                            .fill(border.opacity(0.6))
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardBg)
    }

    private var heroBackground: some View {
        Group {
            if colorScheme == .dark {
                WidgetTheme.heroGradientDark
            } else {
                WidgetTheme.heroGradientLight
            }
        }
    }
}

// MARK: - Widget Configuration

struct LocalBusWidget: Widget {
    let kind: String = "LocalBusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                LocalBusWidgetEntryView(entry: entry)
                    .containerBackground(.clear, for: .widget)
            } else {
                LocalBusWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("다음 버스")
        .description("장유-사상 시외버스 다음 출발 시간을 확인하세요")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    LocalBusWidget()
} timeline: {
    BusEntry(date: .now, nextBusTime: "07:20", remainingMinutes: 15, direction: "장유 → 사상",
             isServiceEnded: false, firstBusTime: "06:00",
             upcomingBuses: [("07:40", 35), ("08:00", 55)],
             isLastBus: false, isNightBus: false)
    BusEntry(date: .now, nextBusTime: "07:20", remainingMinutes: 2, direction: "장유 → 사상",
             isServiceEnded: false, firstBusTime: "06:00",
             upcomingBuses: [], isLastBus: true, isNightBus: false)
    BusEntry(date: .now, nextBusTime: nil, remainingMinutes: 0, direction: "장유 → 사상",
             isServiceEnded: true, firstBusTime: "06:00",
             upcomingBuses: [], isLastBus: false, isNightBus: false)
}

#Preview(as: .systemMedium) {
    LocalBusWidget()
} timeline: {
    BusEntry(date: .now, nextBusTime: "07:20", remainingMinutes: 15, direction: "장유 → 사상",
             isServiceEnded: false, firstBusTime: "06:00",
             upcomingBuses: [("07:40", 35), ("08:00", 55), ("08:20", 75)],
             isLastBus: false, isNightBus: false)
    BusEntry(date: .now, nextBusTime: "21:40", remainingMinutes: 8, direction: "장유 → 사상",
             isServiceEnded: false, firstBusTime: "06:00",
             upcomingBuses: [("22:00", 28)], isLastBus: false, isNightBus: true)
    BusEntry(date: .now, nextBusTime: nil, remainingMinutes: 0, direction: "장유 → 사상",
             isServiceEnded: true, firstBusTime: "06:00",
             upcomingBuses: [], isLastBus: false, isNightBus: false)
}

#Preview(as: .systemLarge) {
    LocalBusWidget()
} timeline: {
    BusEntry(date: .now, nextBusTime: "07:20", remainingMinutes: 15, direction: "장유 → 사상",
             isServiceEnded: false, firstBusTime: "06:00",
             upcomingBuses: [("07:40", 35), ("08:00", 55), ("08:20", 75), ("08:40", 95)],
             isLastBus: false, isNightBus: false)
}
