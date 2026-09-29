import Foundation

/// "새로고침" 결과. 설정 화면의 시간표 데이터 행이 이 값으로 문구를 바꾼다.
enum TimetableUpdateResult: Equatable {
    /// 원격 시간표가 지금 것과 같은 기준일
    case latest
    /// 새 기준일의 시간표를 받아 적용함. `changes`는 바뀐 시각 요약.
    case updated(from: String, to: String, changes: [TimetableChange])
    /// 네트워크 등으로 확인하지 못함 (저장된 시간표는 계속 사용)
    case failed

    /// 현재 기준일과 새로 받은 기준일을 비교해 결과를 정한다.
    static func evaluate(current: String, fetched: String, changes: [TimetableChange] = []) -> TimetableUpdateResult {
        current == fetched ? .latest : .updated(from: current, to: fetched, changes: changes)
    }
}

/// 새 시간표를 적용했을 때 "바뀐 시간" 한 줄. 예: 평일 막차 · 장유 → 사상, 23:30 → 23:40
struct TimetableChange: Equatable, Identifiable {
    let label: String
    let oldValue: String
    let newValue: String

    var id: String { "\(label)|\(oldValue)|\(newValue)" }

    /// 방향을 뺀 이름. "평일 막차 · 장유 → 사상" → "평일 막차"
    var shortLabel: String {
        label.components(separatedBy: " · ").first ?? label
    }
}

enum TimetableDiff {
    /// 두 시간표를 비교해 사람이 읽을 변경 목록을 만든다. 첫차·막차가 바뀌면 그 이름으로, 나머지는 짝지어 보여준다.
    static func changes(old: TimetableData, new: TimetableData, limit: Int = 6) -> [TimetableChange] {
        var result: [TimetableChange] = []

        func compare(_ oldTimes: [String], _ newTimes: [String], prefix: String, suffix: String?) {
            guard oldTimes != newTimes else { return }
            let name: (String) -> String = { kind in
                var parts = [kind.isEmpty ? prefix : "\(prefix) \(kind)"]
                if let suffix { parts.append(suffix) }
                return parts.joined(separator: " · ")
            }
            var handledOld = Set<String>()
            var handledNew = Set<String>()
            if let o = oldTimes.first, let n = newTimes.first, o != n {
                result.append(TimetableChange(label: name("첫차"), oldValue: o, newValue: n))
                handledOld.insert(o); handledNew.insert(n)
            }
            if let o = oldTimes.last, let n = newTimes.last, o != n {
                result.append(TimetableChange(label: name("막차"), oldValue: o, newValue: n))
                handledOld.insert(o); handledNew.insert(n)
            }
            let removed = oldTimes.filter { !newTimes.contains($0) && !handledOld.contains($0) }
            let added = newTimes.filter { !oldTimes.contains($0) && !handledNew.contains($0) }
            for (o, n) in zip(removed, added) {
                result.append(TimetableChange(label: name(""), oldValue: o, newValue: n))
            }
            if removed.count > added.count {
                for o in removed.dropFirst(added.count) {
                    result.append(TimetableChange(label: name(""), oldValue: o, newValue: "없어짐"))
                }
            } else if added.count > removed.count {
                for n in added.dropFirst(removed.count) {
                    result.append(TimetableChange(label: name(""), oldValue: "추가", newValue: n))
                }
            }
        }

        if let oldRoutes = old.routes, let newRoutes = new.routes {
            for direction in RouteDirection.allCases {
                guard let o = oldRoutes[direction.rawValue], let n = newRoutes[direction.rawValue] else { continue }
                compare(o.timetable.weekday, n.timetable.weekday, prefix: "평일", suffix: direction.displayName)
                compare(o.timetable.weekend, n.timetable.weekend, prefix: "주말", suffix: direction.displayName)
            }
        } else if let o = old.timetable, let n = new.timetable {
            compare(o.weekday, n.weekday, prefix: "평일", suffix: nil)
            compare(o.weekend, n.weekend, prefix: "주말", suffix: nil)
        }

        return Array(result.prefix(limit))
    }

    /// 받은 알림 본문. "평일 07:20 → 07:25 · 평일 막차 23:30 → 23:40". 바뀐 것이 없으면 nil.
    static func summaryText(for changes: [TimetableChange], limit: Int = 2) -> String? {
        guard !changes.isEmpty else { return nil }
        return changes.prefix(limit)
            .map { "\($0.shortLabel) \($0.oldValue) → \($0.newValue)" }
            .joined(separator: " · ")
    }
}

/// "마지막 확인 방금" / "마지막 확인 오늘 09:12" 같은 문구를 만든다.
enum LastCheckedFormatter {
    static func text(for date: Date, now: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = calendar.timeZone

        let elapsed = now.timeIntervalSince(date)
        if elapsed >= 0 && elapsed < 60 { return "방금" }

        if calendar.isDate(date, inSameDayAs: now) {
            formatter.dateFormat = "HH:mm"
            return "오늘 \(formatter.string(from: date))"
        }
        formatter.dateFormat = "M월 d일 HH:mm"
        return formatter.string(from: date)
    }
}
