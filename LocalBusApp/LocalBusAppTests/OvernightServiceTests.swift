import Testing
import Foundation
@testable import JangyuBus

/// 시간표 끝에 자정을 넘긴 막차(예: 사상 → 장유 00:10)가 있을 때의 홈·상세 계산
@Suite(.serialized)
@MainActor
struct OvernightServiceTests {

    @Test func 자정_전에는_자정_넘는_막차가_다음_버스다() async {
        let viewModel = await makeViewModel()
        let snapshot = viewModel.makeTimingSnapshot(at: kst(9, 29, 23, 50))

        #expect(snapshot.nextBusTime == "00:10")
        #expect(snapshot.isServiceEnded == false)
        #expect(snapshot.minutesUntilNextBus == 20)
    }

    @Test func 자정_직후에도_전날_막차가_남아_있으면_다음_버스다() async {
        let viewModel = await makeViewModel()
        let snapshot = viewModel.makeTimingSnapshot(at: kst(9, 30, 0, 5))

        #expect(snapshot.nextBusTime == "00:10")
        #expect(snapshot.minutesUntilNextBus == 5)
    }

    @Test func 막차가_지나면_오늘_첫차가_다음_버스다() async {
        let viewModel = await makeViewModel()
        let snapshot = viewModel.makeTimingSnapshot(at: kst(9, 30, 0, 15))

        #expect(snapshot.nextBusTime == "06:00")
        #expect(snapshot.minutesUntilNextBus == 345)
    }

    @Test func 낮에는_자정_넘는_막차가_오늘_남은_버스로_이어진다() async {
        let viewModel = await makeViewModel()
        let snapshot = viewModel.makeTimingSnapshot(at: kst(9, 29, 10, 0))

        #expect(snapshot.nextBusTime == "23:40")
        let overnight = snapshot.upcomingBuses.first { $0.departureTime == "00:10" }
        #expect(overnight != nil)
        #expect(overnight?.statusKind != .nextDay)
    }

    @Test func 자정_직후_이어지는_버스는_같은_날_첫차까지_남은_시간을_쓴다() async {
        let viewModel = await makeViewModel()
        let buses = viewModel.buildUpcomingBuses(limit: 3, at: kst(9, 30, 0, 5))

        #expect(buses.map(\.departureTime) == ["00:10", "06:00", "23:40"])
        #expect(viewModel.minutesUntilDeparture(of: "06:00", isNextDay: true, at: kst(9, 30, 0, 5)) == 355)
    }

    @Test func 자정_넘는_막차의_상세는_남은_시간이_양수다() async {
        let viewModel = await makeViewModel()
        let info = viewModel.makeBusDetailInfo(for: "00:10", at: kst(9, 29, 23, 50))

        #expect(info.minutesUntilDeparture == 20)
    }

    // MARK: - Helpers

    private func makeViewModel() async -> MainViewModel {
        UserDefaults.standard.removeObject(forKey: "selectedDirection")
        let viewModel = await MainViewModel()
        await viewModel.loadTimetable(with: TimetableData(
            meta: Meta(version: 1, updatedAt: "2026-01-14", noticeMessage: nil, contactEmail: "test@test.com"),
            holidays: [],
            timetable: Timetable(
                weekday: ["06:00", "23:40", "00:10"],
                weekend: ["06:00", "23:40", "00:10"]
            )
        ))
        viewModel.selectedScheduleType = .weekday
        return viewModel
    }

    /// 2026년 9월 29일은 화요일, 30일은 수요일
    private func kst(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }
}
