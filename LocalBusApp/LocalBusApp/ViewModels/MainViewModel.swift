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
    /// 도착 시각이 현재 교통을 반영한 값인지 (목록 "기준" 열)
    var usesTraffic: Bool = false
}

struct BusTimingSnapshot {
    let nextBusTime: String?
    let isServiceEnded: Bool
    let nextBusMinuteDisplay: String
    let nextBusUnitDisplay: String
    let nextBusCountdownDescription: String
    /// 운행 종료 뒤에는 내일 첫차, 아니면 오늘 첫차
    let firstBusTime: String
    let hoursUntilFirstBus: Int
    let minutesUntilFirstBus: Int
    let minutesUntilNextBus: Int?
    let nextBusArrivalTime: String
    /// 다음 버스 도착 예상의 근거 (교통 반영 / 시간표 기준 …)
    let nextBusBasis: TrafficBasis
    /// 다음 버스가 아직 출발 1시간 전이 아니라 교통을 반영하지 않은 상태
    var nextBusAwaitsTrafficWindow: Bool = false
    /// "예상 소요 34분" / "기본 소요 26분"
    let nextBusDurationText: String
    let followingBusTime: String
    let nextBusProgress: Double
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

    /// 사용자가 켜 둔 버스 알림 (UserDefaults에 보관, 방향 + 출발 시각이 키)
    @Published private(set) var busAlerts: [BusAlert] = BusAlertStore().load()
    private let alertStore = BusAlertStore()

    /// 공지사항 (원격 JSON의 notices)
    @Published private(set) var notices: [NoticeItem] = []

    /// 읽은 공지 id (UserDefaults에 저장)
    @Published private(set) var readNoticeIDs: Set<String> = Set(
        UserDefaults.standard.stringArray(forKey: "readNoticeIDs") ?? []
    )

    /// 마지막으로 원격 시간표를 확인한 시각
    @Published private(set) var lastUpdateCheckAt: Date? = UserDefaults.standard.object(forKey: "lastUpdateCheckAt") as? Date

    /// 운영 상황 (원격 JSON "ops"). 없으면 배너·업데이트 안내가 뜨지 않는다.
    @Published private(set) var ops: OperationsInfo?

    /// 받은 알림 기록 (홈 종 아이콘 → 알림 모아보기)
    let notificationHistory: NotificationHistoryStore

    /// 원본 공지 데이터 (중요 공지 다이얼로그 판단용)
    private var noticeSource: [NoticeData] = []


    // MARK: - Private Properties

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
        "실시간"
    }

    /// 홈 상단 컨텍스트 라벨. 오늘 날짜와 어떤 시간표가 적용되는지 근거를 함께 보여준다.
    /// 예: "9월 22일 화 · 평일 시간표", "9월 28일 월 · 공휴일 · 주말 시간표"
    func scheduleContextText(at date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "M월 d일 E"
        let dateText = formatter.string(from: date)

        let isHoliday = DateService.isHoliday(date, holidays: holidays)
        let isWeekday = DateService.isWeekday(date)

        if isWeekday && isHoliday {
            return "\(dateText) · 공휴일 · 주말 시간표"
        }
        return isWeekday ? "\(dateText) · 평일 시간표" : "\(dateText) · 주말 시간표"
    }

    /// 오늘 자동 적용되는 시간표 타입 (사용자가 세그먼트로 바꾼 값과 무관)
    func todayScheduleType(at date: Date = Date()) -> ScheduleType {
        DateService.shouldUseWeekdaySchedule(date, holidays: holidays) ? .weekday : .weekend
    }

    /// 내일 적용될 시간표 타입
    func tomorrowScheduleType(at date: Date = Date()) -> ScheduleType {
        todayScheduleType(at: Self.tomorrow(of: date))
    }

    /// 내일 시간표. 해당 시간표 데이터가 비어 있으면 지금 보는 시간표로 대체한다.
    func tomorrowTimes(at date: Date = Date()) -> [String] {
        let times = tomorrowScheduleType(at: date) == .weekday ? weekdayTimes : weekendTimes
        return times.isEmpty ? currentTimes : times
    }

    /// 운행 종료 화면 하단 한 줄. 예: "내일은 9월 23일 수요일 · 평일 시간표로 운행해요"
    func tomorrowContextText(at date: Date = Date()) -> String {
        let tomorrow = Self.tomorrow(of: date)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "M월 d일 EEEE"
        let dateText = formatter.string(from: tomorrow)

        let isHoliday = DateService.isHoliday(tomorrow, holidays: holidays)
        let isWeekday = DateService.isWeekday(tomorrow)
        if isWeekday && isHoliday {
            return "내일은 \(dateText) · 공휴일 · 주말 시간표로 운행해요"
        }
        return "내일은 \(dateText) · \(isWeekday ? "평일" : "주말") 시간표로 운행해요"
    }

    private static let kstCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    private static func tomorrow(of date: Date) -> Date {
        kstCalendar.date(byAdding: .day, value: 1, to: date) ?? date
    }

    private static func yesterday(of date: Date) -> Date {
        kstCalendar.date(byAdding: .day, value: -1, to: date) ?? date
    }

    /// 한국 시각으로 자정부터 센 분
    private static func clockMinutes(of date: Date) -> Int {
        kstCalendar.component(.hour, from: date) * 60 + kstCalendar.component(.minute, from: date)
    }

    /// 큰 제목 아래 한 줄 노선 요약. 예: "장유 터미널 출발 · 26분 소요 · 2,500원"
    var routeSummaryText: String {
        var parts = ["\(currentTerminalName) 출발"]
        if durationMinutes > 0 { parts.append("평소 \(durationMinutes)분") }
        if fare > 0 { parts.append(fareText) }
        return parts.joined(separator: " · ")
    }

    /// 첫차·막차·심야 요금을 한 줄로. 예: "첫차 06:20 · 막차 23:30 · 22:10부터 심야 요금 3,000원"
    var serviceSummaryText: String {
        if let override = OperationsEvaluator.serviceSummaryOverride(
            ops: effectiveOps, routeKey: selectedDirection.rawValue, now: Date(),
            firstBusTime: firstBusTime, lastBusTime: lastBusTime
        ) {
            return override
        }
        var parts = ["첫차 \(firstBusTime)", "막차 \(lastBusTime)"]
        if let nightFare, let nightFareStartTime {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            let amount = formatter.string(from: NSNumber(value: nightFare)) ?? "\(nightFare)"
            parts.append("\(nightFareStartTime)부터 심야 요금 \(amount)원")
        }
        return parts.joined(separator: " · ")
    }

    /// 첫차 시간
    var firstBusTime: String {
        currentTimes.first ?? "--:--"
    }

    /// 막차 시간
    var lastBusTime: String {
        currentTimes.last ?? "--:--"
    }

    /// 실시간 교통 기반 소요시간 (nil이면 고정값 사용)
    @Published var trafficDurationMinutes: Int? = nil

    /// 교통 소요시간을 받은 시각 ("3분 전 갱신")
    @Published private(set) var trafficUpdatedAt: Date? = nil

    /// 교통정보를 새로 받는 중 (기존 예상값은 그대로 보여준다)
    @Published private(set) var isRefreshingTraffic = false

    /// 마지막으로 교통정보를 요청한 시각 (실패가 이어질 때 매번 다시 요청하지 않도록)
    private var lastTrafficRequestAt: Date?

    /// 자동 갱신이 실패한 뒤 다시 시도하기까지 기다리는 시간
    private static let trafficRetryInterval: TimeInterval = 5 * 60

    /// 실제 사용할 소요시간 (실시간 > 고정). 받은 지 오래된 교통값은 쓰지 않는다.
    private var effectiveDurationMinutes: Int {
        freshTrafficDuration(minutes: trafficDurationMinutes, updatedAt: trafficUpdatedAt) ?? durationMinutes
    }

    /// 아직 유효한(캐시 주기 이내) 교통 소요시간. 만료됐거나 없으면 nil.
    func freshTrafficDuration(minutes: Int?, updatedAt: Date?, now: Date = Date()) -> Int? {
        guard let minutes, ArrivalEstimator.isTrafficFresh(updatedAt: updatedAt, now: now) else { return nil }
        return minutes
    }

    /// 화면에 보여줄 소요시간 (실시간 교통 반영값)
    var currentDurationMinutes: Int {
        effectiveDurationMinutes
    }


    // MARK: - Initialization

    init(notificationHistory: NotificationHistoryStore = .shared) {
        self.notificationHistory = notificationHistory
        let saved = UserDefaults.standard.string(forKey: "selectedDirection") ?? RouteDirection.jangyuToSasang.rawValue
        self.selectedDirection = RouteDirection(rawValue: saved) ?? .jangyuToSasang
    }

    // MARK: - Public Methods

    /// - Parameter isTomorrow: 오늘 운행이 끝난 뒤 여는 내일 출발편
    func makeBusDetailInfo(for time: String, isTomorrow: Bool = false, at date: Date = Date()) -> BusDetailInfo {
        // 남은 시간과 교통 반영은 오늘 실제로 운행하는 시간표의 버스에만 붙인다
        let runsToday = !isTomorrow && selectedScheduleType == todayScheduleType(at: date)
        let scheduleType = isTomorrow ? tomorrowScheduleType(at: date) : selectedScheduleType
        let estimate = arrivalEstimate(for: time, isNextDay: !runsToday, at: date)
        return BusDetailInfo(
            departureTime: time,
            arrivalTime: estimate.arrivalTime,
            durationMinutes: estimate.durationMinutes,
            isVia: isViaBus(for: time),
            isNightFare: isNightFare(for: time),
            fare: fare,
            nightFare: nightFare,
            platformNumber: platformNumber,
            stops: currentStops,
            direction: selectedDirection,
            directionDisplayName: selectedDirection.displayName,
            scheduleTypeLabel: scheduleType == .weekday ? "평일" : "주말 · 공휴일",
            nightFareStartTime: nightFareStartTime,
            isNotificationEnabled: isNotificationScheduled(for: time),
            estimate: estimate,
            minutesUntilDeparture: runsToday ? minutesUntilToday(time, at: date) : nil,
            lastTrafficAt: trafficUpdatedAt,
            isTomorrow: isTomorrow
        )
    }

    func nextBusTime(at referenceDate: Date) -> String? {
        let schedule = serviceSchedule(at: referenceDate)
        return schedule.nextIndex.map { schedule.times[$0] }
    }

    /// 운행일 기준 시간표. 시간표 끝에 자정을 넘긴 버스(예: 00:10)가 있으면
    /// 자정 전에는 오늘 남은 버스로, 자정 직후에는 전날 시간표의 남은 버스로 센다.
    func serviceSchedule(at date: Date) -> ServiceDaySchedule {
        let yesterdayType = todayScheduleType(at: Self.yesterday(of: date))
        let yesterdayTimes = yesterdayType == .weekday ? weekdayTimes : weekendTimes
        return ServiceDaySchedule.resolve(
            todayTimes: currentTimes,
            yesterdayTimes: yesterdayTimes.isEmpty ? currentTimes : yesterdayTimes,
            clockMinutes: Self.clockMinutes(of: date)
        )
    }

    /// 오늘 운행일 기준으로 출발까지 남은 분 (음수면 이미 지남)
    func minutesUntilToday(_ time: String, at date: Date) -> Int? {
        serviceSchedule(at: date).minutesUntil(time) ?? DateService.minutesUntil(timeString: time, from: date)
    }

    /// 출발까지 남은 분. 이미 지난 버스는 0.
    /// - Parameter isNextDay: 지금 운행일이 끝난 뒤의 버스
    func minutesUntilDeparture(of time: String, isNextDay: Bool, at date: Date) -> Int {
        guard isNextDay else { return max(minutesUntilToday(time, at: date) ?? 0, 0) }
        // 자정 직후 전날 막차를 기다리는 동안에는 다음 운행일이 달력으로는 오늘이다
        if serviceSchedule(at: date).isOvernightTail {
            return max(DateService.minutesUntil(timeString: time, from: date) ?? 0, 0)
        }
        return DateService.minutesUntilNextDay(timeString: time, from: date)
    }

    /// 지금 운행일 다음 날의 시간표
    func nextServiceDayTimes(at date: Date) -> [String] {
        guard serviceSchedule(at: date).isOvernightTail else { return tomorrowTimes(at: date) }
        let times = todayScheduleType(at: date) == .weekday ? weekdayTimes : weekendTimes
        return times.isEmpty ? currentTimes : times
    }

    func makeTimingSnapshot(at referenceDate: Date) -> BusTimingSnapshot {
        let nextBusTime = nextBusTime(at: referenceDate)
        let minutesUntilNextBus = minutesUntilNextBus(at: referenceDate, nextBusTime: nextBusTime)
        let secondsUntilNextBus = secondsUntilNextBus(at: referenceDate, nextBusTime: nextBusTime)
        let firstBusLeadTime = firstBusLeadTime(at: referenceDate)
        let nextBusEstimate = nextBusTime.map { arrivalEstimate(for: $0, at: referenceDate) }

        // 오늘 남은 버스가 하나라도 있으면 운행 종료가 아니다 (간격이 길어도 다음 버스를 그대로 보여준다).
        let isServiceEnded = !currentTimes.isEmpty && nextBusTime == nil

        return BusTimingSnapshot(
            nextBusTime: nextBusTime,
            isServiceEnded: isServiceEnded,
            nextBusMinuteDisplay: nextBusMinuteDisplay(secondsUntilNextBus: secondsUntilNextBus),
            nextBusUnitDisplay: nextBusUnitDisplay(secondsUntilNextBus: secondsUntilNextBus),
            nextBusCountdownDescription: nextBusCountdownDescription(secondsUntilNextBus: secondsUntilNextBus),
            firstBusTime: nextBusTime == nil ? (tomorrowTimes(at: referenceDate).first ?? firstBusTime) : firstBusTime,
            hoursUntilFirstBus: firstBusLeadTime.hours,
            minutesUntilFirstBus: firstBusLeadTime.minutes,
            minutesUntilNextBus: minutesUntilNextBus,
            nextBusArrivalTime: nextBusEstimate?.arrivalTime ?? "--:--",
            nextBusBasis: nextBusEstimate?.basis ?? .timetable,
            nextBusAwaitsTrafficWindow: nextBusEstimate?.awaitsTrafficWindow ?? false,
            nextBusDurationText: nextBusEstimate?.durationText ?? "기본 소요 \(durationMinutes)분",
            followingBusTime: followingBusTime(after: nextBusTime),
            nextBusProgress: nextBusProgress(nextBusTime: nextBusTime, minutesUntilNextBus: minutesUntilNextBus),
            upcomingBuses: buildUpcomingBuses(limit: 5, at: referenceDate)
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
        ops = data.ops
        rebuildNotices(from: data)
        noticeMessage = data.meta.noticeMessage

        // 현재 선택된 방향에 맞는 시간표 로드
        loadTimesForCurrentDirection(from: data)

        // 오늘 날짜에 맞는 시간표 타입 자동 선택
        let shouldUseWeekday = DateService.shouldUseWeekdaySchedule(Date(), holidays: holidays)
        selectedScheduleType = shouldUseWeekday ? .weekday : .weekend

        isLoading = false

        await refreshTrafficDuration()
        await refreshScheduledNotifications()
    }

    /// 방향 변경
    func changeDirection(to direction: RouteDirection) {
        guard selectedDirection != direction else { return }

        selectedDirection = direction
        UserDefaults.standard.set(direction.rawValue, forKey: "selectedDirection")
        if let data = timetableData {
            loadTimesForCurrentDirection(from: data)
        }
        Task { await refreshTrafficDuration() }
    }

    /// 실시간 교통 소요시간 갱신
    func refreshTrafficDuration(force: Bool = false) async {
        guard let origin = currentRouteOrigin,
              let destination = currentRouteDestination else { return }
        if force { TrafficService.shared.invalidateCache() }
        lastTrafficRequestAt = Date()
        isRefreshingTraffic = true
        defer { isRefreshingTraffic = false }
        let detail = await TrafficService.shared.fetchDurationDetail(
            origin: origin,
            destination: destination
        )
        trafficDurationMinutes = detail?.minutes
        trafficUpdatedAt = detail?.updatedAt
        if let detail {
            EntitlementStore.saveTraffic(routeKey: selectedDirection.rawValue, durationMinutes: detail.minutes, updatedAt: detail.updatedAt)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// 교통값이 만료됐고 곧 출발할 버스가 있으면 새로 받는다 (앱을 다시 열었을 때, 홈을 오래 켜 둔 동안).
    func refreshTrafficIfExpired(now: Date = Date()) async {
        if let lastTrafficRequestAt, now.timeIntervalSince(lastTrafficRequestAt) < Self.trafficRetryInterval { return }
        guard !isLoading, !isRefreshingTraffic,
              !ArrivalEstimator.isTrafficFresh(updatedAt: trafficUpdatedAt, now: now),
              let nextBusTime = nextBusTime(at: now),
              let minutes = minutesUntilToday(nextBusTime, at: now),
              minutes <= ArrivalEstimator.trafficWindowMinutes else { return }
        await refreshTrafficDuration()
    }

    /// 특정 버스의 도착 예상. 출발 1시간 이내면 교통을 반영하고 그 밖에는 기본 소요시간.
    func arrivalEstimate(for busTime: String, isNextDay: Bool = false, at date: Date = Date()) -> ArrivalEstimate {
        let minutesUntil = isNextDay ? nil : minutesUntilToday(busTime, at: date)
        return ArrivalEstimator.estimate(
            departureTime: busTime,
            minutesUntilDeparture: minutesUntil,
            baseDurationMinutes: durationMinutes,
            trafficDurationMinutes: trafficDurationMinutes,
            trafficUpdatedAt: trafficUpdatedAt,
            isRefreshing: isRefreshingTraffic,
            isOffline: isOffline,
            now: date
        )
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

    /// 막차 30분 전 알림 예약
    func scheduleLastBusNotification() async {
        let granted = await NotificationService.shared.requestAuthorization()
        guard granted, let info = makeLastBusAlertInfo(direction: selectedDirection, scheduledAt: Date()) else { return }
        NotificationService.shared.scheduleLastBusNotification(info)
    }

    /// 그 방향의 오늘 막차로 막차 알림 정보를 만든다. 심야 요금은 막차가 심야 시간대일 때만 넣는다.
    private func makeLastBusAlertInfo(direction: RouteDirection, scheduledAt: Date) -> LastBusAlertInfo? {
        let times: [String]
        if let timetable = timetableData?.routes?[direction.rawValue]?.timetable ?? timetableData?.timetable {
            times = DateService.shouldUseWeekdaySchedule(Date(), holidays: holidays) ? timetable.weekday : timetable.weekend
        } else {
            times = direction == selectedDirection ? currentTimes : []
        }
        guard let lastBus = times.last else { return nil }

        var nightFare: Int?
        if let start = getNightFareStartTime(for: direction), lastBus >= start || lastBus < "04:00" {
            nightFare = getNightFare(for: direction)
        }
        return LastBusAlertInfo(direction: direction, busTime: lastBus, nightFare: nightFare, scheduledAt: scheduledAt)
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

    /// 알림 토글 (홈·시간표의 빠른 버튼): 없으면 오늘 한 번 알림을 만들고, 있으면 지운다.
    func toggleNotification(for busTime: String, minutesBefore: Int = 5) async {
        if let alert = alert(for: busTime) {
            removeAlert(id: alert.id)
        } else {
            await setAlert(for: busTime, leadMinutes: minutesBefore, repeatsWeekdays: false)
        }
    }

    /// 선택된 방향의 특정 버스 알림
    func alert(for busTime: String) -> BusAlert? {
        alert(for: busTime, direction: selectedDirection)
    }

    /// 방향을 지정해 찾는다 (알림 관리·받은 알림처럼 선택된 방향과 다를 수 있는 곳에서 사용).
    func alert(for busTime: String, direction: RouteDirection) -> BusAlert? {
        let id = BusAlert.makeID(busTime: busTime, direction: direction)
        return busAlerts.first { $0.id == id }
    }

    /// 알림·받은 알림에서 버스 상세를 열 때 쓴다.
    /// 상세 시트의 알림 설정은 선택된 방향으로 저장되므로, 그 버스의 방향으로 먼저 바꾼다.
    func makeBusDetailInfo(for busTime: String, direction: RouteDirection) -> BusDetailInfo {
        if selectedDirection != direction {
            changeDirection(to: direction)
        }
        return makeBusDetailInfo(for: busTime)
    }

    /// 알림을 만들거나 lead·반복을 바꾼다. 권한이 없으면 false.
    @discardableResult
    func setAlert(for busTime: String, leadMinutes: Int, repeatsWeekdays: Bool) async -> Bool {
        let granted = await NotificationService.shared.requestAuthorization()
        guard granted else { return false }

        let alert = BusAlert(
            busTime: busTime,
            direction: selectedDirection,
            leadMinutes: leadMinutes,
            repeatsWeekdays: repeatsWeekdays,
            isEnabled: true
        )
        upsert(alert)
        scheduleSystemNotification(for: alert)

        startLiveActivityIfDue(for: busTime)
        return true
    }

    /// 출발 20분 이내 버스면 Live Activity 시작 (설정에서 활성화된 경우)
    private func startLiveActivityIfDue(for busTime: String, now: Date = Date()) {
        let liveActivityEnabled = UserDefaults.standard.object(forKey: "liveActivityEnabled") as? Bool ?? true
        guard #available(iOS 16.2, *),
              liveActivityEnabled,
              let departure = LiveActivityTiming.departureDate(for: busTime, now: now),
              LiveActivityTiming.shouldStart(now: now, departure: departure),
              !LiveActivityService.shared.isShowing(departureTime: busTime, direction: currentDirectionName) else { return }

        let estimate = arrivalEstimate(for: busTime)
        var nightFareText: String?
        if isNightFare(for: busTime), let nightFare {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            nightFareText = "심야 \(formatter.string(from: NSNumber(value: nightFare)) ?? "\(nightFare)")원"
        }
        LiveActivityService.shared.startActivity(
            departureTime: busTime,
            direction: currentDirectionName,
            durationMinutes: estimate.durationMinutes,
            destinationName: currentArrivalHubName,
            boardingStopName: currentStops.first?.name ?? currentTerminalName,
            isLastBus: busTime == lastBusTime,
            nextDayFirstBusTime: tomorrowTimes().first,
            nightFareText: nightFareText,
            usesTraffic: estimate.basis.usesTraffic,
            trafficUpdatedAt: trafficUpdatedAt
        )
    }

    /// 알림을 걸 때는 20분 밖이었던 버스가 그 안으로 들어왔으면 지금 표시를 시작한다.
    /// 앱이 열리거나 다시 앞으로 올 때 부른다. 앱이 꺼져 있는 동안에는 시작할 수 없다.
    func startLiveActivityForDueAlerts(now: Date = Date()) {
        // 평일 반복 알림은 주말·공휴일에 울리지 않으므로 표시도 시작하지 않는다
        let isWeekdaySchedule = DateService.shouldUseWeekdaySchedule(now, holidays: holidays)
        let due = busAlerts
            .filter { $0.isEnabled && $0.direction == selectedDirection }
            .filter { !$0.repeatsWeekdays || isWeekdaySchedule }
            .compactMap { alert in
                LiveActivityTiming.departureDate(for: alert.busTime, now: now).map { (alert.busTime, $0) }
            }
            .filter { LiveActivityTiming.shouldStart(now: now, departure: $0.1) }
            .min { $0.1 < $1.1 }
        guard let due else { return }
        startLiveActivityIfDue(for: due.0, now: now)
    }

    /// 알림을 켜거나 끈다 (목록은 유지).
    func setAlertEnabled(id: String, _ isEnabled: Bool) {
        guard var alert = busAlerts.first(where: { $0.id == id }) else { return }
        alert.isEnabled = isEnabled
        upsert(alert)
        scheduleSystemNotification(for: alert)
    }

    /// 알림을 목록에서 지운다.
    func removeAlert(id: String) {
        busAlerts.removeAll { $0.id == id }
        alertStore.save(busAlerts)
        NotificationService.shared.cancel(alertID: id)
        if #available(iOS 16.2, *) {
            LiveActivityService.shared.endActivity()
        }
    }

    /// 켜져 있는 알림 수
    var enabledAlertCount: Int {
        busAlerts.filter(\.isEnabled).count
    }

    /// 꺼 둔 것을 포함한 알림 수 (설정·알림 모아보기의 "3개")
    var alertCount: Int {
        busAlerts.count
    }

    /// 알림이 예약되어 있는지 확인
    func isNotificationScheduled(for busTime: String) -> Bool {
        alert(for: busTime)?.isEnabled == true
    }

    /// 이미 울린 한 번 알림은 목록에서 빼고, 반복 알림은 공휴일 반영을 위해 다시 예약한다.
    func refreshScheduledNotifications() async {
        recordFiredBusAlerts()
        await refreshLastBusNotification()
        let pending = await NotificationService.shared.pendingAlertIDs()
        busAlerts.removeAll { !$0.repeatsWeekdays && $0.isEnabled && !pending.contains($0.id) }
        alertStore.save(busAlerts)
        for alert in busAlerts where alert.repeatsWeekdays && alert.isEnabled {
            scheduleSystemNotification(for: alert)
        }
    }

    /// 시스템 알림 본문에 타는 곳(탑승홈 또는 출발 정류장)을 넣어 예약한다.
    private func scheduleSystemNotification(for alert: BusAlert) {
        NotificationService.shared.schedule(
            alert,
            holidays: holidays,
            platformNumber: getPlatformNumber(for: alert.direction),
            boardingStopName: boardingStopName(for: alert.direction)
        )
    }

    private func boardingStopName(for direction: RouteDirection) -> String? {
        let stops = getStops(for: direction)
        return (stops.first(where: \.isDeparture) ?? stops.first)?.name
    }

    /// 막차 알림: 울린 것은 기록으로 옮기고, 막차 시각이 바뀌었으면 새 시각으로 다시 건다.
    private func refreshLastBusNotification(now: Date = Date()) async {
        if let info = LastBusAlertInfo.load() {
            for firedAt in info.firedDates(now: now) {
                notificationHistory.record(info.historyItem(firedAt: firedAt))
            }
            if let current = makeLastBusAlertInfo(direction: info.direction, scheduledAt: info.scheduledAt), current != info {
                NotificationService.shared.scheduleLastBusNotification(current)
            }
        } else if await NotificationService.shared.hasPendingLastBusNotification(),
                  let info = makeLastBusAlertInfo(direction: selectedDirection, scheduledAt: now) {
            // 이전 버전이 걸어 둔 알림: 문구와 기록 정보를 지금 형식으로 맞춘다
            NotificationService.shared.scheduleLastBusNotification(info)
        }
        startLiveActivityForDueAlerts()
    }

    private func upsert(_ alert: BusAlert) {
        if let index = busAlerts.firstIndex(where: { $0.id == alert.id }) {
            busAlerts[index] = alert
        } else {
            busAlerts.append(alert)
        }
        busAlerts.sort { ($0.busTime, $0.direction.rawValue) < ($1.busTime, $1.direction.rawValue) }
        alertStore.save(busAlerts)
    }

    // MARK: - Private Methods

    private func minutesUntilNextBus(at referenceDate: Date, nextBusTime: String?) -> Int? {
        guard let nextBusTime else { return nil }
        return minutesUntilToday(nextBusTime, at: referenceDate)
    }

    private func secondsUntilNextBus(at referenceDate: Date, nextBusTime: String?) -> Int? {
        guard let nextBusTime, let minutes = minutesUntilToday(nextBusTime, at: referenceDate) else { return nil }
        return minutes * 60 - Self.kstCalendar.component(.second, from: referenceDate)
    }

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
        if secondsUntilNextBus <= 60 { return "곧 도착" }
        let minutes = Int(ceil(Double(secondsUntilNextBus) / 60.0))
        if minutes >= 60 {
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(remainingMinutes)분 후 출발" : "후 출발"
        }
        return "후 출발"
    }

    private func firstBusLeadTime(at referenceDate: Date) -> (hours: Int, minutes: Int) {
        guard let firstTime = nextServiceDayTimes(at: referenceDate).first else { return (0, 0) }
        let totalMinutes = minutesUntilDeparture(of: firstTime, isNextDay: true, at: referenceDate)
        return (totalMinutes / 60, totalMinutes % 60)
    }

    private func nextBusArrivalTime(for nextBusTime: String?) -> String {
        guard let nextBusTime else { return "--:--" }
        return DateService.timeByAdding(minutes: effectiveDurationMinutes, to: nextBusTime) ?? "--:--"
    }

    private func followingBusTime(after nextBusTime: String?) -> String {
        guard let nextBusTime,
              let nextIndex = currentTimes.firstIndex(of: nextBusTime),
              nextIndex + 1 < currentTimes.count else { return "--:--" }
        return currentTimes[nextIndex + 1]
    }

    private func nextBusProgress(nextBusTime: String?, minutesUntilNextBus: Int?) -> Double {
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
        guard !currentTimes.isEmpty else { return [] }

        let schedule = serviceSchedule(at: referenceDate)
        let futureTimes = schedule.times.filter { (schedule.minutesUntil($0) ?? -1) >= 0 }

        var selectedTimes = futureTimes.prefix(limit).map { ($0, false) }

        if selectedTimes.count < limit {
            let remainingCount = limit - selectedTimes.count
            let nextDayTimes = nextServiceDayTimes(at: referenceDate).prefix(remainingCount).map { ($0, true) }
            selectedTimes.append(contentsOf: nextDayTimes)
        }

        let actualLastTodayTime   = futureTimes.last
        let firstNextDayIndex = selectedTimes.firstIndex { $0.1 }

        return Array(selectedTimes.enumerated()).map { index, item in
            let (time, isNextDay) = item
            let minutesUntilDeparture = minutesUntilDeparture(of: time, isNextDay: isNextDay, at: referenceDate)
            let status = statusDescriptor(
                for: minutesUntilDeparture,
                isNextDay: isNextDay,
                isFirstNextDay: index == firstNextDayIndex,
                isLastToday: !isNextDay && time == actualLastTodayTime,
                isNightBus: !isNextDay && isNightFare(for: time)
            )
            let estimate = arrivalEstimate(for: time, isNextDay: isNextDay, at: referenceDate)

            return UpcomingBusSnapshot(
                id: "\(time)_\(isNextDay)",
                departureTime: time,
                relativeText: relativeDepartureText(for: minutesUntilDeparture, isNextDay: isNextDay),
                arrivalTime: estimate.arrivalTime,
                statusText: status.text,
                statusKind: status.kind,
                usesTraffic: estimate.basis.usesTraffic
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

        return ("정시 운행", .onTime)
    }

    /// 앱 시작 시 데이터 로드
    func onAppear() async {
        if #available(iOS 16.2, *) {
            // 앱이 다시 앞으로 올 때마다 20분 안에 들어온 알림의 Live Activity를 시작
            LiveActivityService.shared.reconcile()
            LiveActivityService.shared.onBecameActive = { [weak self] in
                self?.startLiveActivityForDueAlerts()
            }
        }

        let timetableService = TimetableService()
        let networkService = NetworkService()

        // 1. 원격 데이터 fetch 시도
        if let url = remoteURL {
            do {
                let remoteData: TimetableData = try await networkService.fetch(from: url)
                // 앱을 열 때 자동으로 받아 온 것도 "확인"이다. 수동 새로고침 때만 기록하면 오래됨 배너가 잘못 뜬다.
                markUpdateChecked()
                if let cached = timetableService.loadCachedData(), cached.meta.updatedAt != remoteData.meta.updatedAt {
                    recordTimetableUpdate(to: remoteData.meta.updatedAt, changes: TimetableDiff.changes(old: cached, new: remoteData))
                }
                timetableService.saveToCache(remoteData)
                // App Group 캐시가 갱신됐으니 위젯도 새 시간표로 다시 그리도록 타임라인 리로드
                WidgetCenter.shared.reloadAllTimelines()
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

    // MARK: - 시간표 업데이트 확인 (설정 화면)

    /// 원격 시간표를 받아 기준일이 바뀌었으면 적용한다. 확인 시각은 저장한다.
    func checkForTimetableUpdate() async -> TimetableUpdateResult {
        guard let url = remoteURL else { return .failed }
        let networkService = NetworkService()
        let timetableService = TimetableService()

        do {
            let remoteData: TimetableData = try await networkService.fetch(from: url)
            markUpdateChecked()
            isOffline = false

            let current = timetableData?.meta.updatedAt ?? "--"
            let changes = timetableData.map { TimetableDiff.changes(old: $0, new: remoteData) } ?? []
            let result = TimetableUpdateResult.evaluate(current: current, fetched: remoteData.meta.updatedAt, changes: changes)
            if case .updated(_, let to, let changes) = result {
                recordTimetableUpdate(to: to, changes: changes)
            }

            // 기준일이 같아도 공지 등 부속 데이터는 최신으로 맞춘다.
            timetableService.saveToCache(remoteData)
            WidgetCenter.shared.reloadAllTimelines()
            await loadTimetable(with: remoteData)
            return result
        } catch {
            print("⚠️ [MainViewModel] 업데이트 확인 실패: \(error)")
            isOffline = true
            return .failed
        }
    }

    func markUpdateChecked(at now: Date = Date()) {
        lastUpdateCheckAt = now
        UserDefaults.standard.set(now, forKey: "lastUpdateCheckAt")
    }

    // MARK: - 공지사항

    var unreadNoticeCount: Int {
        notices.filter { $0.isNew }.count
    }

    func markNoticeRead(_ id: String) {
        guard !readNoticeIDs.contains(id) else { return }
        readNoticeIDs.insert(id)
        UserDefaults.standard.set(Array(readNoticeIDs), forKey: "readNoticeIDs")
        if let data = timetableData { rebuildNotices(from: data) }
    }

    private func rebuildNotices(from data: TimetableData) {
        // 원격 JSON에 notices가 아직 없으면 번들 JSON의 공지를 쓴다.
        let source = data.notices ?? TimetableService().loadLocalData()?.notices ?? []
        noticeSource = source
        notices = source.map { $0.asNoticeItem(isUnread: !readNoticeIDs.contains($0.id)) }
        recordNewNotices(source)
    }

    // MARK: - 받은 알림 기록

    /// 처음 보는 공지는 "새 소식"으로 기록한다 (푸시를 못 받았어도 모아보기에 남도록).
    private func recordNewNotices(_ source: [NoticeData]) {
        for notice in source where !readNoticeIDs.contains(notice.id) {
            let receivedAt = Self.date(fromDotted: notice.date) ?? Date()
            notificationHistory.record(AppNotification(
                id: "notice_\(notice.id)",
                kind: .notice,
                title: notice.title,
                body: notice.body.first ?? "",
                receivedAt: receivedAt,
                target: .notice(id: notice.id)
            ))
        }
    }

    private func recordTimetableUpdate(to updatedAt: String, changes: [TimetableChange]) {
        let summary = TimetableDiff.summaryText(for: changes)
        notificationHistory.record(AppNotification(
            id: "timetable_\(updatedAt)",
            kind: .timetable,
            title: "새 시간표를 적용했어요",
            body: summary ?? "\(updatedAt.replacingOccurrences(of: "-", with: ".")) 기준 시간표",
            receivedAt: Date(),
            target: .timetable
        ))
    }

    /// 오늘 이미 울린 버스 알림을 기록으로 옮긴다 (앱을 켰을 때 호출).
    func recordFiredBusAlerts(now: Date = Date()) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let dayFormatter = DateFormatter()
        dayFormatter.timeZone = calendar.timeZone
        dayFormatter.dateFormat = "yyyyMMdd"

        for alert in busAlerts where alert.isEnabled {
            let parts = alert.alertTime.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2,
                  let fireAt = calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: now),
                  fireAt <= now else { continue }
            if alert.repeatsWeekdays && !DateService.shouldUseWeekdaySchedule(now, holidays: holidays) { continue }
            notificationHistory.record(AppNotification(
                id: "bus_\(alert.id)_\(dayFormatter.string(from: now))",
                kind: .bus,
                title: NotificationCopy.busTitle(busTime: alert.busTime, leadMinutes: alert.leadMinutes),
                body: NotificationCopy.busBody(
                    direction: alert.direction,
                    platformNumber: getPlatformNumber(for: alert.direction),
                    boardingStopName: boardingStopName(for: alert.direction)
                ),
                receivedAt: fireAt,
                target: .bus(direction: alert.direction, time: alert.busTime)
            ))
        }
    }

    // MARK: - 운영 상황 (디자인 캔버스 Ops*)

    /// 지금 홈에 띄울 안내 배너 하나 (운휴 > 연결 없음 > 변경 예고 > 공휴일 > 오래됨 > 점검). 없으면 nil.
    func operationsBanner(now: Date = Date()) -> OperationsBanner? {
        if let forced = Self.forcedBanner(updatedAt: updatedAtText) { return forced }
        return OperationsEvaluator.banner(
            ops: ops,
            routeKey: selectedDirection.rawValue,
            now: now,
            lastUpdateCheckAt: lastUpdateCheckAt,
            updatedAt: updatedAtText,
            isOffline: isOffline,
            holidays: holidays
        )
    }

    /// 앱 버전이 원격 최소·권장 버전보다 낮은지
    var updateRequirement: UpdateRequirement {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        switch UserDefaults.standard.string(forKey: "forceUpdate") {
        case "required": return .required(version: "1.2")
        case "recommended": return .recommended(version: "1.2")
        default: break
        }
        return OperationsEvaluator.updateRequirement(current: current, min: ops?.minAppVersion, recommended: ops?.recommendedAppVersion)
    }

    /// 권장 업데이트 시트 본문
    var updateMessage: String {
        ops?.updateMessage ?? "도착 예상과 알림 모아보기가 추가됐어요. 지금 버전도 계속 쓸 수 있어요."
    }

    /// UI 테스트·스크린샷용 강제 운휴 데이터 (`-forceOpsBanner closure`)
    private var effectiveOps: OperationsInfo? {
        if UserDefaults.standard.string(forKey: "forceOpsBanner") == "closure" {
            return OperationsInfo(closure: .init(
                date: OperationsEvaluator.dayKey(Date()), title: "오늘 22:10 이후 버스는 운행하지 않아요",
                reason: "도로 공사", lastBus: "21:40", routeKeys: nil
            ))
        }
        return ops
    }

    private static func forcedBanner(updatedAt: String) -> OperationsBanner? {
        switch UserDefaults.standard.string(forKey: "forceOpsBanner") {
        case "closure": return .closure(title: "오늘 22:10 이후 버스는 운행하지 않아요", subtitle: "막차 21:40 · 도로 공사")
        case "change": return .change(title: "10월 1일부터 시간표가 바뀌어요", noticeID: nil)
        case "stale": return .stale(baselineText: OperationsEvaluator.baselineText(updatedAt))
        case "maintenance": return .maintenance(message: "새 시간표 확인을 잠시 멈췄어요")
        case "offline": return .offline(baselineText: OperationsEvaluator.baselineText(updatedAt))
        case "holiday": return .holiday
        default: return nil
        }
    }

    // MARK: - 중요 공지 다이얼로그

    /// 앱을 열자마자 띄울 중요 공지. 읽었거나, 오늘 하루 보지 않기를 눌렀거나, 게시 종료일이 지났으면 nil.
    func importantNoticeToShow(now: Date = Date()) -> NoticeItem? {
        let today = Self.dayKey(now)
        for notice in noticeSource where notice.important == true {
            if readNoticeIDs.contains(notice.id) { continue }
            if let endsAt = notice.endsAt, endsAt < today { continue }
            if UserDefaults.standard.string(forKey: "noticeDialogSnoozed_\(notice.id)") == today { continue }
            return notice.asNoticeItem(isUnread: true)
        }
        return nil
    }

    func snoozeImportantNotice(id: String, now: Date = Date()) {
        UserDefaults.standard.set(Self.dayKey(now), forKey: "noticeDialogSnoozed_\(id)")
    }

    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func date(fromDotted text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.date(from: text)
    }
}
