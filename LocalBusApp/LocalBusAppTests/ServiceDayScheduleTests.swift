import Testing
import Foundation
@testable import JangyuBus

/// 시간표 끝에 자정을 넘긴 시각(사상 → 장유 막차 00:10)이 있을 때의 운행일 계산
struct ServiceDayScheduleTests {

    private let overnight = ["06:00", "07:00", "23:00", "23:30", "00:10"]
    private let daytime = ["06:00", "07:00", "23:00", "23:30"]

    @Test func 자정을_넘긴_시각은_같은_운행일의_24시_이후로_센다() {
        #expect(ServiceDaySchedule.serviceMinutes(of: overnight) == [360, 420, 1380, 1410, 1450])
        #expect(ServiceDaySchedule.serviceMinutes(of: daytime) == [360, 420, 1380, 1410])
    }

    @Test func 낮에는_자정_넘긴_막차까지_남은_시간이_양수다() {
        let schedule = ServiceDaySchedule.resolve(todayTimes: overnight, yesterdayTimes: overnight, clockMinutes: 8 * 60)
        #expect(schedule.isOvernightTail == false)
        #expect(schedule.nextIndex == 2)
        #expect(schedule.minutesUntilLast == 1450 - 480)
        #expect(schedule.isPast("06:00"))
        #expect(schedule.isPast("00:10") == false)
    }

    @Test func 밤_23시_50분에는_다음_버스가_00시_10분이다() {
        let schedule = ServiceDaySchedule.resolve(todayTimes: overnight, yesterdayTimes: overnight, clockMinutes: 23 * 60 + 50)
        #expect(schedule.nextIndex == 4)
        #expect(schedule.minutesUntil(index: 4) == 20)
        #expect(schedule.minutesUntilLast == 20)
    }

    @Test func 자정_직후에는_전날_막차가_아직_남아_있다() {
        let today = ["06:30", "09:00", "00:10"]
        let schedule = ServiceDaySchedule.resolve(todayTimes: today, yesterdayTimes: overnight, clockMinutes: 5)
        #expect(schedule.isOvernightTail)
        #expect(schedule.times == overnight)
        #expect(schedule.nextIndex == 4)
        #expect(schedule.minutesUntil(index: 4) == 5)
        #expect(schedule.isPast("23:30"))
    }

    @Test func 전날_막차가_떠나면_오늘_첫차를_본다() {
        let schedule = ServiceDaySchedule.resolve(todayTimes: overnight, yesterdayTimes: overnight, clockMinutes: 11)
        #expect(schedule.isOvernightTail == false)
        #expect(schedule.nextIndex == 0)
        #expect(schedule.minutesUntil(index: 0) == 349)
    }

    @Test func 자정을_넘는_시각이_없으면_막차_뒤에는_운행_종료다() {
        let late = ServiceDaySchedule.resolve(todayTimes: daytime, yesterdayTimes: daytime, clockMinutes: 23 * 60 + 40)
        #expect(late.nextIndex == nil)
        #expect(late.minutesUntilLast == 0)

        let afterMidnight = ServiceDaySchedule.resolve(todayTimes: daytime, yesterdayTimes: daytime, clockMinutes: 5)
        #expect(afterMidnight.isOvernightTail == false)
        #expect(afterMidnight.nextIndex == 0)
    }

    @Test func 도착_목표는_자정_넘긴_버스를_아침_버스로_착각하지_않는다() {
        let times = ["06:00", "07:00", "08:10", "23:30", "00:10"]
        #expect(ServiceDaySchedule.lastIndex(arrivingBy: "08:30", times: times, durationMinutes: 31) == 1)
        #expect(ServiceDaySchedule.lastIndex(arrivingBy: "06:10", times: times, durationMinutes: 31) == nil)
        // 자정 넘은 목표 시각은 밤 버스까지 포함한다
        #expect(ServiceDaySchedule.lastIndex(arrivingBy: "00:45", times: times, durationMinutes: 31) == 4)
    }

    @Test func 읽을_수_없는_시각은_건너뛴다() {
        let schedule = ServiceDaySchedule.resolve(todayTimes: ["06:00", "??", "07:00"], yesterdayTimes: [], clockMinutes: 6 * 60 + 30)
        #expect(schedule.times == ["06:00", "07:00"])
        #expect(schedule.nextIndex == 1)
    }
}
