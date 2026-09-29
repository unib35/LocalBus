import Testing
import Foundation
@testable import JangyuBus

@MainActor
struct AppNotificationTests {

    @Test func 같은_id는_한_번만_기록된다() {
        let store = makeStore()
        let item = AppNotification(id: "a", kind: .bus, title: "t", body: "b", receivedAt: Date())
        #expect(store.record(item) == true)
        #expect(store.record(item) == false)
        #expect(store.items.count == 1)
        #expect(store.unreadCount == 1)
    }

    @Test func 삼십일이_지난_기록은_지워지고_최신순으로_정렬된다() {
        let now = Date()
        let store = makeStore()
        store.record(AppNotification(id: "old", kind: .notice, title: "t", body: "b", receivedAt: now.addingTimeInterval(-31 * 86400)), now: now)
        store.record(AppNotification(id: "recent", kind: .notice, title: "t", body: "b", receivedAt: now.addingTimeInterval(-3600)), now: now)
        store.record(AppNotification(id: "newest", kind: .notice, title: "t", body: "b", receivedAt: now), now: now)
        #expect(store.items.map(\.id) == ["newest", "recent"])
    }

    @Test func 모두_읽음은_읽지_않음을_0으로_만든다() {
        let store = makeStore()
        store.record(AppNotification(id: "a", kind: .bus, title: "t", body: "b", receivedAt: Date()))
        store.record(AppNotification(id: "b", kind: .notice, title: "t", body: "b", receivedAt: Date()))
        store.markRead(id: "a")
        #expect(store.unreadCount == 1)
        store.markAllRead()
        #expect(store.unreadCount == 0)
    }

    @Test func 날짜_라벨은_오늘_어제_그_외로_나뉜다() {
        let now = kst(2026, 9, 28, 14, 0)
        #expect(NotificationHistoryStore.dayLabel(for: kst(2026, 9, 28, 7, 45), now: now) == "오늘")
        #expect(NotificationHistoryStore.dayLabel(for: kst(2026, 9, 27, 23, 0), now: now) == "어제")
        #expect(NotificationHistoryStore.dayLabel(for: kst(2026, 9, 25, 18, 5), now: now) == "9월 25일")
        #expect(NotificationHistoryStore.timeLabel(for: kst(2026, 9, 28, 7, 45)) == "07:45")
    }

    @Test func 시스템_알림_identifier로_종류와_대상을_알아낸다() {
        let bus = AppNotification.from(identifier: "alert_jangyu_to_sasang_07:50_0", title: "t", body: "b", userInfo: [:], receivedAt: Date())
        #expect(bus?.kind == .bus)
        #expect(bus?.target == .bus(direction: .jangyuToSasang, time: "07:50"))

        let last = AppNotification.from(identifier: "last_bus_daily_notification", title: "t", body: "b", userInfo: [:], receivedAt: Date())
        #expect(last?.kind == .lastBus)
        #expect(last?.target == nil)

        let push = AppNotification.from(identifier: "x", title: "t", body: "b", userInfo: ["gcm.message_id": "m1", "notice_id": "n1"], receivedAt: Date())
        #expect(push?.kind == .notice)
        #expect(push?.target == .notice(id: "n1"))

        #expect(AppNotification.from(identifier: "unknown", title: "t", body: "b", userInfo: [:], receivedAt: Date()) == nil)
    }

    // MARK: - 알림 문구 (디자인 캔버스 AlertsHub)

    @Test func 버스_알림_문구는_보드와_같다() {
        #expect(NotificationCopy.busTitle(busTime: "07:50", leadMinutes: 5) == "07:50 버스가 5분 후 출발해요")
        #expect(NotificationCopy.busBody(direction: .jangyuToSasang, platformNumber: nil, boardingStopName: "갑을장유병원정류소") == "장유 → 사상 · 갑을장유병원정류소 승차")
        #expect(NotificationCopy.busBody(direction: .sasangToJangyu, platformNumber: "20번 홈", boardingStopName: "사상터미널") == "사상 → 장유 · 20번 홈 승차")
        #expect(NotificationCopy.busBody(direction: .jangyuToSasang, platformNumber: nil, boardingStopName: nil) == "장유 → 사상")
    }

    @Test func 막차_알림_문구는_보드와_같다() {
        #expect(NotificationCopy.lastBusTitle == "막차가 30분 후 출발해요")
        #expect(NotificationCopy.lastBusBody(direction: .jangyuToSasang, busTime: "23:30", nightFare: 3000) == "장유 → 사상 23:30 · 심야 요금 3,000원")
        #expect(NotificationCopy.lastBusBody(direction: .yulhaToSasang, busTime: "21:00", nightFare: nil) == "율하 → 사상 21:00")
    }

    @Test func 막차_시스템_알림은_방향과_시각으로_버스_상세를_연다() {
        let receivedAt = kst(2026, 9, 28, 23, 0)
        let last = AppNotification.from(
            identifier: "last_bus_daily_notification",
            title: "t",
            body: "b",
            userInfo: ["direction": "jangyu_to_sasang", "bus_time": "23:30"],
            receivedAt: receivedAt
        )
        #expect(last?.kind == .lastBus)
        #expect(last?.target == .bus(direction: .jangyuToSasang, time: "23:30"))
        #expect(last?.id == "lastbus_20260928")
    }

    @Test func 막차_알림은_예약한_뒤에_울린_것만_기록한다() {
        let info = LastBusAlertInfo(direction: .jangyuToSasang, busTime: "23:30", nightFare: 3000, scheduledAt: kst(2026, 9, 27, 12, 0))
        #expect(info.alertTime == "23:00")

        // 아직 오늘 울리기 전: 어제 것만
        #expect(info.firedDates(now: kst(2026, 9, 28, 22, 0)) == [kst(2026, 9, 27, 23, 0)])
        // 오늘 울린 뒤: 오늘과 어제
        #expect(info.firedDates(now: kst(2026, 9, 28, 23, 10)) == [kst(2026, 9, 28, 23, 0), kst(2026, 9, 27, 23, 0)])
        // 예약하기 전에 지나간 시각은 기록하지 않는다
        let late = LastBusAlertInfo(direction: .jangyuToSasang, busTime: "23:30", nightFare: nil, scheduledAt: kst(2026, 9, 28, 23, 5))
        #expect(late.firedDates(now: kst(2026, 9, 28, 23, 10)).isEmpty)
    }

    @Test func 자정을_넘는_막차는_전날_밤에_울린다() {
        let info = LastBusAlertInfo(direction: .sasangToJangyu, busTime: "00:10", nightFare: 3000, scheduledAt: kst(2026, 9, 27, 12, 0))
        #expect(info.alertTime == "23:40")
        #expect(info.firedDates(now: kst(2026, 9, 28, 9, 0)) == [kst(2026, 9, 27, 23, 40)])
    }

    @Test func 막차_기록은_시스템_알림과_같은_id를_쓴다() {
        let info = LastBusAlertInfo(direction: .jangyuToSasang, busTime: "23:30", nightFare: 3000, scheduledAt: kst(2026, 9, 27, 12, 0))
        let item = info.historyItem(firedAt: kst(2026, 9, 28, 23, 0))
        #expect(item.id == "lastbus_20260928")
        #expect(item.kind == .lastBus)
        #expect(item.title == "막차가 30분 후 출발해요")
        #expect(item.body == "장유 → 사상 23:30 · 심야 요금 3,000원")
        #expect(item.target == .bus(direction: .jangyuToSasang, time: "23:30"))
    }

    private func makeStore() -> NotificationHistoryStore {
        let defaults = UserDefaults(suiteName: "AppNotificationTests")!
        defaults.removePersistentDomain(forName: "AppNotificationTests")
        return NotificationHistoryStore(defaults: defaults)
    }

    private func kst(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }
}
