import Testing
import Foundation
@testable import JangyuBus

struct ArrivalEstimateTests {

    private let updated = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func 출발_1시간_이내면_교통을_반영한다() {
        let estimate = ArrivalEstimator.estimate(
            departureTime: "18:30", minutesUntilDeparture: 12, baseDurationMinutes: 26,
            trafficDurationMinutes: 34, trafficUpdatedAt: updated, isRefreshing: false, isOffline: false, now: updated
        )
        #expect(estimate.arrivalTime == "19:04")
        #expect(estimate.durationMinutes == 34)
        #expect(estimate.basis == .live(updatedAt: updated))
        #expect(estimate.durationText == "예상 소요 34분")
        #expect(estimate.basis.shortLabel == "교통 반영")
    }

    @Test func 먼_시간대는_기본_소요시간으로_계산한다() {
        let estimate = ArrivalEstimator.estimate(
            departureTime: "19:30", minutesUntilDeparture: 72, baseDurationMinutes: 26,
            trafficDurationMinutes: 34, trafficUpdatedAt: updated, isRefreshing: false, isOffline: false, now: updated
        )
        #expect(estimate.arrivalTime == "19:56")
        #expect(estimate.basis == .timetable)
        #expect(estimate.durationText == "기본 소요 26분")
    }

    @Test func 갱신_중에는_기존_예상값을_유지한다() {
        let estimate = ArrivalEstimator.estimate(
            departureTime: "18:30", minutesUntilDeparture: 12, baseDurationMinutes: 26,
            trafficDurationMinutes: 34, trafficUpdatedAt: updated, isRefreshing: true, isOffline: false, now: updated
        )
        #expect(estimate.arrivalTime == "19:04")
        #expect(estimate.basis == .refreshing(updatedAt: updated))
        #expect(estimate.basis.usesTraffic)
    }

    @Test func 교통정보가_없고_오프라인이면_오프라인_기준이다() {
        let estimate = ArrivalEstimator.estimate(
            departureTime: "18:30", minutesUntilDeparture: 12, baseDurationMinutes: 26,
            trafficDurationMinutes: nil, trafficUpdatedAt: nil, isRefreshing: false, isOffline: true, now: updated
        )
        #expect(estimate.arrivalTime == "18:56")
        #expect(estimate.basis == .offline)
        #expect(ArrivalEstimator.statusText(for: estimate.basis) == "오프라인 · 시간표 기준")
    }

    @Test func 먼_시간대는_교통_반영을_기다리는_중이라고_알린다() {
        let far = ArrivalEstimator.estimate(
            departureTime: "19:30", minutesUntilDeparture: 72, baseDurationMinutes: 26,
            trafficDurationMinutes: 34, trafficUpdatedAt: updated, isRefreshing: false, isOffline: false, now: updated
        )
        #expect(far.awaitsTrafficWindow)
        #expect(ArrivalEstimator.statusText(for: far) == "시간표 기준 · 출발 1시간 전부터 교통 반영")

        // 내일 출발편은 남은 분을 모른다(nil)
        let tomorrow = ArrivalEstimator.estimate(
            departureTime: "06:20", minutesUntilDeparture: nil, baseDurationMinutes: 26,
            trafficDurationMinutes: 34, trafficUpdatedAt: updated, isRefreshing: false, isOffline: false, now: updated
        )
        #expect(tomorrow.basis == .timetable)
        #expect(tomorrow.arrivalTime == "06:46")
        #expect(ArrivalEstimator.statusText(for: tomorrow) == "시간표 기준 · 출발 1시간 전부터 교통 반영")
    }

    @Test func 가까운_버스인데_교통정보를_못_받으면_기본_소요시간이라고_알린다() {
        let estimate = ArrivalEstimator.estimate(
            departureTime: "18:30", minutesUntilDeparture: 12, baseDurationMinutes: 26,
            trafficDurationMinutes: nil, trafficUpdatedAt: nil, isRefreshing: false, isOffline: false, now: updated
        )
        #expect(estimate.basis == .timetable)
        #expect(!estimate.awaitsTrafficWindow)
        #expect(ArrivalEstimator.statusText(for: estimate) == "시간표 기준 · 기본 소요시간으로 계산")
    }

    @Test func 오래된_교통값은_시간표_기준으로_되돌린다() {
        let now = updated.addingTimeInterval(21 * 60)
        let expired = ArrivalEstimator.estimate(
            departureTime: "18:30", minutesUntilDeparture: 12, baseDurationMinutes: 26,
            trafficDurationMinutes: 34, trafficUpdatedAt: updated, isRefreshing: false, isOffline: false, now: now
        )
        #expect(expired.basis == .timetable)
        #expect(expired.durationMinutes == 26)
        #expect(expired.arrivalTime == "18:56")

        let stillFresh = ArrivalEstimator.estimate(
            departureTime: "18:30", minutesUntilDeparture: 12, baseDurationMinutes: 26,
            trafficDurationMinutes: 34, trafficUpdatedAt: updated, isRefreshing: false, isOffline: false,
            now: updated.addingTimeInterval(19 * 60)
        )
        #expect(stillFresh.basis == .live(updatedAt: updated))

        // 만료된 값은 갱신 중에도 "기존 예상값"으로 쓰지 않는다
        let refreshing = ArrivalEstimator.estimate(
            departureTime: "18:30", minutesUntilDeparture: 12, baseDurationMinutes: 26,
            trafficDurationMinutes: 34, trafficUpdatedAt: updated, isRefreshing: true, isOffline: false, now: now
        )
        #expect(refreshing.basis == .refreshing(updatedAt: nil))
        #expect(refreshing.durationMinutes == 26)
    }

    @Test func 오프라인이면_오래된_교통값_대신_오프라인_기준이다() {
        let now = updated.addingTimeInterval(45 * 60)
        let near = ArrivalEstimator.estimate(
            departureTime: "18:30", minutesUntilDeparture: 12, baseDurationMinutes: 26,
            trafficDurationMinutes: 34, trafficUpdatedAt: updated, isRefreshing: false, isOffline: true, now: now
        )
        #expect(near.basis == .offline)
        #expect(near.durationMinutes == 26)

        let far = ArrivalEstimator.estimate(
            departureTime: "20:30", minutesUntilDeparture: 132, baseDurationMinutes: 26,
            trafficDurationMinutes: nil, trafficUpdatedAt: nil, isRefreshing: false, isOffline: true, now: now
        )
        #expect(far.basis == .offline)
        #expect(ArrivalEstimator.statusText(for: far) == "오프라인 · 시간표 기준")
    }

    @Test func 상태_문구와_경과_시간() {
        let now = updated.addingTimeInterval(3 * 60)
        #expect(ArrivalEstimator.statusText(for: .live(updatedAt: updated), now: now) == "현재 교통 반영 · 3분 전 갱신")
        #expect(ArrivalEstimator.statusText(for: .live(updatedAt: updated), now: updated) == "현재 교통 반영 · 방금 갱신")
        #expect(ArrivalEstimator.statusText(for: .timetable) == "시간표 기준 · 기본 소요시간으로 계산")
        #expect(ArrivalEstimator.statusText(for: .refreshing(updatedAt: updated)) == "교통정보 갱신 중 · 기존 예상값 표시")
        #expect(ArrivalEstimator.agoText(updated, now: updated.addingTimeInterval(72 * 60)) == "1시간 12분 전")
    }
}
