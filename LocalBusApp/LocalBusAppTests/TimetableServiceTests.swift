import Testing
import Foundation
@testable import LocalBusApp

struct TimetableServiceTests {

    // MARK: - loadLocalData 테스트

    @Test func 번들_JSON_로드_성공() {
        // Given
        let service = TimetableService()

        // When
        let result = service.loadLocalData()

        // Then
        #expect(result != nil)
        #expect(result?.meta.version == 1)
        #expect(result?.timetable.weekday.isEmpty == false)
        #expect(result?.timetable.weekend.isEmpty == false)
    }

    @Test func 번들_JSON이_없으면_nil_반환() {
        // Given
        let service = TimetableService(bundleFileName: "NonExistent")

        // When
        let result = service.loadLocalData()

        // Then
        #expect(result == nil)
    }

    // MARK: - saveToCache & loadCachedData 테스트

    @Test func 캐시_저장_후_로드_성공() {
        // Given
        let cacheKey = "test_cache_save_load"
        let service = TimetableService(cacheKey: cacheKey)
        let testData = createTestTimetableData()
        clearCache(key: cacheKey)

        // When
        service.saveToCache(testData)
        let loaded = service.loadCachedData()

        // Then
        #expect(loaded != nil)
        #expect(loaded?.meta.version == testData.meta.version)
        #expect(loaded?.holidays == testData.holidays)
        #expect(loaded?.timetable.weekday == testData.timetable.weekday)
        #expect(loaded?.timetable.weekend == testData.timetable.weekend)

        // Cleanup
        clearCache(key: cacheKey)
    }

    @Test func 캐시가_없으면_nil_반환() {
        // Given
        let cacheKey = "test_cache_nil"
        let service = TimetableService(cacheKey: cacheKey)
        clearCache(key: cacheKey)

        // When
        let result = service.loadCachedData()

        // Then
        #expect(result == nil)
    }

    // MARK: - getCurrentTimetable 테스트

    @Test func 평일_공휴일아님_평일시간표_반환() {
        // Given
        let service = TimetableService()
        let testData = createTestTimetableData()
        let weekday = createDate(year: 2026, month: 1, day: 14) // 수요일

        // When
        let result = service.getCurrentTimetable(for: weekday, data: testData)

        // Then
        #expect(result == testData.timetable.weekday)
    }

    @Test func 평일_공휴일_주말시간표_반환() {
        // Given
        let service = TimetableService()
        let testData = createTestTimetableData()
        let holiday = createDate(year: 2026, month: 2, day: 9) // 월요일이지만 공휴일

        // When
        let result = service.getCurrentTimetable(for: holiday, data: testData)

        // Then
        #expect(result == testData.timetable.weekend)
    }

    @Test func 토요일_주말시간표_반환() {
        // Given
        let service = TimetableService()
        let testData = createTestTimetableData()
        let saturday = createDate(year: 2026, month: 1, day: 17)

        // When
        let result = service.getCurrentTimetable(for: saturday, data: testData)

        // Then
        #expect(result == testData.timetable.weekend)
    }

    @Test func 일요일_주말시간표_반환() {
        // Given
        let service = TimetableService()
        let testData = createTestTimetableData()
        let sunday = createDate(year: 2026, month: 1, day: 18)

        // When
        let result = service.getCurrentTimetable(for: sunday, data: testData)

        // Then
        #expect(result == testData.timetable.weekend)
    }

    // MARK: - Helper Methods

    private func createTestTimetableData() -> TimetableData {
        let meta = Meta(
            version: 1,
            updatedAt: "2026-01-10",
            noticeMessage: "테스트 메시지",
            contactEmail: "test@localbus.com"
        )

        let holidays = ["2026-02-09", "2026-02-10", "2026-02-11"]

        let timetable = Timetable(
            weekday: ["06:00", "06:30", "07:00", "07:30"],
            weekend: ["07:00", "07:30", "08:00", "08:30"]
        )

        return TimetableData(meta: meta, holidays: holidays, timetable: timetable)
    }

    private func createDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        return Calendar.current.date(from: components)!
    }

    private func clearCache(key: String = "cached_timetable_data") {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
