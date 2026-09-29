import Testing
import Foundation
@testable import JangyuBus

struct OperationsInfoTests {

    private let route = RouteDirection.jangyuToSasang.rawValue

    @Test func ops가_없는_JSON도_디코딩된다() throws {
        let json = """
        {
          "meta": {"version": 1, "updated_at": "2026-03-08", "notice_message": null, "contact_email": "a@b.c"},
          "holidays": [],
          "timetable": {"weekday": ["06:00"], "weekend": ["07:00"]}
        }
        """.data(using: .utf8)!
        let data = try JSONDecoder().decode(TimetableData.self, from: json)
        #expect(data.ops == nil)
    }

    @Test func ops_필드를_디코딩한다() throws {
        let json = """
        {
          "meta": {"version": 1, "updated_at": "2026-03-08", "notice_message": null, "contact_email": "a@b.c"},
          "holidays": [],
          "timetable": {"weekday": ["06:00"], "weekend": ["07:00"]},
          "ops": {
            "closure": {"date": "2026-10-02", "title": "오늘 22:10 이후 버스는 운행하지 않아요", "reason": "도로 공사", "last_bus": "21:40"},
            "change": {"effective_date": "2026-10-01", "title": "10월 1일부터 시간표가 바뀌어요", "notice_id": "notice-002"},
            "maintenance": {"active": true, "message": "새 시간표 확인을 잠시 멈췄어요"},
            "min_app_version": "1.2",
            "recommended_app_version": "1.3",
            "update_message": "도착 예상이 더 정확해졌어요"
          }
        }
        """.data(using: .utf8)!
        let data = try JSONDecoder().decode(TimetableData.self, from: json)
        let ops = try #require(data.ops)
        #expect(ops.closure?.lastBus == "21:40")
        #expect(ops.closure?.routeKeys == nil)
        #expect(ops.change?.noticeID == "notice-002")
        #expect(ops.maintenance?.active == true)
        #expect(ops.minAppVersion == "1.2")
        #expect(ops.recommendedAppVersion == "1.3")
    }

    @Test func 운휴가_오늘이면_운휴_배너가_가장_먼저다() {
        let ops = OperationsInfo(
            closure: .init(date: "2026-10-02", title: "오늘 22:10 이후 버스는 운행하지 않아요", reason: "도로 공사", lastBus: "21:40", routeKeys: nil),
            change: .init(effectiveDate: "2026-10-05", title: "변경", noticeID: nil),
            maintenance: .init(active: true, message: nil)
        )
        let banner = OperationsEvaluator.banner(ops: ops, routeKey: route, now: kst(2026, 10, 2, 9), lastUpdateCheckAt: nil, updatedAt: "2026-03-08")
        #expect(banner == .closure(title: "오늘 22:10 이후 버스는 운행하지 않아요", subtitle: "막차 21:40 · 도로 공사"))
        #expect(banner?.actionTitle == nil)
        #expect(banner?.isWarning == true)
    }

    @Test func 운휴는_날짜와_노선이_맞을_때만() {
        let ops = OperationsInfo(closure: .init(date: "2026-10-02", title: "운휴", reason: nil, lastBus: nil, routeKeys: ["yulha_to_sasang"]))
        #expect(OperationsEvaluator.banner(ops: ops, routeKey: route, now: kst(2026, 10, 2, 9), lastUpdateCheckAt: nil, updatedAt: "2026-03-08") == nil)
        #expect(OperationsEvaluator.banner(ops: ops, routeKey: "yulha_to_sasang", now: kst(2026, 10, 3, 9), lastUpdateCheckAt: nil, updatedAt: "2026-03-08") == nil)
        #expect(OperationsEvaluator.banner(ops: ops, routeKey: "yulha_to_sasang", now: kst(2026, 10, 2, 9), lastUpdateCheckAt: nil, updatedAt: "2026-03-08")?.title == "운휴")
    }

    @Test func 변경_예고는_시행일까지만_보인다() {
        let ops = OperationsInfo(change: .init(effectiveDate: "2026-10-01", title: "10월 1일부터 시간표가 바뀌어요", noticeID: "n2"))
        let before = OperationsEvaluator.banner(ops: ops, routeKey: route, now: kst(2026, 9, 29, 9), lastUpdateCheckAt: Date(), updatedAt: "2026-03-08")
        #expect(before == .change(title: "10월 1일부터 시간표가 바뀌어요", noticeID: "n2"))
        #expect(before?.subtitle == "바뀌는 시각 미리 보기")
        let after = OperationsEvaluator.banner(ops: ops, routeKey: route, now: kst(2026, 10, 2, 9), lastUpdateCheckAt: Date(), updatedAt: "2026-03-08")
        #expect(after == nil)
    }

    @Test func 칠일_이상_확인_못하면_오래됨_배너() {
        let now = kst(2026, 9, 29, 9)
        let stale = OperationsEvaluator.banner(ops: nil, routeKey: route, now: now, lastUpdateCheckAt: now.addingTimeInterval(-8 * 86400), updatedAt: "2026-03-08")
        #expect(stale == .stale(baselineText: "3월 8일"))
        #expect(stale?.title == "7일 동안 시간표를 확인하지 못했어요")
        #expect(stale?.subtitle == "3월 8일 기준 · 바뀌었을 수 있어요")
        #expect(stale?.actionTitle == "새로고침")
        #expect(stale?.isWarning == true)

        let fresh = OperationsEvaluator.banner(ops: nil, routeKey: route, now: now, lastUpdateCheckAt: now.addingTimeInterval(-2 * 86400), updatedAt: "2026-03-08")
        #expect(fresh == nil)
        // 한 번도 확인하지 못한 첫 실행에는 띄우지 않는다
        #expect(OperationsEvaluator.banner(ops: nil, routeKey: route, now: now, lastUpdateCheckAt: nil, updatedAt: "2026-03-08") == nil)
    }

    @Test func 점검은_가장_낮은_우선순위다() {
        let now = kst(2026, 9, 29, 9)
        let ops = OperationsInfo(maintenance: .init(active: true, message: nil))
        let banner = OperationsEvaluator.banner(ops: ops, routeKey: route, now: now, lastUpdateCheckAt: now, updatedAt: "2026-03-08")
        #expect(banner == .maintenance(message: "새 시간표 확인을 잠시 멈췄어요"))
        #expect(banner?.subtitle == "저장된 시간표는 그대로 볼 수 있어요")

        let staleWins = OperationsEvaluator.banner(ops: ops, routeKey: route, now: now, lastUpdateCheckAt: now.addingTimeInterval(-10 * 86400), updatedAt: "2026-03-08")
        #expect(staleWins == .stale(baselineText: "3월 8일"))
    }

    @Test func 오프라인_배너는_운휴_다음으로_급하다() {
        let now = kst(2026, 9, 29, 9)
        let change = OperationsInfo(change: .init(effectiveDate: "2026-10-01", title: "변경", noticeID: nil))
        let offline = OperationsEvaluator.banner(ops: change, routeKey: route, now: now, lastUpdateCheckAt: now, updatedAt: "2026-03-08", isOffline: true)
        #expect(offline == .offline(baselineText: "3월 8일"))
        #expect(offline?.title == "연결 없음 · 3월 8일 기준 저장된 시간표를 보여드려요")
        #expect(offline?.actionTitle == "다시 시도")
        #expect(offline?.isCompact == true)

        let closure = OperationsInfo(closure: .init(date: "2026-09-29", title: "운휴", reason: nil, lastBus: nil, routeKeys: nil))
        let closureWins = OperationsEvaluator.banner(ops: closure, routeKey: route, now: now, lastUpdateCheckAt: now, updatedAt: "2026-03-08", isOffline: true)
        #expect(closureWins?.title == "운휴")
    }

    @Test func 평일_공휴일에는_오늘_적용_시간표를_알린다() {
        // 2026-09-28은 월요일
        let monday = kst(2026, 9, 28, 9)
        let holiday = OperationsEvaluator.banner(ops: nil, routeKey: route, now: monday, lastUpdateCheckAt: monday, updatedAt: "2026-03-08", holidays: ["2026-09-28"])
        #expect(holiday == .holiday)
        #expect(holiday?.title == "오늘은 공휴일 · 주말 시간표로 운행해요")
        #expect(holiday?.isCompact == true)
        #expect(holiday?.isWarning == false)
        #expect(holiday?.actionTitle == nil)

        // 주말과 겹친 공휴일, 평일에는 띄우지 않는다
        #expect(OperationsEvaluator.banner(ops: nil, routeKey: route, now: kst(2026, 9, 27, 9), lastUpdateCheckAt: monday, updatedAt: "2026-03-08", holidays: ["2026-09-27"]) == nil)
        #expect(OperationsEvaluator.banner(ops: nil, routeKey: route, now: kst(2026, 9, 29, 9), lastUpdateCheckAt: monday, updatedAt: "2026-03-08", holidays: ["2026-09-28"]) == nil)
    }

    @Test func 공휴일_배너는_변경_예고_다음_오래됨_앞이다() {
        let monday = kst(2026, 9, 28, 9)
        let change = OperationsInfo(change: .init(effectiveDate: "2026-10-01", title: "10월 1일부터 시간표가 바뀌어요", noticeID: nil))
        let changeWins = OperationsEvaluator.banner(ops: change, routeKey: route, now: monday, lastUpdateCheckAt: monday, updatedAt: "2026-03-08", holidays: ["2026-09-28"])
        #expect(changeWins == .change(title: "10월 1일부터 시간표가 바뀌어요", noticeID: nil))

        let holidayWins = OperationsEvaluator.banner(ops: nil, routeKey: route, now: monday, lastUpdateCheckAt: monday.addingTimeInterval(-10 * 86400), updatedAt: "2026-03-08", holidays: ["2026-09-28"])
        #expect(holidayWins == .holiday)
    }

    @Test func 점검_배너는_누를_수_없는_안내다() {
        #expect(OperationsBanner.maintenance(message: "점검").isInteractive == false)
        #expect(OperationsBanner.holiday.isInteractive == false)
        #expect(OperationsBanner.stale(baselineText: "3월 8일").isInteractive)
        #expect(OperationsBanner.stale(baselineText: "3월 8일").showsChevron == false)
        #expect(OperationsBanner.closure(title: "운휴", subtitle: "임시 운휴").showsChevron)
        #expect(OperationsBanner.change(title: "변경", noticeID: nil).showsChevron)
    }

    @Test func 운휴날_운행_요약은_임시_막차를_보여준다() {
        let ops = OperationsInfo(closure: .init(date: "2026-10-02", title: "운휴", reason: nil, lastBus: "21:40", routeKeys: nil))
        let text = OperationsEvaluator.serviceSummaryOverride(ops: ops, routeKey: route, now: kst(2026, 10, 2, 9), firstBusTime: "06:20", lastBusTime: "23:30")
        #expect(text == "첫차 06:20 · 오늘 막차 21:40 (임시) · 평소 막차 23:30")
        #expect(OperationsEvaluator.serviceSummaryOverride(ops: ops, routeKey: route, now: kst(2026, 10, 3, 9), firstBusTime: "06:20", lastBusTime: "23:30") == nil)
    }

    @Test func 버전_비교로_필수_권장_업데이트를_가른다() {
        #expect(OperationsEvaluator.updateRequirement(current: "1.0", min: "1.2", recommended: "1.3") == .required(version: "1.2"))
        #expect(OperationsEvaluator.updateRequirement(current: "1.2", min: "1.2", recommended: "1.3") == .recommended(version: "1.3"))
        #expect(OperationsEvaluator.updateRequirement(current: "1.3", min: "1.2", recommended: "1.3") == .none)
        #expect(OperationsEvaluator.updateRequirement(current: "1.10", min: "1.9", recommended: nil) == .none)
        #expect(OperationsEvaluator.updateRequirement(current: "1.2.1", min: nil, recommended: "1.2") == .none)
        #expect(OperationsEvaluator.updateRequirement(current: "1.0", min: nil, recommended: nil) == .none)
    }

    private func kst(_ y: Int, _ m: Int, _ d: Int, _ h: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }
}
