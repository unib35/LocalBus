import Foundation
import SwiftUI

/// 시간표 타입 (평일/주말)
enum ScheduleType: String, CaseIterable {
    case weekday = "평일"
    case weekend = "주말"
}

/// 메인 화면 ViewModel
@MainActor
final class MainViewModel: ObservableObject {

    // MARK: - Published Properties

    /// 로딩 상태
    @Published var isLoading: Bool = true

    /// 평일 시간표
    @Published var weekdayTimes: [String] = []

    /// 주말 시간표
    @Published var weekendTimes: [String] = []

    /// 공휴일 목록
    @Published var holidays: [String] = []

    /// 공지 메시지
    @Published var noticeMessage: String?

    /// 선택된 시간표 타입
    @Published var selectedScheduleType: ScheduleType = .weekday

    /// 에러 메시지
    @Published var errorMessage: String?

    /// 오프라인 모드 여부
    @Published var isOffline: Bool = false

    // MARK: - Constants

    private let remoteURL = URL(string: "https://raw.githubusercontent.com/JongMini/LocalBus-Data/main/timetable.json")

    // MARK: - Computed Properties

    /// 공지가 있는지 여부
    var hasNotice: Bool {
        noticeMessage != nil && !noticeMessage!.isEmpty
    }

    /// 현재 선택된 시간표
    var currentTimes: [String] {
        switch selectedScheduleType {
        case .weekday:
            return weekdayTimes
        case .weekend:
            return weekendTimes
        }
    }

    /// 다음 버스 시간
    var nextBusTime: String? {
        DateService.findNextBus(times: currentTimes, from: Date())
    }

    /// 운행 종료 여부
    var isServiceEnded: Bool {
        nextBusTime == nil && !currentTimes.isEmpty
    }

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// 시간표 데이터 로드
    func loadTimetable(with data: TimetableData) async {
        weekdayTimes = data.timetable.weekday
        weekendTimes = data.timetable.weekend
        holidays = data.holidays
        noticeMessage = data.meta.noticeMessage

        // 오늘 날짜에 맞는 시간표 타입 자동 선택
        let shouldUseWeekday = DateService.shouldUseWeekdaySchedule(Date(), holidays: holidays)
        selectedScheduleType = shouldUseWeekday ? .weekday : .weekend

        isLoading = false
    }

    /// 앱 시작 시 데이터 로드
    func onAppear() async {
        let timetableService = TimetableService()
        let networkService = NetworkService()

        // 1. 원격 데이터 fetch 시도
        if let url = remoteURL {
            do {
                let remoteData: TimetableData = try await networkService.fetch(from: url)
                timetableService.saveToCache(remoteData)
                await loadTimetable(with: remoteData)
                isOffline = false
                return
            } catch {
                // 네트워크 실패 - 오프라인 모드로 전환
                isOffline = true
            }
        }

        // 2. 캐시된 데이터 시도
        if let cached = timetableService.loadCachedData() {
            await loadTimetable(with: cached)
            return
        }

        // 3. 로컬 번들 데이터 사용
        if let local = timetableService.loadLocalData() {
            await loadTimetable(with: local)
            return
        }

        // 4. 데이터 없음
        isLoading = false
        errorMessage = "시간표를 불러올 수 없습니다."
    }

    /// 데이터 새로고침
    func refresh() async {
        isLoading = true
        await onAppear()
    }
}
