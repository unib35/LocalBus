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

    enum CodingKeys: String, CodingKey {
        case name, stops, timetable, fare
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

    init(meta: Meta, holidays: [String], timetable: Timetable?, routes: [String: RouteData]? = nil) {
        self.meta = meta
        self.holidays = holidays
        self.timetable = timetable
        self.routes = routes
    }
}

/// 메타 정보
struct Meta: Codable {
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

/// 시간표 (평일/주말)
struct Timetable: Codable, Equatable {
    let weekday: [String]
    let weekend: [String]

    init(weekday: [String], weekend: [String]) {
        self.weekday = weekday
        self.weekend = weekend
    }
}
