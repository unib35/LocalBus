import ActivityKit
import Foundation

@available(iOS 16.2, *)
@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private var currentActivity: Activity<BusLiveActivityAttributes>?
    private var phaseTimer: Timer?

    private init() {}

    /// Live Activity 시작
    /// - Parameters:
    ///   - departureTime: 출발 시간 문자열 ("07:20")
    ///   - direction: 방향 표시 이름 ("장유 → 사상")
    ///   - durationMinutes: 소요 시간 (분)
    func startActivity(departureTime: String, direction: String, durationMinutes: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // 기존 활동 종료
        endActivity()

        guard let departureDate = dateFromTimeString(departureTime),
              departureDate > Date() else { return }

        let arrivalDate = departureDate.addingTimeInterval(TimeInterval(durationMinutes * 60))

        let attributes = BusLiveActivityAttributes(
            direction: direction,
            departureTime: departureTime,
            durationMinutes: durationMinutes
        )

        let initialState = BusLiveActivityAttributes.ContentState(
            departureDate: departureDate,
            arrivalDate: arrivalDate,
            phase: .waitingForDeparture
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            schedulePhaseTransition(departureDate: departureDate, arrivalDate: arrivalDate)
        } catch {
            print("Live Activity 시작 실패: \(error)")
        }
    }

    /// Live Activity 종료
    func endActivity() {
        phaseTimer?.invalidate()
        phaseTimer = nil
        Task {
            await currentActivity?.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }

    /// 현재 Live Activity가 활성 상태인지
    var isActivityActive: Bool {
        currentActivity != nil
    }

    // MARK: - Private

    /// 출발 시각에 phase를 inTransit으로 전환, 도착 시각에 종료
    private func schedulePhaseTransition(departureDate: Date, arrivalDate: Date) {
        phaseTimer?.invalidate()

        let now = Date()
        let departureDelay = departureDate.timeIntervalSince(now)

        if departureDelay > 0 {
            phaseTimer = Timer.scheduledTimer(withTimeInterval: departureDelay, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.transitionToInTransit(departureDate: departureDate, arrivalDate: arrivalDate)
                }
            }
        } else {
            transitionToInTransit(departureDate: departureDate, arrivalDate: arrivalDate)
        }
    }

    private func transitionToInTransit(departureDate: Date, arrivalDate: Date) {
        let transitState = BusLiveActivityAttributes.ContentState(
            departureDate: departureDate,
            arrivalDate: arrivalDate,
            phase: .inTransit
        )

        Task {
            await currentActivity?.update(.init(state: transitState, staleDate: nil))
        }

        let arrivalDelay = arrivalDate.timeIntervalSince(Date())
        if arrivalDelay > 0 {
            phaseTimer = Timer.scheduledTimer(withTimeInterval: arrivalDelay, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.endActivity()
                }
            }
        } else {
            endActivity()
        }
    }

    /// "HH:mm" 문자열을 오늘 날짜의 Date로 변환 (KST)
    private func dateFromTimeString(_ timeString: String) -> Date? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }

        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!

        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0

        return calendar.date(from: components)
    }
}
