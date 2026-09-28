import Foundation

/// "사상에 08:30까지 가려면 몇 시 차?"에 답하는 계산.
/// 시간표는 출발 기준이므로 소요 시간을 빼서 탈 버스를 고른다.
struct ArrivalPlan: Equatable {
    /// 목표 시각까지 도착하는 마지막 버스 (없으면 nil)
    let best: String?
    /// best 한 대 앞
    let earlier: String?
    /// best를 놓쳤을 때 다음 버스 (best가 없으면 첫차)
    let later: String?
    let durationMinutes: Int
    let target: String

    /// best로 갔을 때 남는 여유 (분)
    var slackMinutes: Int? {
        guard let best, let arrive = DateService.timeByAdding(minutes: durationMinutes, to: best) else { return nil }
        return DateService.minutesBetween(from: arrive, to: target)
    }

    /// later로 갔을 때 늦는 시간 (분)
    var lateMinutes: Int? {
        guard let later, let arrive = DateService.timeByAdding(minutes: durationMinutes, to: later) else { return nil }
        return DateService.minutesBetween(from: target, to: arrive)
    }

    func arrival(of departure: String) -> String {
        DateService.timeByAdding(minutes: durationMinutes, to: departure) ?? "--:--"
    }
}

enum ArrivalPlanner {
    /// - Parameters:
    ///   - times: 오늘 시간표 (HH:mm, 오름차순)
    ///   - durationMinutes: 소요 시간
    ///   - target: 목표 도착 시각 (HH:mm)
    static func plan(times: [String], durationMinutes: Int, arriveBy target: String) -> ArrivalPlan {
        let arrivals = times.map { time -> (String, String) in
            (time, DateService.timeByAdding(minutes: durationMinutes, to: time) ?? "99:99")
        }
        let onTime = arrivals.filter { $0.1 <= target }.map(\.0)
        let best = onTime.last

        var earlier: String?
        var later: String?
        if let best, let index = times.firstIndex(of: best) {
            earlier = index > 0 ? times[index - 1] : nil
            later = index + 1 < times.count ? times[index + 1] : nil
        } else {
            later = times.first
        }

        return ArrivalPlan(best: best, earlier: earlier, later: later, durationMinutes: durationMinutes, target: target)
    }

    /// "1시간 12분" 같은 표기
    static func spanText(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)분" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)시간" : "\(hours)시간 \(rest)분"
    }
}
