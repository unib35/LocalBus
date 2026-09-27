import Testing
import Foundation
@testable import JangyuBus

struct TimetableUpdateTests {

    @Test func 기준일이_같으면_최신이다() {
        #expect(TimetableUpdateResult.evaluate(current: "2026-03-08", fetched: "2026-03-08") == .latest)
    }

    @Test func 기준일이_다르면_적용됨이다() {
        let result = TimetableUpdateResult.evaluate(current: "2026-03-08", fetched: "2026-09-28")
        #expect(result == .updated(from: "2026-03-08", to: "2026-09-28"))
    }

    @Test func 같은_날_확인이면_오늘로_표시한다() {
        let now = makeKST(year: 2026, month: 9, day: 28, hour: 14, minute: 0)
        let checked = makeKST(year: 2026, month: 9, day: 28, hour: 9, minute: 12)
        #expect(LastCheckedFormatter.text(for: checked, now: now) == "오늘 09:12")
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
