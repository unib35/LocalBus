import Testing
import Foundation
@testable import JangyuBus

@Suite(.serialized)
@MainActor
struct MainViewModelTests {

    // MARK: - 초기 상태 테스트

    @Test func 초기상태_로딩중이다() async {
        // Given & When
        let viewModel = await MainViewModel()

        // Then
        #expect(viewModel.isLoading == true)
    }

    // MARK: - 시간표 로드 테스트

    @Test func 시간표_로드_성공시_데이터가_설정된다() async {
        // Given
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
        let viewModel = await MainViewModel()
        let testData = createTestTimetableData()

        // When
        await viewModel.loadTimetable(with: testData)

        // Then
        #expect(viewModel.weekdayTimes == ["06:00", "06:30", "07:00"])
    }

    @Test func 주말시간표가_올바르게_설정된다() async {
        // Given
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

    // MARK: - Helper

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
