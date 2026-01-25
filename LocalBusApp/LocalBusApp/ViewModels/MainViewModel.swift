import Foundation
import SwiftUI

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

    /// 선택된 노선 방향
    @Published var selectedDirection: RouteDirection = .jangyuToSasang

    /// 에러 메시지
    @Published var errorMessage: String?

    /// 오프라인 모드 여부
    @Published var isOffline: Bool = false

    /// 현재 시간 (1초마다 업데이트)
    @Published var currentTime: Date = Date()

    /// 알림 예약 상태
    @Published var scheduledNotifications: Set<String> = []

    // MARK: - Private Properties

    /// 전체 시간표 데이터 (routes 포함)
    private var timetableData: TimetableData?

    /// 실시간 타이머
    private var timer: Timer?

    // MARK: - Constants

    private let remoteURL = URL(string: "https://raw.githubusercontent.com/JongMini/LocalBus-Data/main/timetable.json")

    // MARK: - Computed Properties

    /// 공지가 있는지 여부
    var hasNotice: Bool {
        noticeMessage != nil && !noticeMessage!.isEmpty
    }

    /// routes 데이터가 있는지 여부 (양방향 지원)
    var hasRoutes: Bool {
        timetableData?.routes != nil
    }

    /// 현재 선택된 방향의 정류장 목록
    var currentStops: [BusStop] {
        guard let data = timetableData else { return [] }
        return TimetableService().getStops(for: selectedDirection, data: data)
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

    /// 현재 방향의 표시 이름
    var currentDirectionName: String {
        selectedDirection.displayName
    }

    /// 다음 버스까지 남은 시간 (분)
    var minutesUntilNextBus: Int? {
        guard let nextTime = nextBusTime else { return nil }
        return DateService.minutesUntil(timeString: nextTime, from: currentTime)
    }

    /// 다음 버스까지 남은 초
    var secondsUntilNextBus: Int? {
        guard let nextTime = nextBusTime else { return nil }
        return DateService.secondsUntil(timeString: nextTime, from: currentTime)
    }

    /// 카운트다운 텍스트 (MM:SS 형식)
    var countdownText: String {
        guard let seconds = secondsUntilNextBus, seconds > 0 else { return "--:--" }
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    /// 현재 방향의 소요시간 (분)
    var durationMinutes: Int {
        guard let data = timetableData,
              let routes = data.routes,
              let route = routes[selectedDirection.rawValue] else { return 0 }
        return route.durationMinutes
    }

    /// 현재 방향의 요금
    var fare: Int {
        guard let data = timetableData,
              let routes = data.routes,
              let route = routes[selectedDirection.rawValue] else { return 0 }
        return route.fare
    }

    /// 요금 포맷팅
    var fareText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: fare)) ?? "\(fare)") + "원"
    }

    /// 남은 시간 표시 문자열
    var remainingTimeText: String {
        guard let minutes = minutesUntilNextBus else { return "" }
        if minutes == 0 {
            return "곧 도착"
        } else if minutes < 60 {
            return "\(minutes)분 후"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)시간 \(mins)분 후" : "\(hours)시간 후"
        }
    }

    /// 첫차 시간
    var firstBusTime: String {
        currentTimes.first ?? "--:--"
    }

    /// 막차 시간
    var lastBusTime: String {
        currentTimes.last ?? "--:--"
    }

    /// 첫차까지 남은 시간 (시)
    var hoursUntilFirstBus: Int {
        guard let firstTime = currentTimes.first else { return 0 }
        let totalMinutes = DateService.minutesUntilNextDay(timeString: firstTime, from: currentTime)
        return totalMinutes / 60
    }

    /// 첫차까지 남은 시간 (분)
    var minutesUntilFirstBus: Int {
        guard let firstTime = currentTimes.first else { return 0 }
        let totalMinutes = DateService.minutesUntilNextDay(timeString: firstTime, from: currentTime)
        return totalMinutes % 60
    }

    // MARK: - Initialization

    init() {}

    deinit {
        timer?.invalidate()
    }

    // MARK: - Public Methods

    /// 시간표 데이터 로드
    func loadTimetable(with data: TimetableData) async {
        timetableData = data
        holidays = data.holidays
        noticeMessage = data.meta.noticeMessage

        // 현재 선택된 방향에 맞는 시간표 로드
        loadTimesForCurrentDirection(from: data)

        // 오늘 날짜에 맞는 시간표 타입 자동 선택
        let shouldUseWeekday = DateService.shouldUseWeekdaySchedule(Date(), holidays: holidays)
        selectedScheduleType = shouldUseWeekday ? .weekday : .weekend

        isLoading = false
    }

    /// 방향 변경
    func changeDirection(to direction: RouteDirection) {
        selectedDirection = direction
        if let data = timetableData {
            loadTimesForCurrentDirection(from: data)
        }
    }

    /// 실시간 타이머 시작
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = Date()
            }
        }
    }

    /// 알림 토글
    func toggleNotification(for busTime: String, minutesBefore: Int = 5) async {
        let key = "\(busTime)_\(minutesBefore)"
        if scheduledNotifications.contains(key) {
            NotificationService.shared.cancelNotification(busTime: busTime, minutesBefore: minutesBefore)
            scheduledNotifications.remove(key)
        } else {
            let granted = await NotificationService.shared.requestAuthorization()
            if granted {
                NotificationService.shared.scheduleBusNotification(
                    busTime: busTime,
                    minutesBefore: minutesBefore,
                    direction: currentDirectionName
                )
                scheduledNotifications.insert(key)
            }
        }
    }

    /// 알림이 예약되어 있는지 확인
    func isNotificationScheduled(for busTime: String, minutesBefore: Int = 5) -> Bool {
        scheduledNotifications.contains("\(busTime)_\(minutesBefore)")
    }

    // MARK: - Private Methods

    /// 현재 방향에 맞는 시간표 로드
    private func loadTimesForCurrentDirection(from data: TimetableData) {
        // routes가 있으면 routes 사용, 없으면 기존 timetable 사용 (하위호환)
        if let routes = data.routes,
           let route = routes[selectedDirection.rawValue] {
            weekdayTimes = route.timetable.weekday
            weekendTimes = route.timetable.weekend
        } else if let timetable = data.timetable {
            weekdayTimes = timetable.weekday
            weekendTimes = timetable.weekend
        }
    }

    /// 앱 시작 시 데이터 로드
    func onAppear() async {
        startTimer()

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
