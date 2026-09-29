import ActivityKit
import Foundation
import UIKit

@available(iOS 16.2, *)
@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private var currentActivity: Activity<BusLiveActivityAttributes>?
    private var phaseTimer: Timer?
    private var activeObserver: NSObjectProtocol?

    /// 앱이 다시 앞으로 올 때 부른다. 출발 20분 안에 들어온 알림이 있으면 그때 표시를 시작하려는 용도.
    var onBecameActive: (() -> Void)?

    private init() {
        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reconcile()
                self?.onBecameActive?()
            }
        }
    }

    /// Live Activity 시작
    /// - Parameters:
    ///   - departureTime: 출발 시간 문자열 ("07:20")
    ///   - direction: 방향 표시 이름 ("장유 → 사상")
    ///   - durationMinutes: 소요 시간 (분)
    func startActivity(
        departureTime: String,
        direction: String,
        durationMinutes: Int,
        destinationName: String = "사상",
        boardingStopName: String = "",
        isLastBus: Bool = false,
        nextDayFirstBusTime: String? = nil,
        nightFareText: String? = nil,
        usesTraffic: Bool = false,
        trafficUpdatedAt: Date? = nil
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // 기존 활동 종료 (참조를 먼저 분리해 레이스 컨디션 방지)
        let oldActivity = currentActivity
        currentActivity = nil
        phaseTimer?.invalidate()
        phaseTimer = nil
        Task {
            await oldActivity?.end(nil, dismissalPolicy: .immediate)
        }

        let now = Date()
        guard let departureDate = LiveActivityTiming.departureDate(for: departureTime, now: now),
              departureDate > now else { return }

        let arrivalDate = departureDate.addingTimeInterval(TimeInterval(durationMinutes * 60))

        let attributes = BusLiveActivityAttributes(
            direction: direction,
            departureTime: departureTime,
            durationMinutes: durationMinutes,
            destinationName: destinationName,
            boardingStopName: boardingStopName,
            isLastBus: isLastBus,
            nextDayFirstBusTime: nextDayFirstBusTime,
            nightFareText: nightFareText,
            usesTraffic: usesTraffic,
            trafficUpdatedAt: trafficUpdatedAt
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content(departureDate: departureDate, arrivalDate: arrivalDate, now: now),
                pushType: nil
            )
            currentActivity = activity
            scheduleNextTransition(departureDate: departureDate, arrivalDate: arrivalDate)
        } catch {
            print("Live Activity 시작 실패: \(error)")
        }
    }

    /// Live Activity 종료
    func endActivity() {
        phaseTimer?.invalidate()
        phaseTimer = nil
        let activityToEnd = currentActivity
        currentActivity = nil
        Task {
            await activityToEnd?.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// 현재 Live Activity가 활성 상태인지
    var isActivityActive: Bool {
        currentActivity != nil
    }

    /// 이 버스의 표시가 이미 떠 있는지
    func isShowing(departureTime: String, direction: String) -> Bool {
        Activity<BusLiveActivityAttributes>.activities.contains {
            $0.activityState == .active
                && $0.attributes.departureTime == departureTime
                && $0.attributes.direction == direction
        }
    }

    /// 앱이 멈춰 있던 동안 지나간 단계를 따라잡는다.
    /// 도착 예상 시각이 지난 표시는 끝내고, 남은 표시는 지금 시각에 맞는 단계로 고친 뒤 다음 전환을 다시 예약한다.
    func reconcile() {
        let now = Date()
        var survivor: Activity<BusLiveActivityAttributes>?

        for activity in Activity<BusLiveActivityAttributes>.activities {
            let state = activity.content.state
            let stage = LiveActivityTiming.stage(now: now, departure: state.departureDate, arrival: state.arrivalDate)
            if stage == .finished || survivor != nil {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            } else {
                survivor = activity
            }
        }

        phaseTimer?.invalidate()
        phaseTimer = nil
        currentActivity = survivor

        guard let survivor else { return }
        let state = survivor.content.state
        let updated = content(departureDate: state.departureDate, arrivalDate: state.arrivalDate, now: now)
        if updated.state != state {
            Task { await survivor.update(updated) }
        }
        scheduleNextTransition(departureDate: state.departureDate, arrivalDate: state.arrivalDate)
    }

    // MARK: - Private

    /// 출발 5분 전부터 "곧 출발" 단계
    static let departingSoonLead: TimeInterval = LiveActivityTiming.departingSoonLead

    private func content(departureDate: Date, arrivalDate: Date, now: Date) -> ActivityContent<BusLiveActivityAttributes.ContentState> {
        let phase: BusLiveActivityAttributes.ContentState.Phase
        switch LiveActivityTiming.stage(now: now, departure: departureDate, arrival: arrivalDate) {
        case .waiting: phase = .waitingForDeparture
        case .departingSoon: phase = .departingSoon
        case .inTransit, .finished: phase = .inTransit
        }
        return ActivityContent(
            state: .init(departureDate: departureDate, arrivalDate: arrivalDate, phase: phase),
            staleDate: LiveActivityTiming.staleDate(now: now, departure: departureDate, arrival: arrivalDate)
        )
    }

    /// 출발 5분 전에 곧 출발, 출발 시각에 출발 이후, 도착 예상 시각에 종료.
    /// 타이머는 앱이 살아 있을 때만 울린다. 멈춰 있던 동안의 전환은 `reconcile()`과 화면의 시각 계산이 메운다.
    private func scheduleNextTransition(departureDate: Date, arrivalDate: Date) {
        phaseTimer?.invalidate()
        phaseTimer = nil

        let now = Date()
        guard let next = LiveActivityTiming.nextTransition(after: now, departure: departureDate, arrival: arrivalDate) else {
            endActivity()
            return
        }

        phaseTimer = Timer.scheduledTimer(withTimeInterval: max(next.timeIntervalSince(now), 0.1), repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.advance(departureDate: departureDate, arrivalDate: arrivalDate)
            }
        }
    }

    private func advance(departureDate: Date, arrivalDate: Date) {
        let now = Date()
        if LiveActivityTiming.stage(now: now, departure: departureDate, arrival: arrivalDate) == .finished {
            endActivity()
            return
        }
        let updated = content(departureDate: departureDate, arrivalDate: arrivalDate, now: now)
        Task {
            await currentActivity?.update(updated)
        }
        scheduleNextTransition(departureDate: departureDate, arrivalDate: arrivalDate)
    }
}
