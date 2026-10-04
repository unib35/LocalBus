import Foundation
import Testing
@testable import JangyuBus

@Suite("공휴일 데이터와 캐시 갱신")
struct HolidayDataTests {
    @Test func 수정된공휴일과_대체공휴일_포함() throws {
        let data = try #require(TimetableService().loadLocalData())
        for date in ["2026-02-16", "2026-02-17", "2026-02-18", "2026-03-02",
                     "2026-05-01", "2026-05-24", "2026-05-25", "2026-06-03", "2026-07-17",
                     "2026-08-17", "2026-09-24", "2026-09-25", "2026-09-26", "2026-10-05"] {
            #expect(data.holidays.contains(date))
        }
        for date in ["2026-02-09", "2026-02-10", "2026-02-11", "2026-09-28", "2026-09-29", "2026-09-30"] {
            #expect(!data.holidays.contains(date))
        }
        #expect(Set(data.holidays).count == data.holidays.count)
    }

    @Test func 이천이십칠년공휴일과_연말전환() throws {
        let data = try #require(TimetableService().loadLocalData())
        let dates = ["01-01", "02-06", "02-07", "02-08", "02-09", "03-01",
                     "05-01", "05-03", "05-05", "05-13", "06-06", "07-17", "07-19",
                     "08-15", "08-16", "09-14", "09-15", "09-16", "10-03", "10-04",
                     "10-09", "10-11", "12-25", "12-27"].map { "2027-" + $0 }
        #expect(data.holidays.filter { $0.hasPrefix("2027-") } == dates)
        let parser = ISO8601DateFormatter()
        for holiday in dates {
            let date = try #require(parser.date(from: holiday + "T12:00:00+09:00"))
            #expect(!DateService.shouldUseWeekdaySchedule(date, holidays: data.holidays))
            #expect(TimetableTimeline.times(on: date, weekday: ["평일"], weekend: ["휴일"], holidays: data.holidays) == ["휴일"])
        }
        let now = try #require(parser.date(from: "2026-12-31T23:00:00+09:00"))
        let next = try #require(TimetableTimeline.departures(weekday: ["06:00", "22:00"], weekend: ["07:00", "21:00"], holidays: data.holidays, from: now).first)
        #expect(next.date == parser.date(from: "2027-01-01T07:00:00+09:00"))
    }

    @Test func 오래된캐시는_번들수정본으로_교체() throws {
        let suite = "holiday-cache-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = TimetableService(defaults: defaults)
        let bundled = try #require(service.loadLocalData())
        let old = TimetableData(meta: Meta(version: 3, updatedAt: "2026-03-08", noticeMessage: nil, contactEmail: "test@example.com"),
                                holidays: ["2026-09-28"], timetable: bundled.timetable, routes: bundled.routes)
        service.saveToCache(old)
        #expect(service.loadInitialData()?.meta.revision == bundled.meta.revision)
        #expect(service.loadCachedData()?.holidays == bundled.holidays)
    }

    @Test func 더최신캐시는_번들로_덮어쓰지않음() throws {
        let suite = "holiday-newer-cache-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = TimetableService(defaults: defaults)
        let bundled = try #require(service.loadLocalData())
        let newer = TimetableData(meta: Meta(version: 99, updatedAt: "2026-12-01", noticeMessage: nil, contactEmail: "test@example.com"),
                                  holidays: ["2026-12-25"], timetable: bundled.timetable, routes: bundled.routes)
        service.saveToCache(newer)
        #expect(service.loadInitialData()?.meta.version == 99)
        #expect(service.loadCachedData()?.meta.version == 99)
    }
}
