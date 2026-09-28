import Testing
import Foundation
@testable import JangyuBus

struct ArrivalPlannerTests {

    private let times = ["06:20", "06:40", "07:00", "07:20", "07:35", "07:50", "08:05", "08:20"]

    @Test func 목표시각까지_도착하는_마지막_버스를_고른다() {
        let plan = ArrivalPlanner.plan(times: times, durationMinutes: 26, arriveBy: "08:30")
        #expect(plan.best == "07:50")          // 07:50 + 26 = 08:16 ≤ 08:30
        #expect(plan.earlier == "07:35")
        #expect(plan.later == "08:05")         // 08:05 + 26 = 08:31 > 08:30
        #expect(plan.slackMinutes == 14)
        #expect(plan.lateMinutes == 1)
        #expect(plan.arrival(of: "07:50") == "08:16")
    }

    @Test func 딱_맞게_도착하는_버스도_포함한다() {
        let plan = ArrivalPlanner.plan(times: times, durationMinutes: 26, arriveBy: "08:16")
        #expect(plan.best == "07:50")
        #expect(plan.slackMinutes == 0)
    }

    @Test func 그_시각까지_도착하는_버스가_없으면_첫차를_다음으로_안내한다() {
        let plan = ArrivalPlanner.plan(times: times, durationMinutes: 26, arriveBy: "06:30")
        #expect(plan.best == nil)
        #expect(plan.earlier == nil)
        #expect(plan.later == "06:20")
        #expect(plan.slackMinutes == nil)
    }

    @Test func 첫차가_최선이면_한대앞은_없다() {
        let plan = ArrivalPlanner.plan(times: times, durationMinutes: 26, arriveBy: "06:50")
        #expect(plan.best == "06:20")
        #expect(plan.earlier == nil)
        #expect(plan.later == "06:40")
    }

    @Test func 시간_표기() {
        #expect(ArrivalPlanner.spanText(14) == "14분")
        #expect(ArrivalPlanner.spanText(60) == "1시간")
        #expect(ArrivalPlanner.spanText(72) == "1시간 12분")
    }
}
