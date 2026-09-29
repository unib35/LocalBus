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

    @Test func 기본_목표는_한시간_뒤를_십분_단위로_올린다() {
        #expect(ArrivalPlanner.defaultTargetMinutes(nowMinutes: 7 * 60 + 41) == 8 * 60 + 50)
        #expect(ArrivalPlanner.defaultTargetMinutes(nowMinutes: 7 * 60 + 50) == 8 * 60 + 50)
    }

    @Test func 현재_분이_51분_이상이면_다음_정시로_올린다() {
        #expect(ArrivalPlanner.defaultTargetMinutes(nowMinutes: 7 * 60 + 51) == 9 * 60)
        #expect(ArrivalPlanner.defaultTargetMinutes(nowMinutes: 7 * 60 + 59) == 9 * 60)
    }

    @Test func 기본_목표는_새벽_다섯시부터_밤_열한시_오십분_사이다() {
        #expect(ArrivalPlanner.defaultTargetMinutes(nowMinutes: 3 * 60) == 5 * 60)
        #expect(ArrivalPlanner.defaultTargetMinutes(nowMinutes: 22 * 60 + 55) == 23 * 60 + 50)
        // 자정을 넘기면 다음 날 새벽 첫 범위로
        #expect(ArrivalPlanner.defaultTargetMinutes(nowMinutes: 23 * 60 + 30) == 5 * 60)
    }

    @Test func 목표_시각은_범위를_벗어나지_않는다() {
        #expect(ArrivalPlanner.clampedTarget(minutes: 200) == 300)
        #expect(ArrivalPlanner.clampedTarget(minutes: 1439) == 1430)
        #expect(ArrivalPlanner.shiftedTarget(minutes: 510, by: -10) == 500)
        #expect(ArrivalPlanner.shiftedTarget(minutes: 300, by: -10) == 300)
        #expect(ArrivalPlanner.shiftedTarget(minutes: 1430, by: 10) == 1430)
    }

    @Test func 시간_표기() {
        #expect(ArrivalPlanner.spanText(14) == "14분")
        #expect(ArrivalPlanner.spanText(60) == "1시간")
        #expect(ArrivalPlanner.spanText(72) == "1시간 12분")
    }
}
