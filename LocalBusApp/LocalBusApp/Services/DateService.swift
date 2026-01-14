import Foundation

/// 날짜 및 시간 관련 유틸리티 서비스
enum DateService {

    private static let koreaTimeZone = TimeZone(identifier: "Asia/Seoul")!

    // MARK: - 평일/주말 판단

    /// 해당 날짜가 평일인지 확인 (월~금)
    static func isWeekday(_ date: Date) -> Bool {
        var calendar = Calendar.current
        calendar.timeZone = koreaTimeZone
        let weekday = calendar.component(.weekday, from: date)
        // 1: 일요일, 7: 토요일
        return weekday >= 2 && weekday <= 6
    }

    // MARK: - 공휴일 판단

    /// 해당 날짜가 공휴일인지 확인
    static func isHoliday(_ date: Date, holidays: [String]) -> Bool {
        let dateString = formatDate(date)
        return holidays.contains(dateString)
    }

    // MARK: - 시간표 타입 판단

    /// 평일 시간표를 사용해야 하는지 확인
    /// 평일이고 공휴일이 아닌 경우에만 true
    static func shouldUseWeekdaySchedule(_ date: Date, holidays: [String]) -> Bool {
        return isWeekday(date) && !isHoliday(date, holidays: holidays)
    }

    // MARK: - 다음 버스 찾기

    /// 현재 시간 이후 가장 가까운 버스 시간 반환
    /// - Parameters:
    ///   - times: 버스 시간 목록 (HH:mm 형식)
    ///   - from: 기준 시간
    /// - Returns: 다음 버스 시간 (없으면 nil)
    static func findNextBus(times: [String], from date: Date) -> String? {
        var calendar = Calendar.current
        calendar.timeZone = koreaTimeZone

        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)
        let currentTotalMinutes = currentHour * 60 + currentMinute

        for time in times {
            let components = time.split(separator: ":")
            guard components.count == 2,
                  let hour = Int(components[0]),
                  let minute = Int(components[1]) else {
                continue
            }

            let timeTotalMinutes = hour * 60 + minute
            if timeTotalMinutes >= currentTotalMinutes {
                return time
            }
        }

        return nil
    }

    // MARK: - Private Helpers

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = koreaTimeZone
        return formatter.string(from: date)
    }
}
