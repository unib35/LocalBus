import Foundation

/// "업데이트 확인" 결과. 설정 화면의 시간표 데이터 카드가 이 값으로 문구를 바꾼다.
enum TimetableUpdateResult: Equatable {
    /// 원격 시간표가 지금 것과 같은 기준일
    case latest
    /// 새 기준일의 시간표를 받아 적용함
    case updated(from: String, to: String)
    /// 네트워크 등으로 확인하지 못함 (저장된 시간표는 계속 사용)
    case failed

    /// 현재 기준일과 새로 받은 기준일을 비교해 결과를 정한다.
    static func evaluate(current: String, fetched: String) -> TimetableUpdateResult {
        current == fetched ? .latest : .updated(from: current, to: fetched)
    }
}

/// "마지막 확인 오늘 09:12" 같은 문구를 만든다.
enum LastCheckedFormatter {
    static func text(for date: Date, now: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = calendar.timeZone

        if calendar.isDate(date, inSameDayAs: now) {
            formatter.dateFormat = "HH:mm"
            return "오늘 \(formatter.string(from: date))"
        }
        formatter.dateFormat = "M월 d일 HH:mm"
        return formatter.string(from: date)
    }
}
