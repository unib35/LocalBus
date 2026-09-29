import Foundation

// MARK: - 도착 예상 (교통 반영) — 디자인 캔버스 EtaHome / EtaBusDetail / EtaStates
//
// 시간표는 출발 기준이므로 도착 시각은 항상 "약". 출발 1시간 이내 버스에만 현재 교통을 반영하고,
// 그 밖에는 노선의 기본 소요시간으로 계산한다. 갱신 중에도 기존 예상값은 그대로 보여준다.
// 받은 지 오래된 교통값(캐시 주기를 넘긴 값)은 쓰지 않고 시간표 기준으로 되돌린다.

enum TrafficBasis: Equatable {
    /// 현재 교통 반영 (마지막 갱신 시각)
    case live(updatedAt: Date)
    /// 새 교통정보 확인 중. 기존 값이 있으면 그 값을 그대로 보여준다.
    case refreshing(updatedAt: Date?)
    /// 시간표 기준 (기본 소요시간)
    case timetable
    /// 오프라인 · 시간표 기준
    case offline

    var usesTraffic: Bool {
        switch self {
        case .live: return true
        case .refreshing(let updatedAt): return updatedAt != nil
        case .timetable, .offline: return false
        }
    }

    /// 목록 "기준" 열
    var shortLabel: String { usesTraffic ? "교통 반영" : "시간표 기준" }
}

struct ArrivalEstimate: Equatable {
    let departureTime: String
    let arrivalTime: String
    let durationMinutes: Int
    let basis: TrafficBasis
    /// 아직 출발 1시간 전이 아니어서(또는 내일 출발편이라) 교통을 반영하지 않은 시간표 기준
    var awaitsTrafficWindow: Bool = false

    /// "예상 소요 34분" / "기본 소요 26분"
    var durationText: String {
        basis.usesTraffic ? "예상 소요 \(durationMinutes)분" : "기본 소요 \(durationMinutes)분"
    }
}

enum ArrivalEstimator {
    /// 출발까지 이 시간 안이면 교통을 반영한다.
    static let trafficWindowMinutes = 60

    /// 교통값을 받은 뒤 이 시간이 지나면 더는 "현재 교통"으로 보지 않는다 (TrafficService 캐시 주기와 같다).
    static let trafficMaxAgeMinutes = 20

    /// 받은 지 `trafficMaxAgeMinutes` 이내인 교통값인지
    static func isTrafficFresh(updatedAt: Date?, now: Date = Date()) -> Bool {
        guard let updatedAt else { return false }
        return now.timeIntervalSince(updatedAt) <= Double(trafficMaxAgeMinutes) * 60
    }

    static func estimate(
        departureTime: String,
        minutesUntilDeparture: Int?,
        baseDurationMinutes: Int,
        trafficDurationMinutes: Int?,
        trafficUpdatedAt: Date?,
        isRefreshing: Bool,
        isOffline: Bool,
        now: Date = Date()
    ) -> ArrivalEstimate {
        let isDeparted = minutesUntilDeparture.map { $0 < 0 } ?? false
        let isNear = minutesUntilDeparture.map { $0 >= 0 && $0 <= trafficWindowMinutes } ?? false
        let freshTraffic: Int? = isTrafficFresh(updatedAt: trafficUpdatedAt, now: now) ? trafficDurationMinutes : nil

        let basis: TrafficBasis
        var duration = baseDurationMinutes
        var awaitsTrafficWindow = false
        if isNear, let traffic = freshTraffic, let updatedAt = trafficUpdatedAt {
            duration = traffic
            basis = isRefreshing ? .refreshing(updatedAt: updatedAt) : .live(updatedAt: updatedAt)
        } else if isNear, isRefreshing {
            basis = .refreshing(updatedAt: nil)
        } else if isOffline {
            basis = .offline
        } else {
            basis = .timetable
            awaitsTrafficWindow = !isNear && !isDeparted
        }

        let arrival = DateService.timeByAdding(minutes: duration, to: departureTime) ?? "--:--"
        return ArrivalEstimate(
            departureTime: departureTime, arrivalTime: arrival, durationMinutes: duration,
            basis: basis, awaitsTrafficWindow: awaitsTrafficWindow
        )
    }

    /// 홈 히어로 아래 상태 줄. 먼 시간대 버스는 언제부터 교통을 반영하는지 알린다.
    static func statusText(for estimate: ArrivalEstimate, now: Date = Date()) -> String {
        statusText(for: estimate.basis, awaitsTrafficWindow: estimate.awaitsTrafficWindow, now: now)
    }

    static func statusText(for basis: TrafficBasis, awaitsTrafficWindow: Bool, now: Date = Date()) -> String {
        if case .timetable = basis, awaitsTrafficWindow {
            return "시간표 기준 · 출발 1시간 전부터 교통 반영"
        }
        return statusText(for: basis, now: now)
    }

    /// 홈 히어로 아래 상태 줄
    static func statusText(for basis: TrafficBasis, now: Date = Date()) -> String {
        switch basis {
        case .live(let updatedAt):
            return "현재 교통 반영 · \(agoText(updatedAt, now: now)) 갱신"
        case .refreshing(let updatedAt):
            return updatedAt == nil ? "교통정보 확인 중 · 시간표 기준 표시" : "교통정보 갱신 중 · 기존 예상값 표시"
        case .timetable:
            return "시간표 기준 · 기본 소요시간으로 계산"
        case .offline:
            return "오프라인 · 시간표 기준"
        }
    }

    /// "방금" / "3분 전" / "1시간 12분 전"
    static func agoText(_ date: Date, now: Date = Date()) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(date) / 60))
        if minutes < 1 { return "방금" }
        if minutes < 60 { return "\(minutes)분 전" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)시간 전" : "\(hours)시간 \(rest)분 전"
    }

    /// "교통정보 18:15 기준" 같은 설명 카드 각주
    static func footText(for basis: TrafficBasis, lastTrafficAt: Date?) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "HH:mm"
        switch basis {
        case .live(let updatedAt):
            return "교통정보 \(formatter.string(from: updatedAt)) 기준"
        case .refreshing(let updatedAt):
            return updatedAt.map { "교통정보 \(formatter.string(from: $0)) 기준 · 새 정보 확인 중" } ?? "새 정보 확인 중"
        case .timetable, .offline:
            return lastTrafficAt.map { "마지막 교통정보 \(formatter.string(from: $0))" } ?? "교통정보 없음"
        }
    }
}
