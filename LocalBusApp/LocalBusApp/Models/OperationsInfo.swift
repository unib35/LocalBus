import Foundation

// MARK: - 운영 상황 데이터 (디자인 캔버스 C_Operations · Ops*)
//
// 원격 JSON의 "ops"에 실린다. 모든 값이 선택이라 값이 없으면 해당 배너와 화면은 뜨지 않는다.
// 새로 필요한 값: 임시 운휴 기간과 사유, 시간표 변경 시행일, 최소·권장 앱 버전, 점검 여부.

struct OperationsInfo: Codable, Equatable {
    /// 임시 운휴·감편 (가장 급함)
    struct Closure: Codable, Equatable {
        /// yyyy-MM-dd
        let date: String
        let title: String
        let reason: String?
        /// "21:40" — 이날 임시 막차
        let lastBus: String?
        /// nil이면 모든 노선
        let routeKeys: [String]?

        enum CodingKeys: String, CodingKey {
            case date, title, reason
            case lastBus = "last_bus"
            case routeKeys = "route_keys"
        }

        func applies(to routeKey: String) -> Bool {
            guard let routeKeys else { return true }
            return routeKeys.contains(routeKey)
        }
    }

    /// 시간표 변경 예고
    struct Change: Codable, Equatable {
        /// yyyy-MM-dd
        let effectiveDate: String
        let title: String
        let noticeID: String?

        enum CodingKeys: String, CodingKey {
            case effectiveDate = "effective_date"
            case title
            case noticeID = "notice_id"
        }
    }

    /// 서버 점검 (저장된 시간표는 계속 표시)
    struct Maintenance: Codable, Equatable {
        let active: Bool
        let message: String?
    }

    let closure: Closure?
    let change: Change?
    let maintenance: Maintenance?
    let minAppVersion: String?
    let recommendedAppVersion: String?
    let updateMessage: String?

    enum CodingKeys: String, CodingKey {
        case closure, change, maintenance
        case minAppVersion = "min_app_version"
        case recommendedAppVersion = "recommended_app_version"
        case updateMessage = "update_message"
    }

    init(
        closure: Closure? = nil,
        change: Change? = nil,
        maintenance: Maintenance? = nil,
        minAppVersion: String? = nil,
        recommendedAppVersion: String? = nil,
        updateMessage: String? = nil
    ) {
        self.closure = closure
        self.change = change
        self.maintenance = maintenance
        self.minAppVersion = minAppVersion
        self.recommendedAppVersion = recommendedAppVersion
        self.updateMessage = updateMessage
    }
}

// MARK: - 홈 운영 안내 배너

/// 노선 헤더 아래 한 줄. 한 번에 하나만(운휴 > 변경 예고 > 오래됨 > 점검).
enum OperationsBanner: Equatable {
    case closure(title: String, subtitle: String)
    case change(title: String, noticeID: String?)
    case stale(baselineText: String)
    case maintenance(message: String)

    var title: String {
        switch self {
        case .closure(let title, _): return title
        case .change(let title, _): return title
        case .stale: return "\(OperationsEvaluator.staleDays)일 동안 시간표를 확인하지 못했어요"
        case .maintenance(let message): return message
        }
    }

    var subtitle: String {
        switch self {
        case .closure(_, let subtitle): return subtitle
        case .change: return "바뀌는 시각 미리 보기"
        case .stale(let baselineText): return "\(baselineText) 기준 · 바뀌었을 수 있어요"
        case .maintenance: return "저장된 시간표는 그대로 볼 수 있어요"
        }
    }

    /// 오른쪽 글자 버튼. nil이면 chevron만.
    var actionTitle: String? {
        if case .stale = self { return "새로고침" }
        return nil
    }

    var systemImage: String {
        switch self {
        case .closure: return "exclamationmark.triangle.fill"
        case .change: return "calendar"
        case .stale: return "clock"
        case .maintenance: return "wrench.and.screwdriver"
        }
    }

    var isWarning: Bool {
        if case .closure = self { return true }
        return false
    }
}

enum UpdateRequirement: Equatable {
    case none
    case recommended(version: String)
    case required(version: String)
}

enum OperationsEvaluator {
    /// 이 기간 동안 새 시간표를 확인하지 못하면 "오래됨" 배너
    static let staleDays = 7

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dayKey(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    /// 지금 보여줄 배너 하나. 없으면 nil.
    static func banner(
        ops: OperationsInfo?,
        routeKey: String,
        now: Date,
        lastUpdateCheckAt: Date?,
        updatedAt: String
    ) -> OperationsBanner? {
        let today = dayKey(now)

        if let closure = ops?.closure, closure.date == today, closure.applies(to: routeKey) {
            var parts: [String] = []
            if let lastBus = closure.lastBus { parts.append("막차 \(lastBus)") }
            if let reason = closure.reason, !reason.isEmpty { parts.append(reason) }
            return .closure(title: closure.title, subtitle: parts.isEmpty ? "임시 운휴" : parts.joined(separator: " · "))
        }

        if let change = ops?.change, today <= change.effectiveDate {
            return .change(title: change.title, noticeID: change.noticeID)
        }

        if isStale(lastUpdateCheckAt: lastUpdateCheckAt, now: now) {
            return .stale(baselineText: baselineText(updatedAt))
        }

        if let maintenance = ops?.maintenance, maintenance.active {
            return .maintenance(message: maintenance.message ?? "새 시간표 확인을 잠시 멈췄어요")
        }

        return nil
    }

    /// 마지막으로 새 시간표를 확인한 지 7일 이상이면 오래됨. 한 번도 확인 못 했으면(nil) 배너를 띄우지 않는다(첫 실행 오해 방지).
    static func isStale(lastUpdateCheckAt: Date?, now: Date) -> Bool {
        guard let lastUpdateCheckAt else { return false }
        return now.timeIntervalSince(lastUpdateCheckAt) >= Double(staleDays) * 24 * 60 * 60
    }

    /// "2026-03-08" → "3월 8일"
    static func baselineText(_ updatedAt: String) -> String {
        let parts = updatedAt.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return updatedAt }
        return "\(parts[1])월 \(parts[2])일"
    }

    /// 오늘 운휴가 적용되면 "첫차 06:20 · 오늘 막차 21:40 (임시) · 평소 막차 23:30"
    static func serviceSummaryOverride(
        ops: OperationsInfo?,
        routeKey: String,
        now: Date,
        firstBusTime: String,
        lastBusTime: String
    ) -> String? {
        guard let closure = ops?.closure,
              closure.date == dayKey(now),
              closure.applies(to: routeKey),
              let temporaryLastBus = closure.lastBus else { return nil }
        return "첫차 \(firstBusTime) · 오늘 막차 \(temporaryLastBus) (임시) · 평소 막차 \(lastBusTime)"
    }

    /// 필수(min) > 권장(recommended) > 없음. 버전은 "1.2.3" 형태를 숫자 단위로 비교한다.
    static func updateRequirement(current: String, min: String?, recommended: String?) -> UpdateRequirement {
        if let min, compareVersions(current, min) == .orderedAscending {
            return .required(version: min)
        }
        if let recommended, compareVersions(current, recommended) == .orderedAscending {
            return .recommended(version: recommended)
        }
        return .none
    }

    static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let l = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let r = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(l.count, r.count)
        for index in 0..<count {
            let a = index < l.count ? l[index] : 0
            let b = index < r.count ? r[index] : 0
            if a != b { return a < b ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }
}
