import Foundation

/// 시간표 데이터 전체 구조
struct TimetableData: Codable {
    let meta: Meta
    let holidays: [String]
    let timetable: Timetable
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
}

/// 시간표 (평일/주말)
struct Timetable: Codable {
    let weekday: [String]
    let weekend: [String]
}
