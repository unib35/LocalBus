import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct BusLiveActivityAttributes: ActivityAttributes {
    /// 활동 기간 동안 변하지 않는 정적 데이터
    let direction: String           // "장유 → 사상"
    let departureTime: String       // "07:20"
    let durationMinutes: Int        // 26

    /// 실시간 변경되는 동적 상태
    struct ContentState: Codable, Hashable {
        let departureDate: Date     // 출발 시각 (Date)
        let arrivalDate: Date       // 도착 예정 시각 (Date)
        let phase: Phase

        enum Phase: String, Codable, Hashable {
            case waitingForDeparture  // 출발 대기 (카운트다운)
            case inTransit            // 이동 중 (도착 카운트다운)
        }
    }
}
