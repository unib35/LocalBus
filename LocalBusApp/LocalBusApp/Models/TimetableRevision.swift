import Foundation

/// 앱·위젯이 번들과 캐시의 최신 여부를 같은 기준으로 판단합니다.
struct TimetableRevision: Codable, Comparable {
    let version: Int
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case version
        case updatedAt = "updated_at"
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.version != rhs.version { return lhs.version < rhs.version }
        return lhs.updatedAt < rhs.updatedAt
    }
}
