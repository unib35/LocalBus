import Testing
import Foundation
@testable import JangyuBus

struct ArrivalEstimateTests {

    private let updated = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func 출발_1시간_이내면_교통을_반영한다() {
        let estimate = ArrivalEstimator.estimate(
            departureTime: "18:30", minutesUntilDeparture: 12, baseDurationMinutes: 26,
            trafficDurationMinutes: 34, trafficUpdatedAt: updated, isRefreshing: false, isOffline: false
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
            trafficDurationMinutes: 34, trafficUpdatedAt: updated, isRefreshing: false, isOffline: false
        )
        #expect(estimate.arrivalTime == "19:56")
        #expect(estimate.basis == .timetable)
        #expect(estimate.durationText == "기본 소요 26분")
    }

    @Test func 갱신_중에는_기존_예상값을_유지한다() {
        let estimate = ArrivalEstimator.estimate(
            departureTime: "18:30", minutesUntilDeparture: 12, baseDurationMinutes: 26,
            trafficDurationMinutes: 34, trafficUpdatedAt: updated, isRefreshing: true, isOffline: false
        )
        #expect(estimate.arrivalTime == "19:04")
        #expect(estimate.basis == .refreshing(updatedAt: updated))
        #expect(estimate.basis.usesTraffic)
    }

    @Test func 교통정보가_없고_오프라인이면_오프라인_기준이다() {
        let estimate = ArrivalEstimator.estimate(
            departureTime: "18:30", minutesUntilDeparture: 12, baseDurationMinutes: 26,
            trafficDurationMinutes: nil, trafficUpdatedAt: nil, isRefreshing: false, isOffline: true
        )
        #expect(estimate.arrivalTime == "18:56")
        #expect(estimate.basis == .offline)
        #expect(ArrivalEstimator.statusText(for: estimate.basis) == "오프라인 · 시간표 기준")
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
