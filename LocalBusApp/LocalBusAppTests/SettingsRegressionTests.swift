import Testing
import Foundation
import MessageUI
@testable import JangyuBus

@Suite("설정 회귀 검증", .serialized)
struct SettingsRegressionTests {
    @Test func 자정막차_알림은_전날2340() throws {
        let components = try NotificationService.lastBusReminderComponents(for: "00:10")
        #expect(components.hour == 23)
        #expect(components.minute == 40)
        #expect(components.timeZone?.identifier == "Asia/Seoul")
    }

    @Test func 일반막차_30분전() throws {
        let components = try NotificationService.lastBusReminderComponents(for: "19:00")
        #expect(components.hour == 18)
        #expect(components.minute == 30)
    }

    @Test func 잘못된시각은_예약거부() {
        for time in ["--:--", "24:10", "12:60", "-1:40", "12:30:00", "12:bad:30", "12::30"] {
            #expect(throws: (any Error).self) {
                try NotificationService.lastBusReminderComponents(for: time)
            }
        }
    }

    @Test func 메일실패와_임시저장은_완료로안내하지않음() {
        #expect(MailResultNotice.make(result: .failed, error: nil)?.title == "메일 전송 실패")
        #expect(MailResultNotice.make(result: .saved, error: nil)?.title == "임시 저장됨")
        #expect(MailResultNotice.make(result: .cancelled, error: nil) == nil)
    }

    @Test @MainActor func 업데이트확인은_적용전까지_기존시간표유지() async throws {
        let suite = "timetable-update-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = TimetableService(bundleFileName: "isolated-test-no-bundle", defaults: defaults)
        let current = updateFixture(version: 3, time: "08:10")
        let newer = updateFixture(version: 4, time: "08:20")
        service.saveToCache(current)
        let model = MainViewModel()
        await model.onAppear(timetableService: service, networkService: TimetableNetwork(data: newer))
        #expect(model.hasTimetableUpdate)
        #expect(model.weekdayTimes == ["08:10"])
        #expect(service.loadCachedData()?.meta.version == 3)

        // 연결이 끊겨도 이미 확인한 업데이트를 잃지 않습니다.
        await model.checkForTimetableUpdate(timetableService: service, networkService: OfflineNetwork())
        #expect(model.hasTimetableUpdate)
        let result = await model.refresh(timetableService: service, networkService: OfflineNetwork())
        #expect(result == .updated)
        #expect(!model.hasTimetableUpdate)
        #expect(model.weekdayTimes == ["08:20"])
        #expect(service.loadCachedData()?.meta.version == 4)
    }

    @Test @MainActor func 동일시간표는_업데이트표시없음() async throws {
        let suite = "timetable-current-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = TimetableService(bundleFileName: "isolated-test-no-bundle", defaults: defaults)
        let current = updateFixture(version: 3, time: "08:10")
        service.saveToCache(current)
        let model = MainViewModel()
        await model.onAppear(timetableService: service, networkService: TimetableNetwork(data: current))
        #expect(!model.hasTimetableUpdate)
        #expect(model.hasCheckedTimetableUpdate)
        #expect(!model.isOffline)
        let result = await model.refresh(timetableService: service, networkService: TimetableNetwork(data: current))
        #expect(result == .alreadyCurrent)
    }

    @Test func 같은버전내용수정감지_이전버전차단() throws {
        let current = updateFixture(version: 3, time: "08:10")
        #expect(try updateFixture(version: 3, time: "08:20").isUpdate(comparedTo: current))
        #expect(try !updateFixture(version: 2, time: "08:20").isUpdate(comparedTo: current))
        #expect(try !current.isUpdate(comparedTo: current))
    }

    @Test @MainActor func 오프라인새로고침은_최신캐시유지() async throws {
        let suite = "settings-review-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = TimetableService(bundleFileName: "isolated-test-no-bundle", defaults: defaults)
        let cached = TimetableData(meta: Meta(version: 99, updatedAt: "2026-09-12", noticeMessage: nil, contactEmail: "test@example.com"),
                                   holidays: [], timetable: Timetable(weekday: ["08:10"], weekend: ["09:10"]), routes: nil)
        service.saveToCache(cached)
        let model = MainViewModel()
        await model.refresh(timetableService: service, networkService: OfflineNetwork())
        #expect(model.isOffline)
        #expect(model.weekdayTimes == ["08:10"])
        #expect(model.weekendTimes == ["09:10"])
        #expect(service.loadCachedData()?.meta.version == 99)
    }
}

private final class OfflineNetwork: NetworkService {
    override func fetch<T: Decodable>(from url: URL, session: URLSession = .shared) async throws -> T {
        throw NetworkError.requestFailed
    }
}

private func updateFixture(version: Int, time: String) -> TimetableData {
    TimetableData(meta: Meta(version: version, updatedAt: "2026-09-12", noticeMessage: nil, contactEmail: "test@example.com"),
                  holidays: [], timetable: Timetable(weekday: [time], weekend: [time]))
}

private final class TimetableNetwork: NetworkService {
    let data: TimetableData
    init(data: TimetableData) { self.data = data }
    override func fetch<T: Decodable>(from url: URL, session: URLSession = .shared) async throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(data))
    }
}
