import ActivityKit
import Foundation

@available(iOS 16.2, *)
@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private init() {}

    /// 푸시 서버 없이 실제 운행 상태를 추측하지 않고 예약한 편의 예정 시각을 표시합니다.
    func startActivity(departure: TimetableTimeline.Departure, direction: String, durationMinutes: Int) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, departure.date > Date(), durationMinutes > 0 else { return }
        // 재실행 후에도 시스템의 활동 목록을 사용해 중복을 제거합니다.
        for activity in Activity<BusLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        let arrival = departure.date.addingTimeInterval(Double(durationMinutes) * 60)
        let attributes = BusLiveActivityAttributes(direction: direction, departureTime: departure.time, durationMinutes: durationMinutes)
        let state = BusLiveActivityAttributes.ContentState(departureDate: departure.date, arrivalDate: arrival, phase: .waitingForDeparture)
        do {
            _ = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: arrival), pushType: nil)
        } catch {
            // 로컬 출발 알림의 성공 여부와 독립적인 보조 표시입니다.
        }
    }

    func endActivity() {
        let activities = Activity<BusLiveActivityAttributes>.activities
        Task {
            for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    func endActivity(departure: Date, direction: String) async {
        for activity in Activity<BusLiveActivityAttributes>.activities where activity.attributes.direction == direction && activity.content.state.departureDate == departure {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    func reconcileActivities(now: Date = Date()) async {
        for activity in Activity<BusLiveActivityAttributes>.activities where activity.content.state.arrivalDate <= now {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    var isActivityActive: Bool {
        !Activity<BusLiveActivityAttributes>.activities.isEmpty
    }
}
