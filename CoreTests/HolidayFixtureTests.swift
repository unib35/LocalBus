import Foundation
import Testing
@testable import JangyuBus

@Suite("배포 공휴일 데이터")
struct HolidayFixtureTests {
    private func data() throws -> TimetableData {
        let url = try #require(Bundle.module.url(forResource: "timetable", withExtension: "json"))
        return try JSONDecoder().decode(TimetableData.self, from: Data(contentsOf: url))
    }
    private func date(_ value: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: value + "+09:00"))
    }
    @Test func 공휴일46일_중복없이_양쪽계산에반영() throws {
        let document = try data()
        #expect(document.holidays.count == 46)
        #expect(document.holidays == Array(Set(document.holidays)).sorted())
        for day in document.holidays {
            let day = try date(day + "T12:00:00")
            #expect(!DateService.shouldUseWeekdaySchedule(day, holidays: document.holidays))
            #expect(TimetableTimeline.times(on: day, weekday: ["평일"], weekend: ["휴일"], holidays: document.holidays) == ["휴일"])
        }
    }
    @Test func 잘못된공휴일과_일반평일은_평일시간표() throws {
        let document = try data()
        for value in ["2026-02-09", "2026-02-10", "2026-02-11", "2026-09-28", "2026-09-29", "2026-09-30", "2027-01-04", "2027-06-07", "2027-09-17", "2027-12-28"] {
            let day = try date(value + "T12:00:00")
            #expect(DateService.shouldUseWeekdaySchedule(day, holidays: document.holidays))
            #expect(TimetableTimeline.times(on: day, weekday: ["평일"], weekend: ["휴일"], holidays: document.holidays) == ["평일"])
        }
    }
    @Test func 새해첫차는_새해공휴일시간표() throws {
        let document = try data()
        let next = try #require(TimetableTimeline.departures(weekday: ["06:00", "22:00"], weekend: ["07:00", "21:00"], holidays: document.holidays, from: date("2026-12-31T23:00:00")).first)
        #expect(next.date == (try date("2027-01-01T07:00:00")))
    }
    @Test func 데이터버전은_최신순서로비교() throws {
        let revision = try data().meta.revision
        #expect(TimetableRevision(version: 3, updatedAt: "2026-03-08") < revision)
        #expect(TimetableRevision(version: 99, updatedAt: "2026-12-01") > revision)
    }
}
