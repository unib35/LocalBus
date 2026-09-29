import Testing
import Foundation
@testable import JangyuBus

struct BusDetailInfoTests {

    private func makeInfo(
        departure: String = "18:30",
        minutesUntil: Int? = nil,
        isTomorrow: Bool = false,
        estimate: ArrivalEstimate? = nil
    ) -> BusDetailInfo {
        BusDetailInfo(
            departureTime: departure,
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
            scheduleTypeLabel: "평일",
            nightFareStartTime: "22:10",
            isNotificationEnabled: false,
            estimate: estimate,
            minutesUntilDeparture: minutesUntil,
            lastTrafficAt: nil,
            isTomorrow: isTomorrow
        )
    }

    // MARK: - 헤더 오른쪽 위 한 줄

    @Test func 곧_출발하는_버스는_남은_시간을_말한다() {
        #expect(makeInfo(minutesUntil: 12).untilText == "12분 후 출발")
        #expect(makeInfo(minutesUntil: 0).untilText == "곧 출발")
        #expect(makeInfo(minutesUntil: 72).untilText == "1시간 12분 후 출발")
        #expect(makeInfo(minutesUntil: 120).untilText == "2시간 후 출발")
    }

    @Test func 내일_버스는_내일_출발_시각을_말한다() {
        let info = makeInfo(departure: "06:20", isTomorrow: true)
        #expect(info.untilText == "내일 06:20 출발")
        #expect(info.isUpcomingToday == false)
    }

    @Test func 지난_버스와_오늘이_아닌_시간표는_남은_시간이_없다() {
        #expect(makeInfo(minutesUntil: -5).untilText == nil)
        #expect(makeInfo(minutesUntil: nil).untilText == nil)
    }

    // MARK: - 교통 반영 시작 안내

    @Test func 먼_시간대는_교통_반영_시작_시각을_알려준다() {
        #expect(makeInfo(departure: "18:30", minutesUntil: 90).trafficStartText == "17:30부터 교통 반영")
        #expect(makeInfo(departure: "06:20", isTomorrow: true).trafficStartText == "내일 05:20부터 교통 반영")
    }

    @Test func 자정_직후_내일_버스는_전날_밤부터_교통을_반영한다() {
        #expect(makeInfo(departure: "00:10", isTomorrow: true).trafficStartText == "23:10부터 교통 반영")
    }

    @Test func 오늘_운행하지_않는_시간표는_시작_시각을_말하지_않는다() {
        let info = makeInfo(minutesUntil: nil)
        #expect(info.trafficStartText == nil)
        #expect(info.isBeforeTrafficWindow == true)
    }

    @Test func 한시간_이내이거나_지난_버스는_시작_안내가_없다() {
        #expect(makeInfo(minutesUntil: 60).trafficStartText == nil)
        #expect(makeInfo(minutesUntil: 12).trafficStartText == nil)
        #expect(makeInfo(minutesUntil: -3).trafficStartText == nil)
    }

    @Test func 새로고침은_오늘_한시간_이내_버스에만_보인다() {
        #expect(makeInfo(minutesUntil: 12).canRefreshTraffic == true)
        #expect(makeInfo(minutesUntil: 60).canRefreshTraffic == true)
        #expect(makeInfo(minutesUntil: 61).canRefreshTraffic == false)
        #expect(makeInfo(minutesUntil: -1).canRefreshTraffic == false)
        #expect(makeInfo(minutesUntil: nil).canRefreshTraffic == false)
        #expect(makeInfo(departure: "06:20", isTomorrow: true).canRefreshTraffic == false)
    }
}
