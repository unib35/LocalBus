import Testing
import Foundation
@testable import JangyuBus

struct LiveActivityTimingTests {

    private func kst(_ hour: Int, _ minute: Int, day: Int = 29) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = day
        components.hour = hour
        components.minute = minute
        return LiveActivityTiming.koreaCalendar.date(from: components)!
    }

    @Test func 시각만으로_단계를_정한다() {
        let departure = kst(18, 30)
        let arrival = kst(19, 4)
        #expect(LiveActivityTiming.stage(now: kst(18, 12), departure: departure, arrival: arrival) == .waiting)
        #expect(LiveActivityTiming.stage(now: kst(18, 25), departure: departure, arrival: arrival) == .departingSoon)
        #expect(LiveActivityTiming.stage(now: kst(18, 30), departure: departure, arrival: arrival) == .inTransit)
        #expect(LiveActivityTiming.stage(now: kst(19, 4), departure: departure, arrival: arrival) == .finished)
    }

    @Test func 다음_전환_시각() {
        let departure = kst(18, 30)
        let arrival = kst(19, 4)
        #expect(LiveActivityTiming.nextTransition(after: kst(18, 12), departure: departure, arrival: arrival) == kst(18, 25))
        #expect(LiveActivityTiming.nextTransition(after: kst(18, 27), departure: departure, arrival: arrival) == departure)
        #expect(LiveActivityTiming.nextTransition(after: kst(18, 40), departure: departure, arrival: arrival) == arrival)
        #expect(LiveActivityTiming.nextTransition(after: kst(19, 10), departure: departure, arrival: arrival) == nil)
    }

    @Test func 출발_전에는_출발_시각에_낡고_출발_뒤에는_도착_시각에_낡는다() {
        let departure = kst(18, 30)
        let arrival = kst(19, 4)
        #expect(LiveActivityTiming.staleDate(now: kst(18, 12), departure: departure, arrival: arrival) == departure)
        #expect(LiveActivityTiming.staleDate(now: kst(18, 27), departure: departure, arrival: arrival) == departure)
        #expect(LiveActivityTiming.staleDate(now: kst(18, 40), departure: departure, arrival: arrival) == arrival)
    }

    @Test func 출발_20분_전부터_출발_전까지만_시작한다() {
        let departure = kst(18, 30)
        #expect(LiveActivityTiming.shouldStart(now: kst(18, 9), departure: departure) == false)
        #expect(LiveActivityTiming.shouldStart(now: kst(18, 10), departure: departure))
        #expect(LiveActivityTiming.shouldStart(now: kst(18, 29), departure: departure))
        #expect(LiveActivityTiming.shouldStart(now: kst(18, 30), departure: departure) == false)
    }

    @Test func 자정을_넘긴_버스는_내일_날짜로_잡는다() {
        #expect(LiveActivityTiming.departureDate(for: "00:10", now: kst(23, 55)) == kst(0, 10, day: 30))
        #expect(LiveActivityTiming.departureDate(for: "00:10", now: kst(0, 5, day: 30)) == kst(0, 10, day: 30))
        #expect(LiveActivityTiming.departureDate(for: "18:30", now: kst(18, 12)) == kst(18, 30))
        // 방금 지난 버스를 내일 버스로 착각하지 않는다
        #expect(LiveActivityTiming.departureDate(for: "18:30", now: kst(18, 40)) == kst(18, 30))
        #expect(LiveActivityTiming.departureDate(for: "엉뚱한 값", now: kst(18, 40)) == nil)
    }
}
