import Testing
import Foundation
@testable import LocalBusApp

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

    // MARK: - Helper

    private func createTestTimetableData(noticeMessage: String? = nil) -> TimetableData {
        return TimetableData(
            meta: Meta(
                version: 1,
                updatedAt: "2026-01-14",
                noticeMessage: noticeMessage,
                contactEmail: "test@test.com"
            ),
            holidays: ["2026-02-09"],
            timetable: Timetable(
                weekday: ["06:00", "06:30", "07:00"],
                weekend: ["07:00", "08:00", "09:00"]
            )
        )
    }
}
