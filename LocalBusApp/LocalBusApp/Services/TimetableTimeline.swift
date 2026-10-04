import Foundation

/// 배열 끝의 00:10처럼 자정을 넘기는 편은 이전 운행일에 속합니다.
enum TimetableTimeline {
    struct Departure {
        let time: String
        let date: Date
        let serviceDate: Date
        let isLast: Bool
    }

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    static func times(on date: Date, weekday: [String], weekend: [String], holidays: [String]) -> [String] {
        let day = calendar.component(.weekday, from: date)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let dateKey = String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
        return (2...6).contains(day) && !holidays.contains(dateKey) ? weekday : weekend
    }

    /// 조회 중인 운행일의 편을 날짜로 변환합니다. 자정 이후 꼬리 편도 같은 운행일에 속합니다.
    static func departure(time: String, times: [String], serviceDate: Date) -> Departure? {
        var previous = -1
        var dayOffset = 0
        for (index, value) in times.enumerated() {
            let parts = value.split(separator: ":")
            guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
                  (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
            let total = hour * 60 + minute
            if total < previous { dayOffset += 1 }
            previous = total
            if value == time {
                let date = calendar.date(byAdding: .minute, value: dayOffset * 1440 + total, to: calendar.startOfDay(for: serviceDate))!
                return Departure(time: value, date: date, serviceDate: calendar.startOfDay(for: serviceDate), isLast: index == times.count - 1)
            }
        }
        return nil
    }

    static func departures(weekday: [String], weekend: [String], holidays: [String], from date: Date) -> [Departure] {
        let calendar = calendar
        let today = calendar.startOfDay(for: date)
        // 시간표는 분 단위이므로 출발 분이 끝날 때까지 해당 편을 표시합니다.
        let minuteStart = calendar.dateInterval(of: .minute, for: date)!.start
        var result: [Departure] = []
        for offset in -1...1 {
            let serviceDate = calendar.date(byAdding: .day, value: offset, to: today)!
            let validTimes = times(on: serviceDate, weekday: weekday, weekend: weekend, holidays: holidays).compactMap { time -> (String, Int)? in
                let parts = time.split(separator: ":", omittingEmptySubsequences: false)
                guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
                      (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
                return (time, hour * 60 + minute)
            }
            var previousMinute = -1
            var dayOffset = 0
            for (index, entry) in validTimes.enumerated() {
                let (time, minute) = entry
                if minute < previousMinute { dayOffset += 1 }
                previousMinute = minute
                let departureDate = calendar.date(byAdding: .minute, value: dayOffset * 1440 + minute, to: serviceDate)!
                if departureDate >= minuteStart {
                    result.append(Departure(time: time, date: departureDate, serviceDate: serviceDate, isLast: index == validTimes.count - 1))
                }
            }
        }
        return result.sorted { $0.date < $1.date }
    }
}
