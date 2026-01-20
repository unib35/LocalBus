//
//  LocalBusWidget.swift
//  LocalBusWidget
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> BusEntry {
        BusEntry(
            date: Date(),
            nextBusTime: "07:00",
            remainingMinutes: 15,
            direction: "장유 → 사상",
            isServiceEnded: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BusEntry) -> ()) {
        let entry = createEntry(for: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [BusEntry] = []
        let currentDate = Date()

        // 1분마다 업데이트되는 타임라인 생성 (최대 30분)
        for minuteOffset in 0..<30 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = createEntry(for: entryDate)
            entries.append(entry)
        }

        // 30분 후 다시 타임라인 요청
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }

    private func createEntry(for date: Date) -> BusEntry {
        let times = loadTimetable(for: date)
        let nextBus = findNextBus(times: times, from: date)

        if let nextBus = nextBus {
            let remaining = minutesUntil(timeString: nextBus, from: date)
            return BusEntry(
                date: date,
                nextBusTime: nextBus,
                remainingMinutes: remaining ?? 0,
                direction: "장유 → 사상",
                isServiceEnded: false
            )
        } else {
            return BusEntry(
                date: date,
                nextBusTime: nil,
                remainingMinutes: 0,
                direction: "장유 → 사상",
                isServiceEnded: true
            )
        }
    }

    // MARK: - Data Loading

    private func loadTimetable(for date: Date) -> [String] {
        // 번들에서 timetable.json 로드
        guard let url = Bundle.main.url(forResource: "timetable", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONDecoder().decode(WidgetTimetableData.self, from: data) else {
            return defaultTimes
        }

        let isWeekday = isWeekdayDate(date) && !isHoliday(date, holidays: json.holidays)

        // routes가 있으면 routes 사용
        if let route = json.routes?["jangyu_to_sasang"] {
            return isWeekday ? route.timetable.weekday : route.timetable.weekend
        }

        // 기존 timetable 사용
        if let timetable = json.timetable {
            return isWeekday ? timetable.weekday : timetable.weekend
        }

        return defaultTimes
    }

    private var defaultTimes: [String] {
        ["06:00", "06:20", "06:40", "07:00", "07:20", "07:40",
         "08:00", "08:20", "08:40", "09:00", "09:20", "09:40"]
    }

    // MARK: - Date Helpers

    private func isWeekdayDate(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday >= 2 && weekday <= 6
    }

    private func isHoliday(_ date: Date, holidays: [String]) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        let dateString = formatter.string(from: date)
        return holidays.contains(dateString)
    }

    private func findNextBus(times: [String], from date: Date) -> String? {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!

        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)
        let currentTotal = currentHour * 60 + currentMinute

        for time in times {
            let parts = time.split(separator: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]) else { continue }

            if hour * 60 + minute >= currentTotal {
                return time
            }
        }
        return nil
    }

    private func minutesUntil(timeString: String, from date: Date) -> Int? {
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
}

// MARK: - Models

struct BusEntry: TimelineEntry {
    let date: Date
    let nextBusTime: String?
    let remainingMinutes: Int
    let direction: String
    let isServiceEnded: Bool
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

// MARK: - Widget Views

struct LocalBusWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: BusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 헤더
            HStack {
                Image(systemName: "bus.fill")
                    .font(.caption)
                Text("시외버스")
                    .font(.caption.bold())
            }
            .foregroundStyle(.blue)

            Spacer()

            if entry.isServiceEnded {
                // 운행 종료
                VStack(alignment: .leading, spacing: 4) {
                    Text("운행 종료")
                        .font(.headline)
                    Text("내일 첫차 06:00")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let nextTime = entry.nextBusTime {
                // 다음 버스
                Text(nextTime)
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                HStack(spacing: 4) {
                    Text("\(entry.remainingMinutes)분 후")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            Text(entry.direction)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MediumWidgetView: View {
    let entry: BusEntry

    var body: some View {
        HStack(spacing: 16) {
            // 왼쪽: 다음 버스 정보
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "bus.fill")
                        .font(.caption)
                    Text("다음 버스")
                        .font(.caption.bold())
                }
                .foregroundStyle(.blue)

                if entry.isServiceEnded {
                    Text("운행 종료")
                        .font(.title2.bold())
                    Text("내일 첫차 06:00")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let nextTime = entry.nextBusTime {
                    Text(nextTime)
                        .font(.system(size: 36, weight: .bold, design: .rounded))

                    Text("\(entry.remainingMinutes)분 후 출발")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(entry.direction)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 오른쪽: 남은 시간 강조
            if !entry.isServiceEnded {
                VStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 70, height: 70)

                        VStack(spacing: 2) {
                            Text("\(entry.remainingMinutes)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.blue)
                            Text("분")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                    Spacer()
                }
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
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                LocalBusWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("다음 버스")
        .description("장유-사상 시외버스 다음 출발 시간을 확인하세요")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    LocalBusWidget()
} timeline: {
    BusEntry(date: .now, nextBusTime: "07:20", remainingMinutes: 15, direction: "장유 → 사상", isServiceEnded: false)
    BusEntry(date: .now, nextBusTime: "07:20", remainingMinutes: 5, direction: "장유 → 사상", isServiceEnded: false)
}

#Preview(as: .systemMedium) {
    LocalBusWidget()
} timeline: {
    BusEntry(date: .now, nextBusTime: "07:20", remainingMinutes: 15, direction: "장유 → 사상", isServiceEnded: false)
}
