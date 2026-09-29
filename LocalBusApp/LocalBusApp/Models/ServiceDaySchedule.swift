import Foundation

/// 운행일 기준 시각 계산. 앱과 위젯 타깃이 함께 쓴다.
///
/// 시간표 끝에 자정을 넘긴 시각(예: 사상 → 장유 막차 00:10)이 오면 달력 날짜가 아니라
/// 같은 운행일의 24시 이후로 센다. 그래야 낮에 막차까지 남은 시간이 0이 되지 않고,
/// 23:40에도 00:10 버스가 남아 있는 것으로 나온다.
struct ServiceDaySchedule: Equatable {
    static let minutesPerDay = 24 * 60

    /// 시간표 순서 그대로의 출발 시각 (읽을 수 없는 값은 뺀다)
    let times: [String]
    /// 운행일 기준 분. 자정을 넘긴 시각은 24시간을 더한 값
    let serviceMinutes: [Int]
    /// 운행일 기준 현재 분
    let nowMinutes: Int
    /// 자정 직후, 전날 시간표의 자정 넘은 버스가 아직 남아 있는 구간
    let isOvernightTail: Bool

    init(times: [String], nowMinutes: Int, isOvernightTail: Bool = false) {
        let readable = times.filter { Self.clockMinutes($0) != nil }
        self.times = readable
        self.serviceMinutes = Self.serviceMinutes(of: readable)
        self.nowMinutes = nowMinutes
        self.isOvernightTail = isOvernightTail
    }

    /// 지금 봐야 할 운행일의 시간표를 고른다.
    /// - Parameters:
    ///   - todayTimes: 오늘 날짜의 시간표
    ///   - yesterdayTimes: 어제 날짜의 시간표 (자정 넘은 버스가 남았는지 확인용)
    ///   - clockMinutes: 지금 시각을 자정부터 센 분
    static func resolve(todayTimes: [String], yesterdayTimes: [String], clockMinutes: Int) -> ServiceDaySchedule {
        let carried = clockMinutes + minutesPerDay
        if let lastOfYesterday = serviceMinutes(of: yesterdayTimes).last,
           lastOfYesterday >= minutesPerDay,
           carried <= lastOfYesterday {
            return ServiceDaySchedule(times: yesterdayTimes, nowMinutes: carried, isOvernightTail: true)
        }
        return ServiceDaySchedule(times: todayTimes, nowMinutes: clockMinutes)
    }

    /// "HH:mm" → 자정부터 센 분
    static func clockMinutes(_ time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        return hour * 60 + minute
    }

    /// 앞 시각보다 이른 시각이 나오면 자정을 넘긴 것으로 보고 24시간을 더한다.
    static func serviceMinutes(of times: [String]) -> [Int] {
        var offset = 0
        var previous = Int.min
        var result: [Int] = []
        for time in times {
            guard let clock = clockMinutes(time) else { continue }
            if clock + offset < previous { offset += minutesPerDay }
            previous = clock + offset
            result.append(previous)
        }
        return result
    }

    /// 목표 시각까지 도착하는 마지막 버스의 위치
    static func lastIndex(arrivingBy target: String, times: [String], durationMinutes: Int) -> Int? {
        let readable = times.filter { clockMinutes($0) != nil }
        let minutes = serviceMinutes(of: readable)
        guard var targetMinutes = clockMinutes(target), let first = minutes.first else { return nil }
        // 첫차보다 이른 목표는 자정을 넘긴 시각으로 본다 (예: 00:45까지 도착)
        if targetMinutes < first, (minutes.last ?? 0) + durationMinutes >= minutesPerDay {
            targetMinutes += minutesPerDay
        }
        return minutes.lastIndex { $0 + durationMinutes <= targetMinutes }
    }

    /// 다음 버스 위치 (없으면 운행 종료)
    var nextIndex: Int? {
        serviceMinutes.firstIndex { $0 >= nowMinutes }
    }

    func minutesUntil(index: Int) -> Int {
        serviceMinutes[index] - nowMinutes
    }

    /// 같은 시각이 두 번 나오지 않는다고 보고 처음 나온 것을 쓴다.
    func minutesUntil(_ time: String) -> Int? {
        times.firstIndex(of: time).map(minutesUntil(index:))
    }

    func isPast(_ time: String) -> Bool {
        (minutesUntil(time) ?? 0) < 0
    }

    /// 막차까지 남은 분 (지났으면 0, 시간표가 비었으면 nil)
    var minutesUntilLast: Int? {
        serviceMinutes.last.map { max($0 - nowMinutes, 0) }
    }
}
