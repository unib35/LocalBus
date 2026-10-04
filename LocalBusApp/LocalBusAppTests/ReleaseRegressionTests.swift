import Foundation
import Testing
import UserNotifications
@testable import JangyuBus

@Suite("출시 알림 회귀")
struct ReleaseNotificationTests {
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text + "+09:00")! }

    @Test func 지난예약은_다음날로넘기지않음() {
        let departure = date("2026-09-18T06:20:00")
        for now in ["2026-09-18T06:18:00", "2026-09-18T06:15:00", "2026-09-18T06:20:00", "2026-09-18T06:21:00"] {
            #expect(throws: (any Error).self) {
                try NotificationService.reminderComponents(departure: departure, minutesBefore: 5, now: date(now))
            }
        }
    }

    @Test func 자정편_날짜와한국시간대를보존() throws {
        let departure = date("2026-09-19T00:10:00")
        let components = try NotificationService.reminderComponents(departure: departure, minutesBefore: 30, now: date("2026-09-18T23:00:00"))
        #expect(components.day == 18)
        #expect(components.hour == 23)
        #expect(components.minute == 40)
        #expect(components.timeZone?.identifier == "Asia/Seoul")
        #expect(components.date == date("2026-09-18T23:40:00"))
    }

    @Test func 노선과날짜가다르면_예약ID도다름() {
        let today = date("2026-09-18T07:00:00")
        let tomorrow = date("2026-09-19T07:00:00")
        let keys = [
            NotificationService.busNotificationIdentifier(departure: today, direction: .jangyuToSasang, minutesBefore: 5),
            NotificationService.busNotificationIdentifier(departure: today, direction: .sasangToJangyu, minutesBefore: 5),
            NotificationService.busNotificationIdentifier(departure: tomorrow, direction: .jangyuToSasang, minutesBefore: 5)
        ]
        #expect(Set(keys).count == 3)
    }

    @Test @MainActor func 다른요일조회는예약불가_홈은실제운행일사용() {
        let model = MainViewModel()
        model.weekdayTimes = ["06:00", "00:10"]
        model.weekendTimes = ["07:00", "23:00"]
        model.selectedScheduleType = .weekend
        let now = date("2026-09-18T23:55:00")
        #expect(model.notificationDeparture(for: "07:00", now: now) == nil)
        #expect(model.notificationDeparture(for: "00:10", useSelectedSchedule: false, now: now)?.date == date("2026-09-19T00:10:00"))
    }
    @Test @MainActor func 예약실패와권한거부는_성공상태를남기지않음() async {
        let model = MainViewModel()
        model.weekdayTimes = ["12:00"]
        model.weekendTimes = ["12:00"]
        let now = date("2099-09-18T11:00:00")
        let mock = FailingNotificationScheduler()
        let result = await model.toggleNotification(for: "12:00", useSelectedSchedule: false, now: now, notificationService: mock)
        guard case .failed = result else { Issue.record("예약 실패를 성공으로 처리함"); return }
        #expect(model.scheduledNotifications.isEmpty)
        mock.granted = false
        let denied = await model.toggleNotification(for: "12:00", useSelectedSchedule: false, now: now, notificationService: mock)
        guard case .denied = denied else { Issue.record("권한 거부가 구분되지 않음"); return }
        #expect(model.scheduledNotifications.isEmpty)
    }

    @Test @MainActor func 양방향같은시각을_독립예약하고취소() async {
        let model = MainViewModel()
        model.weekdayTimes = ["12:00"]
        model.weekendTimes = ["12:00"]
        let now = date("2099-09-18T11:00:00")
        let mock = FailingNotificationScheduler()
        mock.shouldFail = false
        model.selectedDirection = .jangyuToSasang
        let outbound = await model.toggleNotification(for: "12:00", useSelectedSchedule: false, now: now, notificationService: mock)
        guard case .scheduled = outbound else { Issue.record("첫 방향 예약 실패"); return }
        model.selectedDirection = .sasangToJangyu
        let inbound = await model.toggleNotification(for: "12:00", useSelectedSchedule: false, now: now, notificationService: mock)
        guard case .scheduled = inbound else { Issue.record("반대 방향 예약 충돌"); return }
        #expect(mock.keys.count == 2)
        let cancelled = await model.toggleNotification(for: "12:00", useSelectedSchedule: false, now: now, notificationService: mock)
        guard case .cancelled = cancelled else { Issue.record("취소 실패"); return }
        #expect(mock.keys.count == 1)
        #expect(mock.keys.first?.contains("jangyu_to_sasang") == true)
        #expect(model.scheduledNotifications == mock.keys)
    }

}

@Suite("출시 데이터 방어")
struct ReleaseDataValidationTests {
    private func bundledJSON() throws -> [String: Any] {
        let url = try #require(Bundle.main.url(forResource: "timetable", withExtension: "json"))
        return try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }
    private func decode(_ json: [String: Any]) throws -> TimetableData {
        try TimetableData.validatedDecode(JSONSerialization.data(withJSONObject: json))
    }

    @Test func 번들유효() throws { _ = try decode(bundledJSON()) }

    @Test func 빈노선_누락노선_빈시간표거부() throws {
        var json = try bundledJSON()
        json["routes"] = [:] as [String: Any]
        #expect(throws: (any Error).self) { try decode(json) }
        json = try bundledJSON()
        var routes = try #require(json["routes"] as? [String: Any])
        routes.removeValue(forKey: "sasang_to_jangyu")
        json["routes"] = routes
        #expect(throws: (any Error).self) { try decode(json) }
    }

    @Test func 잘못된시각_정렬_좌표_음수요금거부() throws {
        for invalid in [["24:00"], ["06:00", "06:00"], ["10:00", "09:00"], ["23:00", "00:10", "23:10", "00:20"], []] {
            var json = try bundledJSON()
            var routes = try #require(json["routes"] as? [String: [String: Any]])
            routes["jangyu_to_sasang"]?["timetable"] = ["weekday": invalid, "weekend": ["07:00"]]
            json["routes"] = routes
            #expect(throws: (any Error).self) { try decode(json) }
        }
        for change in ([["fare": -1], ["duration_minutes": 0], ["path": [[91.0, 128.0], [35.0, 128.0]]]] as [[String: Any]]) {
            var json = try bundledJSON()
            var routes = try #require(json["routes"] as? [String: [String: Any]])
            for (key, value) in change { routes["jangyu_to_sasang"]?[key] = value }
            json["routes"] = routes
            #expect(throws: (any Error).self) { try decode(json) }
        }
    }

    @Test func 불량캐시는정상번들로복구_저장시정상본보존() throws {
        let suite = "release-validation-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = TimetableService(cacheKey: "fixture", defaults: defaults)
        let valid = try decode(bundledJSON())
        service.saveToCache(valid)
        let invalid = TimetableData(meta: Meta(version: 999, updatedAt: "2026-09-18", noticeMessage: nil, contactEmail: "test@example.com"), holidays: [], timetable: nil, routes: [:])
        service.saveToCache(invalid)
        #expect(service.loadCachedData()?.meta.version == valid.meta.version)
        defaults.set(try JSONEncoder().encode(invalid), forKey: "fixture")
        #expect(service.loadInitialData()?.meta.version == valid.meta.version)
    }
}

private final class FailingNotificationScheduler: BusNotificationScheduling {
    var granted = true
    var shouldFail = true
    var keys: Set<String> = []
    func requestAuthorization() async -> Bool { granted }
    func scheduledBusNotificationKeys() async -> Set<String> { keys }
    func cancelNotification(identifier: String) { keys.remove(identifier) }
    func scheduleBusNotification(departure: TimetableTimeline.Departure, minutesBefore: Int, direction: RouteDirection) async throws {
        if shouldFail { throw NotificationService.ScheduleError.invalidTime }
        keys.insert(NotificationService.busNotificationIdentifier(departure: departure.date, direction: direction, minutesBefore: minutesBefore))
    }
}
