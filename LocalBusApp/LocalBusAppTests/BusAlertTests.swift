import Testing
import Foundation
@testable import JangyuBus

struct BusAlertTests {

    @Test func 알림_시각은_출발에서_lead를_뺀_값이다() {
        let alert = BusAlert(busTime: "07:50", direction: .jangyuToSasang, leadMinutes: 10)
        #expect(alert.alertTime == "07:40")
        #expect(alert.detailText == "10분 전 · 07:40에 알림")
        #expect(alert.repeatText == "오늘 한 번")
    }

    @Test func 꺼진_알림은_꺼짐으로_표시한다() {
        let alert = BusAlert(busTime: "18:40", direction: .sasangToJangyu, leadMinutes: 5, repeatsWeekdays: true, isEnabled: false)
        #expect(alert.detailText == "5분 전 · 꺼짐")
        #expect(alert.repeatText == "평일마다 반복")
        #expect(alert.id == "sasang_to_jangyu_18:40")
    }

    @Test func 한_번_알림은_오늘_아직_안_지났으면_오늘_울린다() {
        let now = kst(2026, 9, 28, 7, 0)   // 월요일
        let alert = BusAlert(busTime: "07:50", direction: .jangyuToSasang, leadMinutes: 5)
        let dates = BusAlertScheduler.fireDates(for: alert, from: now, holidays: [])
        #expect(dates == [kst(2026, 9, 28, 7, 45)])
    }

    @Test func 한_번_알림은_이미_지났으면_내일_울린다() {
        let now = kst(2026, 9, 28, 8, 0)
        let alert = BusAlert(busTime: "07:50", direction: .jangyuToSasang, leadMinutes: 5)
        let dates = BusAlertScheduler.fireDates(for: alert, from: now, holidays: [])
        #expect(dates == [kst(2026, 9, 29, 7, 45)])
    }

    @Test func 반복_알림은_주말과_공휴일을_건너뛴다() {
        let now = kst(2026, 9, 25, 9, 0)   // 금요일, 07:15는 이미 지남
        let alert = BusAlert(busTime: "07:20", direction: .jangyuToSasang, leadMinutes: 5, repeatsWeekdays: true)
        let dates = BusAlertScheduler.fireDates(for: alert, from: now, holidays: ["2026-09-28"], count: 3)
        // 9/26 토, 9/27 일, 9/28 공휴일 → 9/29 화, 9/30 수, 10/1 목
        #expect(dates == [kst(2026, 9, 29, 7, 15), kst(2026, 9, 30, 7, 15), kst(2026, 10, 1, 7, 15)])
    }

    @Test func 예약_식별자는_조회_없이_모두_만들_수_있다() {
        let alert = BusAlert(busTime: "07:50", direction: .jangyuToSasang, repeatsWeekdays: true)
        let ids = NotificationService.requestIdentifiers(alertID: alert.id)
        #expect(ids.count == BusAlertScheduler.maxFireDates)
        #expect(ids.first == "alert_jangyu_to_sasang_07:50_0")
        #expect(ids.last == "alert_jangyu_to_sasang_07:50_9")
        // 반복 알림이 거는 예약 수보다 적으면 지우지 못한 예약이 남는다
        let fireDates = BusAlertScheduler.fireDates(for: alert, from: kst(2026, 9, 28, 6, 0), holidays: [])
        #expect(fireDates.count <= ids.count)
    }

    @Test func 저장하고_다시_읽을_수_있다() {
        let defaults = UserDefaults(suiteName: "BusAlertTests")!
        defaults.removePersistentDomain(forName: "BusAlertTests")
        let store = BusAlertStore(defaults: defaults)

        let alerts = [
            BusAlert(busTime: "07:50", direction: .jangyuToSasang),
            BusAlert(busTime: "18:40", direction: .sasangToJangyu, leadMinutes: 15, repeatsWeekdays: true, isEnabled: false),
        ]
        store.save(alerts)

        #expect(store.load() == alerts)
    }

    private func kst(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }
}
