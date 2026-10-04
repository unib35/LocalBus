import Foundation
import Testing
@testable import JangyuBus

@Suite("운행일 경계 계산")
struct TimetableTimelineTests {
    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value + "+09:00")!
    }

    @Test func 자정전_익일0010막차를_유지() {
        let now = date("2026-09-18T23:50:00")
        let next = TimetableTimeline.departures(weekday: ["06:00", "23:30", "00:10"], weekend: ["07:00", "22:30", "00:10"], holidays: [], from: now).first!
        #expect(next.time == "00:10")
        #expect(next.date == date("2026-09-19T00:10:00"))
        #expect(next.serviceDate == date("2026-09-18T00:00:00"))
        #expect(next.isLast)
    }

    @Test func 토요일자정_전날평일막차를_찾음() {
        let next = TimetableTimeline.departures(weekday: ["06:00", "00:10"], weekend: ["07:00", "23:00"], holidays: [], from: date("2026-09-19T00:05:00")).first!
        #expect(next.time == "00:10")
        #expect(next.serviceDate == date("2026-09-18T00:00:00"))
    }

    @Test func 금요일막차후_토요일첫차_사용() {
        let next = TimetableTimeline.departures(weekday: ["06:00", "22:00"], weekend: ["07:00", "21:00"], holidays: [], from: date("2026-09-18T23:00:00")).first!
        #expect(next.date == date("2026-09-19T07:00:00"))
    }

    @Test func 일요일막차후_월요일공휴일시간표_사용() {
        let next = TimetableTimeline.departures(weekday: ["06:00", "22:00"], weekend: ["07:00", "21:00"], holidays: ["2026-09-21"], from: date("2026-09-20T23:00:00")).first!
        #expect(next.date == date("2026-09-21T07:00:00"))
    }

}
