import Testing
import Foundation
@testable import JangyuBus

/// 제보 시트의 '지금 앱에 나온 정보'
struct QuickReportContextTests {

    private func makeInfo(estimate: ArrivalEstimate?, scheduleTypeLabel: String = "평일") -> BusDetailInfo {
        BusDetailInfo(
            departureTime: "18:30",
            arrivalTime: "18:56",
            durationMinutes: 26,
            isVia: false,
            isNightFare: false,
            fare: 2500,
            nightFare: 3000,
            platformNumber: nil,
            stops: [],
            direction: .jangyuToSasang,
            directionDisplayName: "장유 → 사상",
            scheduleTypeLabel: scheduleTypeLabel,
            nightFareStartTime: "22:10",
            isNotificationEnabled: false,
            estimate: estimate
        )
    }

    @Test func 제보_소요시간은_상세에_보이는_도착_예상과_같다() {
        let estimate = ArrivalEstimate(departureTime: "18:30", arrivalTime: "19:04", durationMinutes: 34, basis: .live(updatedAt: Date()))
        let context = QuickReportContext(entry: .duration, info: makeInfo(estimate: estimate))
        #expect(context.shownText(for: .duration) == "34분 · 19:04 사상 도착 예상")
    }

    @Test func 도착_예상이_없으면_기본_소요시간을_보여준다() {
        let context = QuickReportContext(entry: .duration, info: makeInfo(estimate: nil))
        #expect(context.shownText(for: .duration) == "26분 · 18:56 사상 도착 예상")
    }

    @Test func 주말_버스는_시간표_세그먼트와_같은_표기를_쓴다() {
        let context = QuickReportContext(entry: .time, info: makeInfo(estimate: nil, scheduleTypeLabel: "주말 · 공휴일"))
        #expect(context.contextText == "장유 → 사상 · 주말 · 공휴일 18:30 버스")
        #expect(context.shownText(for: .time) == "주말 · 공휴일 18:30 출발 · 직행")
    }
}
