import Testing
import Foundation
@testable import LocalBusApp

struct DateServiceTests {

    // MARK: - isWeekday 테스트

    @Test func 월요일은_평일이다() {
        // Given: 2026년 1월 12일 (월요일)
        let monday = createDate(year: 2026, month: 1, day: 12)

        // When & Then
        #expect(DateService.isWeekday(monday) == true)
    }

    @Test func 금요일은_평일이다() {
        // Given: 2026년 1월 16일 (금요일)
        let friday = createDate(year: 2026, month: 1, day: 16)

        // When & Then
        #expect(DateService.isWeekday(friday) == true)
    }

    @Test func 토요일은_평일이_아니다() {
        // Given: 2026년 1월 17일 (토요일)
        let saturday = createDate(year: 2026, month: 1, day: 17)

        // When & Then
        #expect(DateService.isWeekday(saturday) == false)
    }

    @Test func 일요일은_평일이_아니다() {
        // Given: 2026년 1월 18일 (일요일)
        let sunday = createDate(year: 2026, month: 1, day: 18)

        // When & Then
        #expect(DateService.isWeekday(sunday) == false)
    }

    // MARK: - isHoliday 테스트

    @Test func 공휴일_목록에_있으면_true() {
        // Given
        let holidays = ["2026-01-01", "2026-02-09", "2026-02-10"]
        let date = createDate(year: 2026, month: 2, day: 9)

        // When & Then
        #expect(DateService.isHoliday(date, holidays: holidays) == true)
    }

    @Test func 공휴일_목록에_없으면_false() {
        // Given
        let holidays = ["2026-01-01", "2026-02-09"]
        let date = createDate(year: 2026, month: 1, day: 12)

        // When & Then
        #expect(DateService.isHoliday(date, holidays: holidays) == false)
    }

    // MARK: - shouldUseWeekdaySchedule 테스트

    @Test func 평일이고_공휴일이_아니면_평일시간표_사용() {
        // Given: 2026년 1월 12일 (월요일, 공휴일 아님)
        let monday = createDate(year: 2026, month: 1, day: 12)
        let holidays: [String] = []

        // When & Then
        #expect(DateService.shouldUseWeekdaySchedule(monday, holidays: holidays) == true)
    }

    @Test func 평일이지만_공휴일이면_주말시간표_사용() {
        // Given: 2026년 2월 9일 (월요일, 설날)
        let holiday = createDate(year: 2026, month: 2, day: 9)
        let holidays = ["2026-02-09"]

        // When & Then
        #expect(DateService.shouldUseWeekdaySchedule(holiday, holidays: holidays) == false)
    }

    @Test func 주말이면_주말시간표_사용() {
        // Given: 2026년 1월 17일 (토요일)
        let saturday = createDate(year: 2026, month: 1, day: 17)
        let holidays: [String] = []

        // When & Then
        #expect(DateService.shouldUseWeekdaySchedule(saturday, holidays: holidays) == false)
    }

    // MARK: - findNextBus 테스트

    @Test func 다음_버스_시간_반환() {
        // Given
        let times = ["06:00", "06:30", "07:00", "07:30"]
        let currentTime = createTime(hour: 6, minute: 15)

        // When
        let nextBus = DateService.findNextBus(times: times, from: currentTime)

        // Then
        #expect(nextBus == "06:30")
    }

    @Test func 정각에_해당_버스_반환() {
        // Given
        let times = ["06:00", "06:30", "07:00"]
        let currentTime = createTime(hour: 6, minute: 30)

        // When
        let nextBus = DateService.findNextBus(times: times, from: currentTime)

        // Then
        #expect(nextBus == "06:30")
    }

    @Test func 막차_이후_nil_반환() {
        // Given
        let times = ["06:00", "06:30", "07:00"]
        let currentTime = createTime(hour: 23, minute: 0)

        // When
        let nextBus = DateService.findNextBus(times: times, from: currentTime)

        // Then
        #expect(nextBus == nil)
    }

    @Test func 첫차_전_첫차_반환() {
        // Given
        let times = ["06:00", "06:30", "07:00"]
        let currentTime = createTime(hour: 5, minute: 30)

        // When
        let nextBus = DateService.findNextBus(times: times, from: currentTime)

        // Then
        #expect(nextBus == "06:00")
    }

    // MARK: - Helper

    private func createDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        return Calendar.current.date(from: components)!
    }

    private func createTime(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 14
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        return Calendar.current.date(from: components)!
    }
}
