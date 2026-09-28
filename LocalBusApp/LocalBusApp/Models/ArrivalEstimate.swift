import Foundation

// MARK: - 도착 예상 (교통 반영) — 디자인 캔버스 EtaHome / EtaBusDetail / EtaStates
//
// 시간표는 출발 기준이므로 도착 시각은 항상 "약". 출발 1시간 이내 버스에만 현재 교통을 반영하고,
// 그 밖에는 노선의 기본 소요시간으로 계산한다. 갱신 중에도 기존 예상값은 그대로 보여준다.

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

    /// "예상 소요 34분" / "기본 소요 26분"
    var durationText: String {
        basis.usesTraffic ? "예상 소요 \(durationMinutes)분" : "기본 소요 \(durationMinutes)분"
    }
}

enum ArrivalEstimator {
    /// 출발까지 이 시간 안이면 교통을 반영한다.
    static let trafficWindowMinutes = 60

    static func estimate(
        departureTime: String,
        minutesUntilDeparture: Int?,
        baseDurationMinutes: Int,
        trafficDurationMinutes: Int?,
        trafficUpdatedAt: Date?,
        isRefreshing: Bool,
        isOffline: Bool
    ) -> ArrivalEstimate {
        let isNear = minutesUntilDeparture.map { $0 >= 0 && $0 <= trafficWindowMinutes } ?? false

        let basis: TrafficBasis
        var duration = baseDurationMinutes
        if !isNear {
            basis = .timetable
        } else if let traffic = trafficDurationMinutes, let updatedAt = trafficUpdatedAt {
            duration = traffic
            basis = isRefreshing ? .refreshing(updatedAt: updatedAt) : .live(updatedAt: updatedAt)
        } else if isRefreshing {
            basis = .refreshing(updatedAt: nil)
        } else {
            basis = isOffline ? .offline : .timetable
        }

        let arrival = DateService.timeByAdding(minutes: duration, to: departureTime) ?? "--:--"
        return ArrivalEstimate(departureTime: departureTime, arrivalTime: arrival, durationMinutes: duration, basis: basis)
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
