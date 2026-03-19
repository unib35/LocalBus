import Foundation
import SwiftUI

enum UpcomingBusStatusKind: Equatable {
    case onTime
    case delayed
    case nextDay
}

struct UpcomingBusSnapshot: Identifiable, Equatable {
    let id: String
    let departureTime: String
    let relativeText: String
    let arrivalTime: String
    let statusText: String
    let statusKind: UpcomingBusStatusKind
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

    private let remoteURL = URL(string: "https://raw.githubusercontent.com/unib35/LocalBus/main/LocalBusApp/LocalBusApp/Resources/timetable.json")

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
        DateService.findNextBus(times: currentTimes, from: currentTime)
    }

    /// 운행 종료 여부
    var isServiceEnded: Bool {
        nextBusTime == nil && !currentTimes.isEmpty
    }

    /// 현재 방향의 표시 이름
    var currentDirectionName: String {
        selectedDirection.displayName
    }

    /// 현재 방향의 출발지 이름
    var currentDepartureStopName: String {
        if let stop = currentStops.first(where: { $0.isDeparture }) { return stop.name }
        if let stop = currentStops.first { return stop.name }
        switch selectedDirection {
        case .jangyuToSasang: return "장유"
        case .sasangToJangyu: return "사상"
        case .yulhaToSasang:  return "율하"
        case .sasangToYulha:  return "사상"
        }
    }

    /// 현재 방향의 도착지 이름
    var currentArrivalStopName: String {
        if let stop = currentStops.last { return stop.name }
        switch selectedDirection {
        case .jangyuToSasang: return "사상"
        case .sasangToJangyu: return "장유"
        case .yulhaToSasang:  return "사상"
        case .sasangToYulha:  return "율하"
        }
    }

    /// 홈 상단 위치 텍스트
    var dashboardLocationText: String {
        "현재 위치: \(currentTerminalName)"
    }

    /// 홈 화면 출발 터미널 이름
    var currentTerminalName: String {
        switch selectedDirection {
        case .jangyuToSasang: return "장유 터미널"
        case .sasangToJangyu: return "사상 터미널"
        case .yulhaToSasang:  return "율하 (김해외고)"
        case .sasangToYulha:  return "사상 터미널"
        }
    }

    /// 홈 화면 도착지 축약명
    var currentArrivalHubName: String {
        switch selectedDirection {
        case .jangyuToSasang: return "사상"
        case .sasangToJangyu: return "장유"
        case .yulhaToSasang:  return "사상"
        case .sasangToYulha:  return "율하"
        }
    }

    /// 심야 요금
    var nightFare: Int? {
        guard let routes = timetableData?.routes,
              let route = routes[selectedDirection.rawValue] else { return nil }
        return route.nightFare
    }

    /// 심야 요금 적용 시작 시간 ("22:10")
    var nightFareStartTime: String? {
        guard let routes = timetableData?.routes,
              let route = routes[selectedDirection.rawValue] else { return nil }
        return route.nightFareStartTime
    }

    /// 탑승 홈 번호 (사상터미널 출발 노선에만 존재)
    var platformNumber: String? {
        guard let routes = timetableData?.routes,
              let route = routes[selectedDirection.rawValue] else { return nil }
        return route.platformNumber
    }

    /// 주어진 시간이 심야 요금 적용 대상인지
    func isNightFare(for time: String) -> Bool {
        guard let start = nightFareStartTime else { return false }
        return time >= start
    }

    /// 주어진 시간이 경유 버스인지 (진영·부곡 경유)
    func isViaBus(for time: String) -> Bool {
        guard let routes = timetableData?.routes,
              let route = routes[selectedDirection.rawValue],
              let viaTimes = route.viaTimes else { return false }
        return viaTimes.contains(time)
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

    /// 다음 버스까지 남은 분 표시값 (초 기준 올림, 60초 이하면 빈 문자열)
    var nextBusMinuteDisplay: String {
        guard let seconds = secondsUntilNextBus else { return "--" }
        if seconds <= 60 { return "" }
        return String(Int(ceil(Double(seconds) / 60.0)))
    }

    /// 다음 버스 단위 텍스트 (60초 이하면 빈 문자열)
    var nextBusUnitDisplay: String {
        guard let seconds = secondsUntilNextBus else { return "분" }
        return seconds <= 60 ? "" : "분"
    }

    /// 다음 버스 카운트다운 보조 텍스트
    var nextBusCountdownDescription: String {
        guard let seconds = secondsUntilNextBus else { return "후 출발" }
        return seconds <= 60 ? "곧 도착" : "후 출발"
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

    /// 데이터 기준일 표시 문자열
    var updatedAtText: String {
        timetableData?.meta.updatedAt ?? "--"
    }

    /// 현재 시간표 배지 텍스트
    var scheduleBadgeText: String {
        "실시간"
    }

    /// 남은 시간 표시 문자열
    var remainingTimeText: String {
        guard let seconds = secondsUntilNextBus else { return "" }
        if seconds <= 60 {
            return "곧 도착"
        }
        let minutes = Int(ceil(Double(seconds) / 60.0))
        if minutes < 60 {
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

    /// 실시간 교통 기반 소요시간 (nil이면 고정값 사용)
    @Published var trafficDurationMinutes: Int? = nil

    /// 실제 사용할 소요시간 (실시간 > 고정)
    private var effectiveDurationMinutes: Int {
        trafficDurationMinutes ?? durationMinutes
    }

    /// 다음 버스 예상 도착 시간
    var nextBusArrivalTime: String {
        guard let nextBusTime else { return "--:--" }
        return DateService.timeByAdding(minutes: effectiveDurationMinutes, to: nextBusTime) ?? "--:--"
    }

    /// 다음 버스 이후 버스 출발 시간 (배차 참고용)
    var followingBusTime: String {
        guard let nextBusTime,
              let nextIndex = currentTimes.firstIndex(of: nextBusTime),
              nextIndex + 1 < currentTimes.count else { return "--:--" }
        return currentTimes[nextIndex + 1]
    }

    /// 다음 버스 진행률
    var nextBusProgress: Double {
        guard let nextBusTime,
              let nextIndex = currentTimes.firstIndex(of: nextBusTime),
              let minutesUntilNextBus else {
            return 0
        }

        let intervalMinutes: Int
        if nextIndex > 0,
           let previousInterval = DateService.minutesBetween(from: currentTimes[nextIndex - 1], to: nextBusTime),
           previousInterval > 0 {
            intervalMinutes = previousInterval
        } else if nextIndex + 1 < currentTimes.count,
                  let nextInterval = DateService.minutesBetween(from: nextBusTime, to: currentTimes[nextIndex + 1]),
                  nextInterval > 0 {
            intervalMinutes = nextInterval
        } else {
            intervalMinutes = max(minutesUntilNextBus, 1)
        }

        let elapsedMinutes = max(intervalMinutes - max(minutesUntilNextBus, 0), 0)
        let progress = Double(elapsedMinutes) / Double(max(intervalMinutes, 1))
        return min(max(progress, 0.08), 1.0)
    }

    /// 홈 화면 예정 버스 목록
    var upcomingBuses: [UpcomingBusSnapshot] {
        buildUpcomingBuses(limit: 3)
    }

    // MARK: - Initialization

    init() {}

    deinit {
        timer?.invalidate()
    }

    // MARK: - Public Methods

    func getStops(for direction: RouteDirection) -> [BusStop] {
        guard let data = timetableData else { return [] }
        return TimetableService().getStops(for: direction, data: data)
    }

    func getFare(for direction: RouteDirection) -> Int {
        guard let data = timetableData,
              let route = data.routes?[direction.rawValue] else { return 0 }
        return route.fare
    }

    func getPlatformNumber(for direction: RouteDirection) -> String? {
        timetableData?.routes?[direction.rawValue]?.platformNumber
    }

    func getNightFare(for direction: RouteDirection) -> Int? {
        timetableData?.routes?[direction.rawValue]?.nightFare
    }

    func getNightFareStartTime(for direction: RouteDirection) -> String? {
        timetableData?.routes?[direction.rawValue]?.nightFareStartTime
    }

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

        await refreshTrafficDuration()
    }

    /// 방향 변경
    func changeDirection(to direction: RouteDirection) {
        selectedDirection = direction
        if let data = timetableData {
            loadTimesForCurrentDirection(from: data)
        }
        Task { await refreshTrafficDuration() }
    }

    /// 실시간 교통 소요시간 갱신
    func refreshTrafficDuration() async {
        guard let origin = currentRouteOrigin,
              let destination = currentRouteDestination else { return }
        let minutes = await TrafficService.shared.fetchDuration(
            origin: origin,
            destination: destination
        )
        trafficDurationMinutes = minutes
    }

    /// 현재 노선 출발지 좌표
    private var currentRouteOrigin: Coordinate? {
        currentStops.first(where: { $0.isDeparture })
            .flatMap { stop in
                guard let lat = stop.latitude, let lon = stop.longitude else { return nil }
                return Coordinate(latitude: lat, longitude: lon)
            }
    }

    /// 현재 노선 도착지 좌표
    private var currentRouteDestination: Coordinate? {
        currentStops.last
            .flatMap { stop in
                guard let lat = stop.latitude, let lon = stop.longitude else { return nil }
                return Coordinate(latitude: lat, longitude: lon)
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

    /// 막차 30분 전 알림 예약
    func scheduleLastBusNotification() async {
        let granted = await NotificationService.shared.requestAuthorization()
        guard granted else { return }
        NotificationService.shared.scheduleLastBusNotification(
            lastBusTime: lastBusTime,
            direction: currentDirectionName
        )
    }

    /// 막차 알림 취소
    func cancelLastBusNotification() {
        NotificationService.shared.cancelLastBusNotification()
    }

    /// 캐시 초기화 후 데이터 재로드
    func clearCacheAndRefresh() async {
        TimetableService().clearCache()
        await refresh()
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

    private func buildUpcomingBuses(limit: Int) -> [UpcomingBusSnapshot] {
        guard !currentTimes.isEmpty else { return [] }

        let futureTimes = currentTimes.filter {
            (DateService.minutesUntil(timeString: $0, from: currentTime) ?? -1) >= 0
        }

        var selectedTimes = futureTimes.prefix(limit).map { ($0, false) }

        if selectedTimes.count < limit {
            let remainingCount = limit - selectedTimes.count
            let nextDayTimes = currentTimes.prefix(remainingCount).map { ($0, true) }
            selectedTimes.append(contentsOf: nextDayTimes)
        }

        return Array(selectedTimes.enumerated()).map { index, item in
            let (time, isNextDay) = item
            let minutesUntilDeparture = isNextDay
                ? DateService.minutesUntilNextDay(timeString: time, from: currentTime)
                : max(DateService.minutesUntil(timeString: time, from: currentTime) ?? 0, 0)
            let status = statusDescriptor(
                for: minutesUntilDeparture,
                isNextDay: isNextDay,
                displayIndex: index
            )
            let totalMinutes = durationMinutes + (status.kind == .delayed ? 5 : 0)

            return UpcomingBusSnapshot(
                id: "\(time)_\(isNextDay)",
                departureTime: time,
                relativeText: relativeDepartureText(for: minutesUntilDeparture, isNextDay: isNextDay),
                arrivalTime: DateService.timeByAdding(minutes: totalMinutes, to: time) ?? time,
                statusText: status.text,
                statusKind: status.kind
            )
        }
    }

    private func relativeDepartureText(for minutes: Int, isNextDay: Bool) -> String {
        if isNextDay {
            return "내일 운행"
        }

        if minutes == 0 {
            return "곧 출발"
        }

        if minutes < 60 {
            return "\(minutes)분 후"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if remainingMinutes == 0 {
            return "\(hours)시간 후"
        }

        return "\(hours)시간 \(remainingMinutes)분 후"
    }

    private func statusDescriptor(
        for minutes: Int,
        isNextDay: Bool,
        displayIndex: Int
    ) -> (text: String, kind: UpcomingBusStatusKind) {
        if isNextDay {
            return ("내일 첫차", .nextDay)
        }

        if minutes <= 5 {
            return ("곧 출발", .onTime)
        }

        if displayIndex == 2 {
            return ("5분 지연", .delayed)
        }

        return ("정시 운행", .onTime)
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
                print("⚠️ [MainViewModel] fetch 실패: \(error)")
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
