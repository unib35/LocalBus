import Foundation

/// 시간표 유형 (평일/주말)
enum ScheduleType: String, CaseIterable {
    case weekday = "평일"
    case weekend = "주말"

    var displayLabel: String {
        switch self {
        case .weekday: return "평일"
        case .weekend: return "주말/공휴일"
        }
    }
}
