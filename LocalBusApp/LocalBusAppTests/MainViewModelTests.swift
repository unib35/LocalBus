import Testing
import Foundation
@testable import JangyuBus

@Suite(.serialized)
@MainActor
struct MainViewModelTests {

    // MARK: - 초기 상태 테스트

    @Test func 초기상태_로딩중이다() async {
        // Given & When
        TestEnvironment.reset()
        let viewModel = await MainViewModel()

        // Then
        #expect(viewModel.isLoading == true)
    }

    // MARK: - 시간표 로드 테스트

    @Test func 시간표_로드_성공시_데이터가_설정된다() async {
        // Given
        TestEnvironment.reset()
        let viewModel = await MainViewModel()
        let testData = createTestTimetableData()

        // When
        await viewModel.loadTimetable(with: testData)

        // Then
        #expect(viewModel.isLoading == false)
        #expect(viewModel.weekdayTimes.isEmpty == false)
        #expect(viewModel.weekendTimes.isEmpty == false)
    }

    @Test func 평일시간표가_올바르게_설정된다() async {
        // Given
        TestEnvironment.reset()
        let viewModel = await MainViewModel()
        let testData = createTestTimetableData()

        // When
        await viewModel.loadTimetable(with: testData)

        // Then
        #expect(viewModel.weekdayTimes == ["06:00", "06:30", "07:00"])
    }

    @Test func 주말시간표가_올바르게_설정된다() async {
        // Given
        TestEnvironment.reset()
        let viewModel = await MainViewModel()
        let testData = createTestTimetableData()

        // When
        await viewModel.loadTimetable(with: testData)

        // Then
        #expect(viewModel.weekendTimes == ["07:00", "08:00", "09:00"])
    }

    // MARK: - 공지 메시지 테스트

    @Test func 공지메시지가_있으면_표시된다() async {
        // Given
        TestEnvironment.reset()
        let viewModel = await MainViewModel()
        let testData = createTestTimetableData(noticeMessage: "테스트 공지")

        // When
        await viewModel.loadTimetable(with: testData)

        // Then
        #expect(viewModel.noticeMessage == "테스트 공지")
        #expect(viewModel.hasNotice == true)
    }

    @Test func 공지메시지가_없으면_표시안됨() async {
        // Given
        TestEnvironment.reset()
        let viewModel = await MainViewModel()
        let testData = createTestTimetableData(noticeMessage: nil)

        // When
        await viewModel.loadTimetable(with: testData)

        // Then
        #expect(viewModel.noticeMessage == nil)
        #expect(viewModel.hasNotice == false)
    }

    // MARK: - 현재 시간표 선택 테스트

    @Test func 평일_선택시_평일시간표_반환() async {
        // Given
        TestEnvironment.reset()
        let viewModel = await MainViewModel()
        let testData = createTestTimetableData()
        await viewModel.loadTimetable(with: testData)

        // When
        viewModel.selectedScheduleType = .weekday

        // Then
        #expect(viewModel.currentTimes == ["06:00", "06:30", "07:00"])
    }

    @Test func 주말_선택시_주말시간표_반환() async {
        // Given
        TestEnvironment.reset()
        let viewModel = await MainViewModel()
        let testData = createTestTimetableData()
        await viewModel.loadTimetable(with: testData)

        // When
        viewModel.selectedScheduleType = .weekend

        // Then
        #expect(viewModel.currentTimes == ["07:00", "08:00", "09:00"])
    }

    // MARK: - 시간표 컨텍스트 라벨 테스트

    @Test func 평일이면_날짜와_평일시간표_라벨을_반환한다() async {
        // Given
        let viewModel = await MainViewModel()
        await viewModel.loadTimetable(with: createTestTimetableData())
        let tuesday = makeKSTDate(year: 2026, month: 9, day: 22)

        // When
        let text = viewModel.scheduleContextText(at: tuesday)

        // Then
        #expect(text == "9월 22일 화 · 평일 시간표")
    }

    @Test func 평일이라도_공휴일이면_공휴일과_주말시간표_라벨을_반환한다() async {
        // Given
        let viewModel = await MainViewModel()
        await viewModel.loadTimetable(with: createTestTimetableData(holidays: ["2026-09-28"]))
        let holidayMonday = makeKSTDate(year: 2026, month: 9, day: 28)

        // When
        let text = viewModel.scheduleContextText(at: holidayMonday)

        // Then
        #expect(text == "9월 28일 월 · 공휴일 · 주말 시간표")
    }

    @Test func 주말이면_주말시간표_라벨을_반환한다() async {
        // Given
        let viewModel = await MainViewModel()
        await viewModel.loadTimetable(with: createTestTimetableData())
        let saturday = makeKSTDate(year: 2026, month: 9, day: 26)

        // When
        let text = viewModel.scheduleContextText(at: saturday)

        // Then
        #expect(text == "9월 26일 토 · 주말 시간표")
    }

    @Test func 내일_안내는_요일_전체와_시간표_종류를_말한다() async {
        let viewModel = await MainViewModel()
        await viewModel.loadTimetable(with: createTestTimetableData(holidays: ["2026-09-28"]))

        #expect(viewModel.tomorrowContextText(at: makeKSTDate(year: 2026, month: 9, day: 22)) == "내일은 9월 23일 수요일 · 평일 시간표로 운행해요")
        #expect(viewModel.tomorrowContextText(at: makeKSTDate(year: 2026, month: 9, day: 25)) == "내일은 9월 26일 토요일 · 주말 시간표로 운행해요")
        #expect(viewModel.tomorrowContextText(at: makeKSTDate(year: 2026, month: 9, day: 27)) == "내일은 9월 28일 월요일 · 공휴일 · 주말 시간표로 운행해요")
        #expect(viewModel.tomorrowScheduleType(at: makeKSTDate(year: 2026, month: 9, day: 27)) == .weekend)
        #expect(viewModel.tomorrowScheduleType(at: makeKSTDate(year: 2026, month: 9, day: 28)) == .weekday)
    }

    // MARK: - 홈 히어로 상태

    @Test func 운행_간격이_길어도_오늘_버스가_남아_있으면_운행_종료가_아니다() async {
        UserDefaults.standard.removeObject(forKey: "selectedDirection")
        let viewModel = await MainViewModel()
        await viewModel.loadTimetable(with: createTestTimetableData())
        viewModel.selectedScheduleType = .weekend // 07:00, 08:00, 09:00

        let early = viewModel.makeTimingSnapshot(at: makeKSTDate(year: 2026, month: 9, day: 26, hour: 3))
        #expect(early.nextBusTime == "07:00")
        #expect(early.isServiceEnded == false)

        let late = viewModel.makeTimingSnapshot(at: makeKSTDate(year: 2026, month: 9, day: 26, hour: 22))
        #expect(late.nextBusTime == nil)
        #expect(late.isServiceEnded)
        #expect(late.firstBusTime == "07:00")
    }

    @Test func 자동으로_시간표를_받아도_마지막_확인_시각이_갱신된다() async {
        let viewModel = await MainViewModel()
        let checkedAt = Date()
        viewModel.markUpdateChecked(at: checkedAt)
        #expect(viewModel.lastUpdateCheckAt == checkedAt)
        #expect(UserDefaults.standard.object(forKey: "lastUpdateCheckAt") as? Date == checkedAt)
    }

    @Test func 교통값이_만료되면_기본_소요시간을_쓴다() async {
        let viewModel = await MainViewModel()
        let now = Date()
        #expect(viewModel.freshTrafficDuration(minutes: 34, updatedAt: now.addingTimeInterval(-5 * 60), now: now) == 34)
        #expect(viewModel.freshTrafficDuration(minutes: 34, updatedAt: now.addingTimeInterval(-25 * 60), now: now) == nil)
        #expect(viewModel.freshTrafficDuration(minutes: nil, updatedAt: nil, now: now) == nil)
    }

    // MARK: - Helper

    // MARK: - 버스 상세 정보

    @Test func 오늘_시간표의_버스는_출발까지_남은_시간을_갖는다() async {
        let viewModel = await MainViewModel()
        await viewModel.loadTimetable(with: createTestTimetableData())
        let tuesdayMorning = makeKSTDate(year: 2026, month: 9, day: 22, hour: 6)
        viewModel.selectedScheduleType = .weekday

        let info = viewModel.makeBusDetailInfo(for: "06:30", at: tuesdayMorning)

        #expect(info.minutesUntilDeparture == 30)
        #expect(info.isTomorrow == false)
        #expect(info.scheduleTypeLabel == "평일")
    }

    @Test func 오늘이_아닌_요일_시간표의_버스는_남은_시간과_교통_반영이_없다() async {
        let viewModel = await MainViewModel()
        await viewModel.loadTimetable(with: createTestTimetableData())
        let tuesdayMorning = makeKSTDate(year: 2026, month: 9, day: 22, hour: 6)
        viewModel.selectedScheduleType = .weekend
        viewModel.trafficDurationMinutes = 34

        let info = viewModel.makeBusDetailInfo(for: "07:00", at: tuesdayMorning)

        #expect(info.minutesUntilDeparture == nil)
        #expect(info.estimate?.basis == .timetable)
        #expect(info.untilText == nil)
        #expect(info.scheduleTypeLabel == "주말 · 공휴일")
    }

    @Test func 내일_버스_상세는_내일_표시와_시간표_기준을_갖는다() async {
        let viewModel = await MainViewModel()
        await viewModel.loadTimetable(with: createTestTimetableData())
        let tuesdayNight = makeKSTDate(year: 2026, month: 9, day: 22, hour: 23)
        viewModel.selectedScheduleType = .weekday
        viewModel.trafficDurationMinutes = 34

        let info = viewModel.makeBusDetailInfo(for: "06:00", isTomorrow: true, at: tuesdayNight)

        #expect(info.isTomorrow == true)
        #expect(info.minutesUntilDeparture == nil)
        #expect(info.estimate?.basis == .timetable)
        #expect(info.untilText == "내일 06:00 출발")
        #expect(info.durationMinutes == info.estimate?.durationMinutes)
    }

    private func makeKSTDate(year: Int, month: Int, day: Int, hour: Int = 9) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func createTestTimetableData(
        noticeMessage: String? = nil,
        holidays: [String] = ["2026-02-09"]
    ) -> TimetableData {
        return TimetableData(
            meta: Meta(
                version: 1,
                updatedAt: "2026-01-14",
                noticeMessage: noticeMessage,
                contactEmail: "test@test.com"
            ),
            holidays: holidays,
            timetable: Timetable(
                weekday: ["06:00", "06:30", "07:00"],
                weekend: ["07:00", "08:00", "09:00"]
            )
        )
    }
}
