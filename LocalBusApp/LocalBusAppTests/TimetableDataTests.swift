import Testing
import Foundation
@testable import LocalBusApp

struct TimetableDataTests {

    // MARK: - JSON 디코딩 테스트

    @Test func validJSON_디코딩_성공() throws {
        // Given
        let json = """
        {
            "meta": {
                "version": 1,
                "updated_at": "2026-01-10",
                "notice_message": "공지 메시지",
                "contact_email": "help@localbus.com"
            },
            "holidays": ["2026-02-09", "2026-02-10"],
            "timetable": {
                "weekday": ["06:00", "06:20", "06:40"],
                "weekend": ["06:30", "07:00", "07:30"]
            }
        }
        """.data(using: .utf8)!

        // When
        let data = try JSONDecoder().decode(TimetableData.self, from: json)

        // Then
        #expect(data.meta.version == 1)
        #expect(data.meta.updatedAt == "2026-01-10")
        #expect(data.meta.noticeMessage == "공지 메시지")
        #expect(data.meta.contactEmail == "help@localbus.com")
        #expect(data.holidays == ["2026-02-09", "2026-02-10"])
        #expect(data.timetable.weekday == ["06:00", "06:20", "06:40"])
        #expect(data.timetable.weekend == ["06:30", "07:00", "07:30"])
    }

    @Test func noticeMessage_없는_JSON_디코딩_성공() throws {
        // Given
        let json = """
        {
            "meta": {
                "version": 1,
                "updated_at": "2026-01-10",
                "contact_email": "help@localbus.com"
            },
            "holidays": [],
            "timetable": {
                "weekday": ["06:00"],
                "weekend": ["07:00"]
            }
        }
        """.data(using: .utf8)!

        // When
        let data = try JSONDecoder().decode(TimetableData.self, from: json)

        // Then
        #expect(data.meta.noticeMessage == nil)
    }

    @Test func 빈_holidays_디코딩_성공() throws {
        // Given
        let json = """
        {
            "meta": {
                "version": 1,
                "updated_at": "2026-01-10",
                "contact_email": "help@localbus.com"
            },
            "holidays": [],
            "timetable": {
                "weekday": ["06:00"],
                "weekend": ["07:00"]
            }
        }
        """.data(using: .utf8)!

        // When
        let data = try JSONDecoder().decode(TimetableData.self, from: json)

        // Then
        #expect(data.holidays.isEmpty)
    }
}
