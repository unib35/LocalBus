import Testing
import Foundation
@testable import LocalBusApp

struct TimetableDataTests {

    // MARK: - 기존 JSON 디코딩 테스트 (하위호환)

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
        #expect(data.timetable?.weekday == ["06:00", "06:20", "06:40"])
        #expect(data.timetable?.weekend == ["06:30", "07:00", "07:30"])
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

    // MARK: - 양방향 노선 테스트

    @Test func RouteDirection_displayName_올바른값_반환() {
        // Given & When & Then
        #expect(RouteDirection.jangyuToSasang.displayName == "장유 → 사상")
        #expect(RouteDirection.sasangToJangyu.displayName == "사상 → 장유")
    }

    @Test func BusStop_디코딩_성공() throws {
        // Given
        let json = """
        {
            "id": "gapeul_hospital",
            "name": "갑을장유병원",
            "description": "출발지",
            "is_departure": true
        }
        """.data(using: .utf8)!

        // When
        let stop = try JSONDecoder().decode(BusStop.self, from: json)

        // Then
        #expect(stop.id == "gapeul_hospital")
        #expect(stop.name == "갑을장유병원")
        #expect(stop.description == "출발지")
        #expect(stop.isDeparture == true)
    }

    @Test func BusStop_description_없을때_디코딩_성공() throws {
        // Given
        let json = """
        {
            "id": "sasang",
            "name": "사상",
            "is_departure": false
        }
        """.data(using: .utf8)!

        // When
        let stop = try JSONDecoder().decode(BusStop.self, from: json)

        // Then
        #expect(stop.id == "sasang")
        #expect(stop.description == nil)
    }

    @Test func RouteData_디코딩_성공() throws {
        // Given
        let json = """
        {
            "name": "장유 → 사상",
            "duration_minutes": 40,
            "fare": 3200,
            "stops": [
                {
                    "id": "gapeul_hospital",
                    "name": "갑을장유병원",
                    "description": "출발지",
                    "is_departure": true
                }
            ],
            "timetable": {
                "weekday": ["06:00", "06:30"],
                "weekend": ["07:00", "07:30"]
            }
        }
        """.data(using: .utf8)!

        // When
        let route = try JSONDecoder().decode(RouteData.self, from: json)

        // Then
        #expect(route.name == "장유 → 사상")
        #expect(route.durationMinutes == 40)
        #expect(route.fare == 3200)
        #expect(route.stops.count == 1)
        #expect(route.stops.first?.name == "갑을장유병원")
        #expect(route.timetable.weekday == ["06:00", "06:30"])
    }

    @Test func TimetableData_routes포함_디코딩_성공() throws {
        // Given
        let json = """
        {
            "meta": {
                "version": 2,
                "updated_at": "2026-01-14",
                "contact_email": "help@localbus.com"
            },
            "holidays": ["2026-02-09"],
            "routes": {
                "jangyu_to_sasang": {
                    "name": "장유 → 사상",
                    "duration_minutes": 40,
                    "fare": 3200,
                    "stops": [
                        {
                            "id": "gapeul_hospital",
                            "name": "갑을장유병원",
                            "is_departure": true
                        }
                    ],
                    "timetable": {
                        "weekday": ["06:00"],
                        "weekend": ["07:00"]
                    }
                },
                "sasang_to_jangyu": {
                    "name": "사상 → 장유",
                    "duration_minutes": 40,
                    "fare": 3200,
                    "stops": [
                        {
                            "id": "sasang",
                            "name": "사상",
                            "is_departure": true
                        }
                    ],
                    "timetable": {
                        "weekday": ["06:30"],
                        "weekend": ["07:30"]
                    }
                }
            }
        }
        """.data(using: .utf8)!

        // When
        let data = try JSONDecoder().decode(TimetableData.self, from: json)

        // Then
        #expect(data.routes != nil)
        #expect(data.routes?.count == 2)
        #expect(data.routes?["jangyu_to_sasang"]?.name == "장유 → 사상")
        #expect(data.routes?["sasang_to_jangyu"]?.name == "사상 → 장유")
    }

    @Test func TimetableData_하위호환_routes없어도_디코딩_성공() throws {
        // Given - 기존 v1 형식 (routes 없음)
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
        #expect(data.routes == nil)
        #expect(data.timetable != nil)
    }
}
