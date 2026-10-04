import Foundation
import Testing
@testable import JangyuBus

@Suite("홈 운행일 경계")
struct TimetableTimelineViewModelTests {
    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value + "+09:00")!
    }

    @Test @MainActor func 긴배차간격과_다른시간표선택이_홈을바꾸지않음() {
        let model = MainViewModel()
        model.weekdayTimes = ["11:00", "15:00", "19:00"]
        model.weekendTimes = ["12:00", "20:00"]
        model.selectedScheduleType = .weekend
        let snapshot = model.makeTimingSnapshot(at: date("2026-09-18T11:01:00"))
        #expect(snapshot.nextBusTime == "15:00")
        #expect(!snapshot.isServiceEnded)
        #expect(model.nextBusTimeForSelectedSchedule(at: date("2026-09-18T11:01:00")) == nil)
    }

    @Test @MainActor func 자정후_남은시간은_다음날로_넘어가지않음() {
        let model = MainViewModel()
        model.weekdayTimes = ["06:00", "00:10"]
        model.weekendTimes = ["07:00", "23:00"]
        let snapshot = model.makeTimingSnapshot(at: date("2026-09-19T00:05:00"))
        #expect(snapshot.nextBusTime == "00:10")
        #expect(snapshot.nextBusMinuteDisplay == "5")
        #expect(!snapshot.isServiceEnded)
    }
}
