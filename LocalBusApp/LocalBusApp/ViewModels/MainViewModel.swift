import ActivityKit
import CoreLocation
import Foundation
import SwiftUI
import WidgetKit

enum UpcomingBusStatusKind: Equatable {
    case onTime
    case delayed
    case nextDay
    case lastBus
    case nightBus
}

struct UpcomingBusSnapshot: Identifiable, Equatable {
    let id: String
    let departureTime: String
    let relativeText: String
    let arrivalTime: String
    let statusText: String
    let statusKind: UpcomingBusStatusKind
}

struct BusTimingSnapshot {
    let nextBusTime: String?
    let isServiceEnded: Bool
    let nextBusMinuteDisplay: String
    let nextBusUnitDisplay: String
    let nextBusCountdownDescription: String
    let firstBusTime: String
    let hoursUntilFirstBus: Int
    let minutesUntilFirstBus: Int
    let nextBusArrivalTime: String
    let followingBusTime: String
    let upcomingBuses: [UpcomingBusSnapshot]
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

    /// 알림 예약 상태
    @Published private(set) var scheduledNotifications: Set<String> = []

    @Published private(set) var isCheckingTimetableUpdate = false
    @Published private(set) var isUpdatingTimetable = false
    @Published private(set) var hasCheckedTimetableUpdate = false
    @Published private var pendingTimetableData: TimetableData?

    var hasTimetableUpdate: Bool { pendingTimetableData != nil }

    enum TimetableUpdateResult {
        case updated, alreadyCurrent, unavailable
    }

    // MARK: - Private Properties

    private var updateCheckTask: Task<Void, Never>?

    /// 전체 시간표 데이터 (routes 포함)
    private var timetableData: TimetableData?

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
        "출발지: \(currentDepartureStopName)"
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

    /// 현재 방향의 경유 시간 전체 집합
    var currentViaTimes: Set<String> {
        guard let routes = timetableData?.routes,
              let route = routes[selectedDirection.rawValue],
              let viaTimes = route.viaTimes else { return [] }
        return Set(viaTimes)
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
        let now = Date()
        let today = TimetableTimeline.calendar.startOfDay(for: now)
        let serviceDate = departures(from: now).first.flatMap { $0.serviceDate <= today ? $0.serviceDate : nil } ?? now
        let type: ScheduleType = DateService.shouldUseWeekdaySchedule(serviceDate, holidays: holidays) ? .weekday : .weekend
        return "\(type.displayLabel) · 시간표 기준"
    }

    /// 첫차 시간
    var firstBusTime: String {
        operatingTimes(on: Date()).first ?? "--:--"
    }

    /// 막차 시간
    var lastBusTime: String {
        operatingTimes(on: Date()).last ?? "--:--"
    }

    /// 실시간 교통 기반 소요시간 (nil이면 고정값 사용)
    @Published var trafficDurationMinutes: Int? = nil

    /// 실제 사용할 소요시간 (실시간 > 고정)
    private var effectiveDurationMinutes: Int {
        trafficDurationMinutes ?? durationMinutes
    }


    // MARK: - Initialization

    init() {
        let saved = UserDefaults.standard.string(forKey: "selectedDirection") ?? RouteDirection.jangyuToSasang.rawValue
        self.selectedDirection = RouteDirection(rawValue: saved) ?? .jangyuToSasang
        if PreviewRuntime.isRunning, let data = TimetableService().loadLocalData() {
            selectedDirection = .jangyuToSasang
            timetableData = data
            holidays = data.holidays
            noticeMessage = data.meta.noticeMessage
            loadTimesForCurrentDirection(from: data)
            selectedScheduleType = .weekday
            isLoading = false
        }
    }

    // MARK: - Public Methods

    func makeBusDetailInfo(for time: String) -> BusDetailInfo {
        let arrival = DateService.timeByAdding(minutes: effectiveDurationMinutes, to: time) ?? "--:--"
        return BusDetailInfo(
            departureTime: time,
            arrivalTime: arrival,
            durationMinutes: effectiveDurationMinutes,
            isVia: isViaBus(for: time),
            isNightFare: isNightFare(for: time),
            fare: fare,
            nightFare: nightFare,
            platformNumber: platformNumber,
            stops: currentStops,
            directionDisplayName: selectedDirection.displayName,
            scheduleTypeLabel: selectedScheduleType.displayLabel,
            isNotificationEnabled: isNotificationScheduled(for: time)
        )
    }

    private func operatingTimes(on date: Date) -> [String] {
        TimetableTimeline.times(on: date, weekday: weekdayTimes, weekend: weekendTimes, holidays: holidays)
    }

    private func departures(from date: Date) -> [TimetableTimeline.Departure] {
        TimetableTimeline.departures(weekday: weekdayTimes, weekend: weekendTimes, holidays: holidays, from: date)
    }

    func nextBusTime(at referenceDate: Date) -> String? {
        let today = TimetableTimeline.calendar.startOfDay(for: referenceDate)
        return departures(from: referenceDate).first(where: { $0.serviceDate <= today })?.time
    }

    func nextBusTimeForSelectedSchedule(at referenceDate: Date) -> String? {
        let today = TimetableTimeline.calendar.startOfDay(for: referenceDate)
        let type: ScheduleType = DateService.shouldUseWeekdaySchedule(referenceDate, holidays: holidays) ? .weekday : .weekend
        guard selectedScheduleType == type,
              let next = departures(from: referenceDate).first,
              next.serviceDate == today else { return nil }
        return next.time
    }

    func makeTimingSnapshot(at referenceDate: Date) -> BusTimingSnapshot {
        let future = departures(from: referenceDate)
        let today = TimetableTimeline.calendar.startOfDay(for: referenceDate)
        let next = future.first
        let isServiceEnded = next.map { $0.serviceDate > today } ?? (!weekdayTimes.isEmpty || !weekendTimes.isEmpty)
        let seconds = next.map { max(0, Int($0.date.timeIntervalSince(referenceDate))) }
        let leadMinutes = Int(ceil(Double(seconds ?? 0) / 60))
        let firstTime = isServiceEnded ? (next?.time ?? "--:--") : (operatingTimes(on: next?.serviceDate ?? referenceDate).first ?? "--:--")
        return BusTimingSnapshot(
            nextBusTime: isServiceEnded ? nil : next?.time,
            isServiceEnded: isServiceEnded,
            nextBusMinuteDisplay: nextBusMinuteDisplay(secondsUntilNextBus: seconds),
            nextBusUnitDisplay: nextBusUnitDisplay(secondsUntilNextBus: seconds),
            nextBusCountdownDescription: nextBusCountdownDescription(secondsUntilNextBus: seconds),
            firstBusTime: firstTime,
            hoursUntilFirstBus: leadMinutes / 60,
            minutesUntilFirstBus: leadMinutes % 60,
            nextBusArrivalTime: nextBusArrivalTime(for: next?.time),
            followingBusTime: future.dropFirst().first?.time ?? "--:--",
            upcomingBuses: buildUpcomingBuses(limit: 3, at: referenceDate)
        )
    }

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

    /// 미리 추출된 도로 경로 좌표. 없으면 nil → 지도 뷰가 정류장 직선으로 폴백.
    func getRoutePath(for direction: RouteDirection) -> [CLLocationCoordinate2D]? {
        guard let raw = timetableData?.routes?[direction.rawValue]?.path else { return nil }
        return raw.compactMap { pair in
            guard pair.count == 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
        }
    }

    /// 시간표 데이터 로드
    func loadTimetable(with data: TimetableData) async {
        timetableData = data
        errorMessage = nil
        holidays = data.holidays
        noticeMessage = data.meta.noticeMessage

        // 현재 선택된 방향에 맞는 시간표 로드
        loadTimesForCurrentDirection(from: data)

        // 오늘 날짜에 맞는 시간표 타입 자동 선택
        let shouldUseWeekday = DateService.shouldUseWeekdaySchedule(Date(), holidays: holidays)
        selectedScheduleType = shouldUseWeekday ? .weekday : .weekend

        isLoading = false

        await refreshTrafficDuration()
        await refreshScheduledNotifications()
        await updateSavedLastBusReminder(using: data)
    }

    /// 방향 변경
    func changeDirection(to direction: RouteDirection) {
        guard selectedDirection != direction else { return }

        selectedDirection = direction
        trafficDurationMinutes = nil
        if !PreviewRuntime.isRunning {
            UserDefaults.standard.set(direction.rawValue, forKey: "selectedDirection")
        }
        if let data = timetableData {
            loadTimesForCurrentDirection(from: data)
        }
        Task { await refreshTrafficDuration() }
    }

    /// 실시간 교통 소요시간 갱신
    func refreshTrafficDuration() async {
        guard !PreviewRuntime.isRunning else { return }
        let requestedDirection = selectedDirection
        guard let origin = currentRouteOrigin,
              let destination = currentRouteDestination else { return }
        let minutes = await TrafficService.shared.fetchDuration(
            origin: origin,
            destination: destination
        )
        guard selectedDirection == requestedDirection else { return }
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

    /// 현재 노선의 실제 오늘 시간표로 막차 알림을 예약한다.
    func scheduleLastBusNotification() async throws {
        guard let data = timetableData,
              let time = TimetableService().getCurrentTimetable(for: Date(), direction: selectedDirection, data: data).last else {
            throw NotificationService.ScheduleError.invalidTime
        }
        try await NotificationService.shared.scheduleLastBusNotification(
            lastBusTime: time, direction: currentDirectionName
        )
    }

    /// 저장한 알림 대상 노선은 홈에서 조회하는 노선과 독립적으로 유지한다.
    private func updateSavedLastBusReminder(using data: TimetableData) async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "lastMileAlertEnabled"),
              let raw = defaults.string(forKey: "lastBusDirection"),
              let direction = RouteDirection(rawValue: raw),
              let lastTime = TimetableService().getCurrentTimetable(for: Date(), direction: direction, data: data).last,
              await NotificationService.shared.lastBusReminderSummary() != nil else { return }
        do {
            try await NotificationService.shared.scheduleLastBusNotification(lastBusTime: lastTime, direction: direction.displayName)
            defaults.removeObject(forKey: "lastBusReminderUpdateError")
        } catch {
            defaults.set("시간표 변경에 맞춰 알림을 갱신하지 못했습니다. 다시 설정해주세요.", forKey: "lastBusReminderUpdateError")
        }
    }

    func cancelLastBusNotification() {
        NotificationService.shared.cancelLastBusNotification()
    }

    enum NotificationResult {
        case scheduled, cancelled, denied, failed(String)
        var message: String {
            switch self {
            case .scheduled: return "출발 5분 전 알림을 설정했습니다"
            case .cancelled: return "버스 알림을 해제했습니다"
            case .denied: return "설정에서 알림 권한을 허용해주세요"
            case .failed(let message): return message
            }
        }
    }

    private var notificationChangeInFlight = false

    func notificationDeparture(for time: String, useSelectedSchedule: Bool = true, now: Date = Date()) -> TimetableTimeline.Departure? {
        let today = TimetableTimeline.calendar.startOfDay(for: now)
        if !useSelectedSchedule {
            return departures(from: now).first { $0.time == time && $0.serviceDate <= today }
        }
        let type: ScheduleType = DateService.shouldUseWeekdaySchedule(now, holidays: holidays) ? .weekday : .weekend
        guard selectedScheduleType == type else { return nil }
        return TimetableTimeline.departure(time: time, times: currentTimes, serviceDate: today)
    }

    @discardableResult
    func toggleNotification(for busTime: String, minutesBefore: Int = 5, useSelectedSchedule: Bool = true, now: Date = Date(), notificationService: any BusNotificationScheduling = NotificationService.shared) async -> NotificationResult {
        guard !notificationChangeInFlight else { return .failed("알림 설정 중입니다. 잠시 기다려주세요.") }
        guard let departure = notificationDeparture(for: busTime, useSelectedSchedule: useSelectedSchedule, now: now) else {
            return .failed("오늘 운행하는 시간표에서 알림을 설정해주세요.")
        }
        notificationChangeInFlight = true
        defer { notificationChangeInFlight = false }
        let direction = selectedDirection
        let duration = effectiveDurationMinutes
        let key = NotificationService.busNotificationIdentifier(departure: departure.date, direction: direction, minutesBefore: minutesBefore)
        scheduledNotifications = await notificationService.scheduledBusNotificationKeys()
        if scheduledNotifications.contains(key) {
            notificationService.cancelNotification(identifier: key)
            scheduledNotifications.remove(key)
            if #available(iOS 16.2, *) {
                await LiveActivityService.shared.endActivity(departure: departure.date, direction: direction.displayName)
            }
            return .cancelled
        }
        do {
            _ = try NotificationService.reminderComponents(departure: departure.date, minutesBefore: minutesBefore, now: now)
            guard await notificationService.requestAuthorization() else { return .denied }
            try await notificationService.scheduleBusNotification(departure: departure, minutesBefore: minutesBefore, direction: direction)
            scheduledNotifications.insert(key)
            let enabled = UserDefaults.standard.object(forKey: "liveActivityEnabled") as? Bool ?? true
            if #available(iOS 16.2, *), enabled, departure.date.timeIntervalSinceNow <= 20 * 60 {
                await LiveActivityService.shared.startActivity(departure: departure, direction: direction.displayName, durationMinutes: duration)
            }
            return .scheduled
        } catch {
            return .failed((error as? NotificationService.ScheduleError)?.localizedDescription ?? "알림을 예약하지 못했습니다. 다시 시도해주세요.")
        }
    }

    func isNotificationScheduled(for busTime: String, minutesBefore: Int = 5, useSelectedSchedule: Bool = true) -> Bool {
        guard let departure = notificationDeparture(for: busTime, useSelectedSchedule: useSelectedSchedule) else { return false }
        return scheduledNotifications.contains(NotificationService.busNotificationIdentifier(departure: departure.date, direction: selectedDirection, minutesBefore: minutesBefore))
    }

    func refreshScheduledNotifications() async {
        scheduledNotifications = await NotificationService.shared.scheduledBusNotificationKeys()
    }

    // MARK: - Private Methods

    private func nextBusMinuteDisplay(secondsUntilNextBus: Int?) -> String {
        guard let secondsUntilNextBus else { return "--" }
        if secondsUntilNextBus <= 60 { return "" }
        let minutes = Int(ceil(Double(secondsUntilNextBus) / 60.0))
        if minutes >= 60 {
            return String(minutes / 60)
        }
        return String(minutes)
    }

    private func nextBusUnitDisplay(secondsUntilNextBus: Int?) -> String {
        guard let secondsUntilNextBus else { return "분" }
        if secondsUntilNextBus <= 60 { return "" }
        let minutes = Int(ceil(Double(secondsUntilNextBus) / 60.0))
        return minutes >= 60 ? "시간" : "분"
    }

    private func nextBusCountdownDescription(secondsUntilNextBus: Int?) -> String {
        guard let secondsUntilNextBus else { return "후 출발" }
        if secondsUntilNextBus <= 60 { return "곧 출발" }
        let minutes = Int(ceil(Double(secondsUntilNextBus) / 60.0))
        if minutes >= 60 {
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(remainingMinutes)분 후 출발" : "후 출발"
        }
        return "후 출발"
    }

    private func nextBusArrivalTime(for nextBusTime: String?) -> String {
        guard let nextBusTime else { return "--:--" }
        return DateService.timeByAdding(minutes: effectiveDurationMinutes, to: nextBusTime) ?? "--:--"
    }

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

    func buildUpcomingBuses(limit: Int, at referenceDate: Date = Date()) -> [UpcomingBusSnapshot] {
        guard limit > 0 else { return [] }
        let today = TimetableTimeline.calendar.startOfDay(for: referenceDate)
        let selected = Array(departures(from: referenceDate).prefix(limit))
        let firstNextDayIndex = selected.firstIndex { $0.serviceDate > today }
        return selected.enumerated().map { index, departure in
            let isNextDay = departure.serviceDate > today
            let minutes = max(0, Int(ceil(departure.date.timeIntervalSince(referenceDate) / 60)))
            let status = statusDescriptor(
                for: minutes, isNextDay: isNextDay, isFirstNextDay: index == firstNextDayIndex,
                isLastToday: !isNextDay && departure.isLast,
                isNightBus: !isNextDay && isNightFare(for: departure.time)
            )
            return UpcomingBusSnapshot(
                id: "\(departure.time)_\(Int(departure.date.timeIntervalSince1970))", departureTime: departure.time,
                relativeText: relativeDepartureText(for: minutes, isNextDay: isNextDay),
                arrivalTime: DateService.timeByAdding(minutes: effectiveDurationMinutes, to: departure.time) ?? departure.time,
                statusText: status.text, statusKind: status.kind
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
        isFirstNextDay: Bool,
        isLastToday: Bool,
        isNightBus: Bool
    ) -> (text: String, kind: UpcomingBusStatusKind) {
        if isNextDay {
            return (isFirstNextDay ? "내일 첫차" : "내일 운행", .nextDay)
        }

        if isLastToday {
            return ("막차", .lastBus)
        }

        if isNightBus {
            return ("심야", .nightBus)
        }

        if minutes <= 5 {
            return ("곧 출발", .onTime)
        }

        return ("시간표 기준", .onTime)
    }

    /// 저장된 시간표를 먼저 표시하고 새 시간표가 있는지 확인합니다.
    func onAppear(timetableService: TimetableService = TimetableService(), networkService: NetworkService = NetworkService()) async {
        await checkForTimetableUpdate(timetableService: timetableService, networkService: networkService)
    }

    func checkForTimetableUpdate(timetableService: TimetableService = TimetableService(), networkService: NetworkService = NetworkService()) async {
        guard !PreviewRuntime.isRunning else { return }
        if let updateCheckTask {
            await updateCheckTask.value
            return
        }
        guard !isUpdatingTimetable else { return }
        isCheckingTimetableUpdate = true
        let task = Task { @MainActor in
            if timetableData == nil,
               let saved = timetableService.loadInitialData() {
                WidgetCenter.shared.reloadAllTimelines()
                await loadTimetable(with: saved)
            }
            do {
                guard let url = remoteURL else { throw NetworkError.invalidURL }
                let remote: TimetableData = try await networkService.fetch(from: url)
                try remote.validate(requireRoutes: timetableData?.routes != nil)
                if let current = timetableData {
                    pendingTimetableData = try remote.isUpdate(comparedTo: current) ? remote : nil
                } else {
                    // 최초 실행에 저장된 시간표도 없을 때만 바로 적용합니다.
                    timetableService.saveToCache(remote)
                    WidgetCenter.shared.reloadAllTimelines()
                    await loadTimetable(with: remote)
                }
                isOffline = false
                hasCheckedTimetableUpdate = true
            } catch {
                // 이미 확인한 업데이트와 사용 중인 시간표는 보존합니다.
                isOffline = true
            }
            isLoading = false
            if timetableData == nil { errorMessage = "시간표를 불러올 수 없습니다." }
        }
        updateCheckTask = task
        await task.value
        updateCheckTask = nil
        isCheckingTimetableUpdate = false
    }

    /// 사용자가 요청할 때 확인한 새 시간표를 적용합니다. 당겨서 새로고침도 같은 동작입니다.
    @discardableResult
    func refresh(timetableService: TimetableService = TimetableService(), networkService: NetworkService = NetworkService()) async -> TimetableUpdateResult {
        if let updateCheckTask { await updateCheckTask.value }
        guard !isUpdatingTimetable else { return .unavailable }
        if pendingTimetableData == nil {
            await checkForTimetableUpdate(timetableService: timetableService, networkService: networkService)
        }
        guard let update = pendingTimetableData else {
            return isOffline ? .unavailable : .alreadyCurrent
        }
        isUpdatingTimetable = true
        pendingTimetableData = nil
        timetableService.saveToCache(update)
        WidgetCenter.shared.reloadAllTimelines()
        await loadTimetable(with: update)
        isUpdatingTimetable = false
        return .updated
    }
}
