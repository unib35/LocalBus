import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct BusLiveActivityView: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusLiveActivityAttributes.self) { context in
            // 잠금화면 / 배너 뷰
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.direction)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(context.attributes.departureTime + " 출발")
                            .font(.headline.bold().monospacedDigit())
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.phase == .waitingForDeparture ? "출발까지" : "도착까지")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        countdownText(context: context)
                            .font(.title3.bold().monospacedDigit())
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(
                        timerInterval: progressInterval(context: context),
                        countsDown: true
                    )
                    .tint(context.state.phase == .inTransit ? .green : .blue)
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "bus.fill")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                countdownText(context: context)
                    .font(.caption.bold().monospacedDigit())
            } minimal: {
                Image(systemName: "bus.fill")
                    .foregroundStyle(context.state.phase == .inTransit ? .green : .blue)
            }
        }
    }

    @ViewBuilder
    private func countdownText(context: ActivityViewContext<BusLiveActivityAttributes>) -> some View {
        let targetDate = context.state.phase == .waitingForDeparture
            ? context.state.departureDate
            : context.state.arrivalDate

        Text(timerInterval: Date.now...targetDate, countsDown: true)
    }

    private func progressInterval(context: ActivityViewContext<BusLiveActivityAttributes>) -> ClosedRange<Date> {
        if context.state.phase == .waitingForDeparture {
            // 출발 대기: 현재 → 출발시각
            return Date.now...context.state.departureDate
        } else {
            // 이동 중: 출발시각 → 도착시각
            return context.state.departureDate...context.state.arrivalDate
        }
    }
}

// MARK: - Lock Screen Banner View

@available(iOS 16.2, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<BusLiveActivityAttributes>

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.direction)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(context.attributes.departureTime + " 출발")
                    .font(.headline.bold())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(context.state.phase == .waitingForDeparture ? "출발까지" : "도착 예정")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                let targetDate = context.state.phase == .waitingForDeparture
                    ? context.state.departureDate
                    : context.state.arrivalDate

                Text(timerInterval: Date.now...targetDate, countsDown: true)
                    .font(.title2.bold().monospacedDigit())
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.7))
    }
}
