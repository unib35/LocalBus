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

    /// UI 테스트용 식별자 키. rawValue가 한국어라 표시 문구와 분리해 둔다.
    var accessibilityKey: String {
        switch self {
        case .weekday: return "weekday"
        case .weekend: return "weekend"
        }
    }
}
