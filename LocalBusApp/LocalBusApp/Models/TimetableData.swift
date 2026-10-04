import Foundation

// MARK: - 노선 구분

enum RouteLine: String, CaseIterable {
    case jangyu = "jangyu"
    case yulha  = "yulha"

    var displayName: String {
        switch self {
        case .jangyu: return "장유 노선"
        case .yulha:  return "율하 노선"
        }
    }

    var directions: [RouteDirection] {
        switch self {
        case .jangyu: return [.jangyuToSasang, .sasangToJangyu]
        case .yulha:  return [.yulhaToSasang,  .sasangToYulha]
        }
    }

    var defaultDirection: RouteDirection { directions[0] }
}

// MARK: - 방향 Enum

/// 노선 방향
enum RouteDirection: String, CaseIterable, Codable {
    case jangyuToSasang = "jangyu_to_sasang"
    case sasangToJangyu = "sasang_to_jangyu"
    case yulhaToSasang  = "yulha_to_sasang"
    case sasangToYulha  = "sasang_to_yulha"

    var displayName: String {
        switch self {
        case .jangyuToSasang: return "장유 → 사상"
        case .sasangToJangyu: return "사상 → 장유"
        case .yulhaToSasang:  return "율하 → 사상"
        case .sasangToYulha:  return "사상 → 율하"
        }
    }

    var routeLine: RouteLine {
        switch self {
        case .jangyuToSasang, .sasangToJangyu: return .jangyu
        case .yulhaToSasang,  .sasangToYulha:  return .yulha
        }
    }

    /// 출발지 짧은 이름 (큰 제목용)
    var departureName: String {
        switch self {
        case .jangyuToSasang: return "장유"
        case .sasangToJangyu: return "사상"
        case .yulhaToSasang:  return "율하"
        case .sasangToYulha:  return "사상"
        }
    }

    /// 도착지 짧은 이름 (큰 제목용)
    var arrivalName: String {
        switch self {
        case .jangyuToSasang: return "사상"
        case .sasangToJangyu: return "장유"
        case .yulhaToSasang:  return "사상"
        case .sasangToYulha:  return "율하"
        }
    }

    /// 같은 노선의 반대 방향
    var opposite: RouteDirection {
        switch self {
        case .jangyuToSasang: return .sasangToJangyu
        case .sasangToJangyu: return .jangyuToSasang
        case .yulhaToSasang:  return .sasangToYulha
        case .sasangToYulha:  return .yulhaToSasang
        }
    }
}

// MARK: - 정류장

/// 버스 정류장 정보
struct BusStop: Codable {
    let id: String
    let name: String
    let description: String?
    let isDeparture: Bool
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, description, latitude, longitude
        case isDeparture = "is_departure"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        isDeparture = try container.decodeIfPresent(Bool.self, forKey: .isDeparture) ?? false
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
    }
}

// MARK: - 노선 데이터

/// 노선별 시간표 데이터
struct RouteData: Codable {
    let name: String
    let durationMinutes: Int
    let fare: Int
    let nightFare: Int?
    let nightFareStartTime: String?
    let platformNumber: String?
    let viaTimes: [String]?
    let stops: [BusStop]
    let timetable: Timetable
    /// MKDirections로 미리 추출한 도로 경로 좌표. [[lat, lng], ...]
    let path: [[Double]]?

    enum CodingKeys: String, CodingKey {
        case name, stops, timetable, fare, path
        case durationMinutes      = "duration_minutes"
        case nightFare            = "night_fare"
        case nightFareStartTime   = "night_fare_start_time"
        case platformNumber       = "platform_number"
        case viaTimes             = "via_times"
    }
}

// MARK: - 시간표 데이터

/// 시간표 데이터 전체 구조
struct TimetableData: Codable {
    let meta: Meta
    let holidays: [String]
    let timetable: Timetable?
    let routes: [String: RouteData]?
    /// 공지사항. 원격 JSON으로 갱신되며, 없으면 nil (하위호환).
    let notices: [NoticeData]?
    /// 운영 상황(임시 운휴·변경 예고·점검·앱 버전). 없으면 nil.
    let ops: OperationsInfo?

    init(
        meta: Meta,
        holidays: [String],
        timetable: Timetable?,
        routes: [String: RouteData]? = nil,
        notices: [NoticeData]? = nil,
        ops: OperationsInfo? = nil
    ) {
        self.meta = meta
        self.holidays = holidays
        self.timetable = timetable
        self.routes = routes
        self.notices = notices
        self.ops = ops
    }
}

// MARK: - 공지사항 데이터 (JSON)

/// JSON의 공지 항목. 화면 모델(NoticeItem)로 변환해 쓴다.
struct NoticeData: Codable, Equatable {
    let id: String
    let title: String
    let date: String
    let category: String?
    let body: [String]
    let timetableSummary: NoticeSummaryData?
    /// 임시 운휴·시간표 변경처럼 앱을 열자마자 보여줄 공지
    let important: Bool?
    /// 이 날짜(yyyy-MM-dd)가 지나면 다이얼로그로 띄우지 않는다
    let endsAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, date, category, body, important
        case timetableSummary = "timetable_summary"
        case endsAt = "ends_at"
    }

    init(id: String, title: String, date: String, category: String?, body: [String], timetableSummary: NoticeSummaryData?, important: Bool? = nil, endsAt: String? = nil) {
        self.id = id; self.title = title; self.date = date; self.category = category
        self.body = body; self.timetableSummary = timetableSummary
        self.important = important; self.endsAt = endsAt
    }

    func asNoticeItem(isUnread: Bool) -> NoticeItem {
        NoticeItem(
            id: id,
            title: title,
            date: date,
            author: "관리자",
            isNew: isUnread,
            body: body,
            timetableSummary: timetableSummary.map { summary in
                NoticeTimetableSummary(
                    effectiveDate: summary.effectiveDate,
                    departureLabel: summary.departureLabel,
                    arrivalLabel: summary.arrivalLabel,
                    rows: summary.rows.map { NoticeTimetableRow(departure: $0.departure, arrival: $0.arrival, isNew: $0.isNew) },
                    note: summary.note,
                    fullScheduleImageURL: summary.fullScheduleImageURL.flatMap(URL.init(string:))
                )
            },
            categoryLabel: category
        )
    }
}

struct NoticeSummaryData: Codable, Equatable {
    let effectiveDate: String
    let departureLabel: String
    let arrivalLabel: String
    let rows: [NoticeSummaryRowData]
    let note: String?
    let fullScheduleImageURL: String?

    enum CodingKeys: String, CodingKey {
        case rows, note
        case effectiveDate = "effective_date"
        case departureLabel = "departure_label"
        case arrivalLabel = "arrival_label"
        case fullScheduleImageURL = "full_schedule_image_url"
    }
}

struct NoticeSummaryRowData: Codable, Equatable {
    let departure: String
    let arrival: String
    let isNew: Bool

    enum CodingKeys: String, CodingKey {
        case departure, arrival
        case isNew = "is_new"
    }
}

/// 메타 정보
struct Meta: Codable {
    var revision: TimetableRevision { TimetableRevision(version: version, updatedAt: updatedAt) }
    let version: Int
    let updatedAt: String
    let noticeMessage: String?
    let contactEmail: String

    enum CodingKeys: String, CodingKey {
        case version
        case updatedAt = "updated_at"
        case noticeMessage = "notice_message"
        case contactEmail = "contact_email"
    }

    init(version: Int, updatedAt: String, noticeMessage: String?, contactEmail: String) {
        self.version = version
        self.updatedAt = updatedAt
        self.noticeMessage = noticeMessage
        self.contactEmail = contactEmail
    }
}

// MARK: - 버스 상세 정보 (시트용 스냅샷)

struct BusDetailInfo: Identifiable {
    var id: String { departureTime }
    let departureTime: String
    let arrivalTime: String
    let durationMinutes: Int
    let isVia: Bool
    let isNightFare: Bool
    let fare: Int
    let nightFare: Int?
    let platformNumber: String?
    let stops: [BusStop]
    let direction: RouteDirection
    let directionDisplayName: String
    let scheduleTypeLabel: String
    let nightFareStartTime: String?
    var isNotificationEnabled: Bool
    /// 도착 예상 (교통 반영 여부 포함). 없으면 durationMinutes로 계산한 arrivalTime을 쓴다.
    var estimate: ArrivalEstimate? = nil
    /// 출발까지 남은 분 (지났으면 음수, 내일 편이면 nil)
    var minutesUntilDeparture: Int? = nil
    /// 마지막으로 교통정보를 받은 시각
    var lastTrafficAt: Date? = nil
    /// 내일 출발편 (오늘 운행이 끝난 뒤 여는 내일 첫차 등)
    var isTomorrow: Bool = false
}

extension BusDetailInfo {
    /// 오늘 아직 출발하지 않은 버스
    var isUpcomingToday: Bool {
        guard !isTomorrow, let minutes = minutesUntilDeparture else { return false }
        return minutes >= 0
    }

    /// 헤더 오른쪽 위 한 줄: "12분 후 출발" / "내일 06:20 출발". 지난 버스와 오늘 운행하지 않는 시간표는 nil.
    var untilText: String? {
        if isTomorrow { return "내일 \(departureTime) 출발" }
        guard isUpcomingToday, let minutes = minutesUntilDeparture else { return nil }
        if minutes == 0 { return "곧 출발" }
        if minutes < 60 { return "\(minutes)분 후 출발" }
        let rest = minutes % 60
        return rest == 0 ? "\(minutes / 60)시간 후 출발" : "\(minutes / 60)시간 \(rest)분 후 출발"
    }

    /// 출발까지 많이 남아 아직 교통을 반영하지 않는 버스 (먼 시간대 · 내일 · 오늘 운행하지 않는 시간표)
    var isBeforeTrafficWindow: Bool {
        if isTomorrow { return true }
        guard let minutes = minutesUntilDeparture else { return true }
        return minutes > ArrivalEstimator.trafficWindowMinutes
    }

    /// 새로고침해서 교통을 반영할 수 있는 버스인지 (오늘 출발 1시간 이내)
    var canRefreshTraffic: Bool {
        isUpcomingToday && !isBeforeTrafficWindow
    }

    /// 설명 카드 각주: "17:30부터 교통 반영" / "내일 05:20부터 교통 반영". 교통을 이미 반영할 시간대면 nil.
    var trafficStartText: String? {
        guard isTomorrow || (minutesUntilDeparture ?? 0) > ArrivalEstimator.trafficWindowMinutes,
              let start = DateService.timeByAdding(minutes: -ArrivalEstimator.trafficWindowMinutes, to: departureTime) else {
            return nil
        }
        // 자정 직후 출발편은 교통 반영이 전날 밤에 시작된다
        let startsOnDepartureDay = start < departureTime
        return isTomorrow && startsOnDepartureDay ? "내일 \(start)부터 교통 반영" : "\(start)부터 교통 반영"
    }
}

/// 시간표 (평일/주말)
struct Timetable: Codable, Equatable {
    let weekday: [String]
    let weekend: [String]

    init(weekday: [String], weekend: [String]) {
        self.weekday = weekday
        self.weekend = weekend
    }
}

// 버전/기준일을 올리지 않은 시간표 수정도 감지하되, 이전 배포본으로 되돌리지 않습니다.
extension TimetableData {
    func isUpdate(comparedTo current: TimetableData) throws -> Bool {
        guard meta.version >= current.meta.version else { return false }
        if meta.version == current.meta.version,
           meta.updatedAt < current.meta.updatedAt { return false }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self) != encoder.encode(current)
    }
}

extension TimetableData {
    enum ValidationError: Error { case invalidData }

    /// 레거시 단일 시간표는 로컬 호환용으로 허용합니다. 노선형 자료는 모든 방향이 필요합니다.
    func validate(requireRoutes: Bool = false) throws {
        func require(_ valid: Bool) throws {
            if !valid { throw ValidationError.invalidData }
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        func validDate(_ value: String) -> Bool {
            guard let date = formatter.date(from: value) else { return false }
            return formatter.string(from: date) == value
        }
        func minute(_ value: String) -> Int? {
            let parts = value.split(separator: ":", omittingEmptySubsequences: false)
            guard value.count == 5, parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]),
                  (0..<24).contains(h), (0..<60).contains(m),
                  value == String(format: "%02d:%02d", h, m) else { return nil }
            return h * 60 + m
        }
        func validateTimes(_ times: [String]) throws {
            try require(!times.isEmpty && times.count <= 1440 && Set(times).count == times.count)
            var previous = -1
            var rollover = false
            for value in times {
                guard let next = minute(value) else { throw ValidationError.invalidData }
                if next < previous {
                    // 심야 꼬리편만 다음 운행일로 넘깁니다. 잘못 정렬된 낮 시간표는 거절합니다.
                    try require(!rollover && previous >= 18 * 60 && next < 4 * 60)
                    rollover = true
                }
                if rollover { try require(next < 4 * 60) }
                previous = next
            }
        }
        func validateTable(_ table: Timetable) throws {
            try validateTimes(table.weekday)
            try validateTimes(table.weekend)
        }
        func coordinate(_ lat: Double, _ lng: Double) -> Bool {
            lat.isFinite && lng.isFinite && (-90...90).contains(lat) && (-180...180).contains(lng)
        }
        try require(meta.version > 0 && validDate(meta.updatedAt))
        try require(holidays.count <= 1000 && Set(holidays).count == holidays.count && holidays.allSatisfy(validDate))
        try require((meta.noticeMessage?.count ?? 0) <= 4000)
        if let routes {
            try require(Set(routes.keys) == Set(RouteDirection.allCases.map(\.rawValue)))
            for route in routes.values {
                try require(!route.name.isEmpty && route.durationMinutes > 0 && route.durationMinutes <= 1440 && route.fare >= 0)
                try require(route.nightFare.map { $0 >= 0 } ?? true)
                try require(route.nightFareStartTime.map { minute($0) != nil } ?? true)
                try validateTable(route.timetable)
                let times = Set(route.timetable.weekday + route.timetable.weekend)
                try require(route.viaTimes?.allSatisfy { times.contains($0) } ?? true)
                try require(!route.stops.isEmpty && route.stops.count <= 100 && Set(route.stops.map(\.id)).count == route.stops.count)
                try require(route.stops.filter(\.isDeparture).count == 1)
                for stop in route.stops {
                    try require(!stop.id.isEmpty && !stop.name.isEmpty)
                    switch (stop.latitude, stop.longitude) {
                    case let (.some(lat), .some(lng)): try require(coordinate(lat, lng))
                    case (.none, .none): break
                    default: throw ValidationError.invalidData
                    }
                }
                if let path = route.path {
                    try require(path.count >= 2 && path.count <= 50000)
                    for point in path { try require(point.count == 2 && coordinate(point[0], point[1])) }
                }
            }
        } else {
            try require(!requireRoutes)
            guard let timetable else { throw ValidationError.invalidData }
            try validateTable(timetable)
        }
    }

    static func validatedDecode(_ bytes: Data) throws -> TimetableData {
        guard bytes.count <= 2_000_000 else { throw ValidationError.invalidData }
        let decoded = try JSONDecoder().decode(Self.self, from: bytes)
        try decoded.validate()
        return decoded
    }
}
