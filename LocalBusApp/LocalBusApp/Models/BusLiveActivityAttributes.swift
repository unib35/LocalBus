import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct BusLiveActivityAttributes: ActivityAttributes {
    /// 활동 기간 동안 변하지 않는 정적 데이터
    let direction: String           // "장유 → 사상"
    let departureTime: String       // "07:20"
    let durationMinutes: Int        // 26 (교통 반영값이면 그 값)
    let destinationName: String     // "사상"
    let boardingStopName: String    // "갑을장유병원정류소"
    let isLastBus: Bool
    let nextDayFirstBusTime: String? // 막차를 놓쳤을 때 안내
    let nightFareText: String?      // "심야 3,000원"
    let usesTraffic: Bool
    let trafficUpdatedAt: Date?

    init(
        direction: String,
        departureTime: String,
        durationMinutes: Int,
        destinationName: String = "사상",
        boardingStopName: String = "",
        isLastBus: Bool = false,
        nextDayFirstBusTime: String? = nil,
        nightFareText: String? = nil,
        usesTraffic: Bool = false,
        trafficUpdatedAt: Date? = nil
    ) {
        self.direction = direction
        self.departureTime = departureTime
        self.durationMinutes = durationMinutes
        self.destinationName = destinationName
        self.boardingStopName = boardingStopName
        self.isLastBus = isLastBus
        self.nextDayFirstBusTime = nextDayFirstBusTime
        self.nightFareText = nightFareText
        self.usesTraffic = usesTraffic
        self.trafficUpdatedAt = trafficUpdatedAt
    }

    /// 실시간 변경되는 동적 상태
    struct ContentState: Codable, Hashable {
        let departureDate: Date     // 출발 시각 (Date)
        let arrivalDate: Date       // 도착 예정 시각 (Date)
        let phase: Phase

        enum Phase: String, Codable, Hashable {
            case waitingForDeparture  // 출발 대기 (20분 전 ~ 5분 전)
            case departingSoon        // 곧 출발 (5분 전부터)
            case inTransit            // 출발 시각 이후 (정시 출발 기준 도착 예상)
        }
    }
}
