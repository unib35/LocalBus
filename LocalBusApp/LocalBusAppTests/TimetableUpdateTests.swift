import Testing
import Foundation
@testable import JangyuBus

struct TimetableUpdateTests {

    @Test func 기준일이_같으면_최신이다() {
        #expect(TimetableUpdateResult.evaluate(current: "2026-03-08", fetched: "2026-03-08") == .latest)
    }

    @Test func 기준일이_다르면_적용됨이다() {
        let result = TimetableUpdateResult.evaluate(current: "2026-03-08", fetched: "2026-09-28")
        #expect(result == .updated(from: "2026-03-08", to: "2026-09-28", changes: []))
    }

    @Test func 바뀐_시각을_첫차_막차_일반으로_구분해_요약한다() {
        let old = makeData(weekday: ["06:20", "07:20", "23:30"], weekend: ["07:00", "23:00"])
        let new = makeData(weekday: ["06:20", "07:25", "23:40"], weekend: ["07:00", "23:00"])

        let changes = TimetableDiff.changes(old: old, new: new)

        #expect(changes.count == 2)
        #expect(changes[0] == TimetableChange(label: "평일 막차 · 장유 → 사상", oldValue: "23:30", newValue: "23:40"))
        #expect(changes[1] == TimetableChange(label: "평일 · 장유 → 사상", oldValue: "07:20", newValue: "07:25"))
    }

    @Test func 시간표가_같으면_변경이_없다() {
        let data = makeData(weekday: ["06:20"], weekend: ["07:00"])
        #expect(TimetableDiff.changes(old: data, new: data).isEmpty)
    }

    private func makeData(weekday: [String], weekend: [String]) -> TimetableData {
        let route = RouteData(
            name: "장유 → 사상", durationMinutes: 26, fare: 2500, nightFare: nil, nightFareStartTime: nil,
            platformNumber: nil, viaTimes: nil, stops: [], timetable: Timetable(weekday: weekday, weekend: weekend), path: nil
        )
        return TimetableData(
            meta: Meta(version: 1, updatedAt: "2026-01-10", noticeMessage: nil, contactEmail: "a@b.c"),
            holidays: [], timetable: nil,
            routes: [RouteDirection.jangyuToSasang.rawValue: route]
        )
    }

    @Test func 같은_날_확인이면_오늘로_표시한다() {
        let now = makeKST(year: 2026, month: 9, day: 28, hour: 14, minute: 0)
        let checked = makeKST(year: 2026, month: 9, day: 28, hour: 9, minute: 12)
        #expect(LastCheckedFormatter.text(for: checked, now: now) == "오늘 09:12")
    }

    @Test func 받은_알림_본문은_방향을_빼고_두_건까지_보여준다() {
        let changes = [
            TimetableChange(label: "평일 · 장유 → 사상", oldValue: "07:20", newValue: "07:25"),
            TimetableChange(label: "평일 막차 · 장유 → 사상", oldValue: "23:30", newValue: "23:40"),
            TimetableChange(label: "주말 첫차 · 장유 → 사상", oldValue: "06:30", newValue: "06:40")
        ]
        #expect(changes[0].shortLabel == "평일")
        #expect(changes[1].shortLabel == "평일 막차")
        #expect(TimetableDiff.summaryText(for: changes) == "평일 07:20 → 07:25 · 평일 막차 23:30 → 23:40")
        #expect(TimetableDiff.summaryText(for: []) == nil)
    }

    @Test func 일분_안에_확인했으면_방금으로_표시한다() {
        let now = makeKST(year: 2026, month: 9, day: 28, hour: 14, minute: 0)
        #expect(LastCheckedFormatter.text(for: now.addingTimeInterval(-20), now: now) == "방금")
        #expect(LastCheckedFormatter.text(for: now.addingTimeInterval(-59), now: now) == "방금")
        #expect(LastCheckedFormatter.text(for: now.addingTimeInterval(-60), now: now) == "오늘 13:59")
    }

    @Test func 다른_날_확인이면_날짜를_표시한다() {
        let now = makeKST(year: 2026, month: 9, day: 28, hour: 14, minute: 0)
        let checked = makeKST(year: 2026, month: 9, day: 25, hour: 18, minute: 5)
        #expect(LastCheckedFormatter.text(for: checked, now: now) == "9월 25일 18:05")
    }

    @Test func notices_배열이_있으면_디코딩된다() throws {
        let json = """
        {
          "meta": {"version": 1, "updated_at": "2026-01-10", "notice_message": null, "contact_email": "a@b.c"},
          "holidays": [],
          "timetable": {"weekday": ["06:00"], "weekend": ["07:00"]},
          "notices": [
            {"id": "n1", "title": "제목", "date": "2026.01.10", "category": "시간표 변경",
             "body": ["첫 문단", "둘째 문단"],
             "timetable_summary": {"effective_date": "2026.01.20", "departure_label": "장유 출발", "arrival_label": "사상 도착",
                                   "rows": [{"departure": "06:20", "arrival": "06:46", "is_new": true}], "note": "참고"}}
          ]
        }
        """.data(using: .utf8)!

        let data = try JSONDecoder().decode(TimetableData.self, from: json)
        let notices = data.notices ?? []
        #expect(notices.count == 1)
        #expect(notices[0].id == "n1")
        #expect(notices[0].category == "시간표 변경")
        #expect(notices[0].body.count == 2)
        #expect(notices[0].timetableSummary?.rows.first?.isNew == true)

        let item = notices[0].asNoticeItem(isUnread: true)
        #expect(item.title == "제목")
        #expect(item.isNew == true)
        #expect(item.timetableSummary?.effectiveDate == "2026.01.20")
    }

    @Test func notices가_없는_JSON도_디코딩된다() throws {
        let json = """
        {
          "meta": {"version": 1, "updated_at": "2026-01-10", "notice_message": null, "contact_email": "a@b.c"},
          "holidays": [],
          "timetable": {"weekday": ["06:00"], "weekend": ["07:00"]}
        }
        """.data(using: .utf8)!

        let data = try JSONDecoder().decode(TimetableData.self, from: json)
        #expect(data.notices == nil)
    }

    private func makeKST(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
