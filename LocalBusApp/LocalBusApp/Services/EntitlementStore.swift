import Foundation

/// 메인 앱과 위젯이 공유하는 Pro 권한 저장소
///
/// App Group `group.kr.co.lee.jangyusasang`을 통해 UserDefaults를 공유한다.
/// - 메인 앱: 구매/복원 시 `setPro(_:)` 호출로 갱신
/// - 위젯: `isPro` 읽기 전용으로 사용
struct EntitlementStore {

    // MARK: - Constants

    static let appGroupID = "group.kr.co.lee.jangyusasang"
    private static let proKey = "entitlement.isPro"

    /// 원격에서 받은 시간표 캐시 키.
    /// 메인 앱(`TimetableService`)이 App Group에 저장하고, 위젯이 읽는다.
    /// 두 타깃이 같은 키를 써야 하므로 공유 위치인 여기에 둔다.
    static let timetableCacheKey = "cached_timetable_data"

    /// 메인 앱과 위젯이 공유하는 App Group UserDefaults.
    /// App Group 미설정 시 standard로 폴백한다(개발 중 안전장치).
    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    // MARK: - Shared Instance

    static let shared = EntitlementStore()

    // MARK: - Properties

    private let defaults: UserDefaults

    // MARK: - Initialization

    init(suiteName: String = EntitlementStore.appGroupID) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            // App Group이 설정되지 않은 경우 standard로 폴백 (개발 중 안전장치)
            self.defaults = .standard
            return
        }
        self.defaults = defaults
    }

    // MARK: - 교통 소요시간 공유 (앱 → 위젯)

    /// 앱이 받은 교통 소요시간을 위젯이 "교통 반영" 도착 예상에 쓰도록 공유한다.
    struct SharedTrafficSnapshot: Codable {
        let durationMinutes: Int
        let updatedAt: Date

        /// 20분이 지나면 위젯은 시간표 기준으로 돌아간다.
        var isFresh: Bool { Date().timeIntervalSince(updatedAt) < 20 * 60 }
    }

    static func trafficKey(for routeKey: String) -> String { "traffic.\(routeKey)" }

    static func saveTraffic(routeKey: String, durationMinutes: Int, updatedAt: Date) {
        let snapshot = SharedTrafficSnapshot(durationMinutes: durationMinutes, updatedAt: updatedAt)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        sharedDefaults.set(data, forKey: trafficKey(for: routeKey))
    }

    static func loadTraffic(routeKey: String) -> SharedTrafficSnapshot? {
        guard let data = sharedDefaults.data(forKey: trafficKey(for: routeKey)),
              let snapshot = try? JSONDecoder().decode(SharedTrafficSnapshot.self, from: data) else { return nil }
        return snapshot
    }

    // MARK: - Pro Entitlement

    var isPro: Bool {
        defaults.bool(forKey: Self.proKey)
    }

    func setPro(_ value: Bool) {
        defaults.set(value, forKey: Self.proKey)
    }
}
