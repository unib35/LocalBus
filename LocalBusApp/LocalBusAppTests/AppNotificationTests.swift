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

        let push = AppNotification.from(identifier: "x", title: "t", body: "b", userInfo: ["gcm.message_id": "m1", "notice_id": "n1"], receivedAt: Date())
        #expect(push?.kind == .notice)
        #expect(push?.target == .notice(id: "n1"))

        #expect(AppNotification.from(identifier: "unknown", title: "t", body: "b", userInfo: [:], receivedAt: Date()) == nil)
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
