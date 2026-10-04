import Foundation
import Testing
@testable import JangyuBus

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
