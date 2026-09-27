import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Activity (디자인 캔버스 개선안)
//
// 출발 시각·노선을 한 줄로, 단계 칩("출발 대기"/"이동 중"), 남은 시간을 크게,
// 진행 바에 시작·끝 레이블. 강조색은 진행 바와 이동 중 아이콘에만.

private enum LiveActivityTheme {
    static let accent = Color(red: 74/255, green: 222/255, blue: 128/255)
    static let secondaryText = Color.white.opacity(0.64)
    static let chipBackground = Color.white.opacity(0.12)
    static let track = Color.white.opacity(0.14)
    static let background = Color(white: 0.04)
}

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
                    .tint(LiveActivityTheme.accent)
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "bus.fill")
                    .foregroundStyle(context.state.phase == .inTransit ? LiveActivityTheme.accent : .white)
            } compactTrailing: {
                countdownText(context: context)
                    .font(.caption.bold().monospacedDigit())
            } minimal: {
                Image(systemName: "bus.fill")
                    .foregroundStyle(context.state.phase == .inTransit ? LiveActivityTheme.accent : .white)
            }
        }
    }

    @ViewBuilder
    private func countdownText(context: ActivityViewContext<BusLiveActivityAttributes>) -> some View {
        let targetDate = context.state.phase == .waitingForDeparture
            ? context.state.departureDate
            : context.state.arrivalDate
        let safeEnd = max(targetDate, Date.now.addingTimeInterval(1))

        Text(timerInterval: Date.now...safeEnd, countsDown: true)
    }

    private func progressInterval(context: ActivityViewContext<BusLiveActivityAttributes>) -> ClosedRange<Date> {
        if context.state.phase == .waitingForDeparture {
            // 출발 대기: 현재 → 출발시각
            let safeEnd = max(context.state.departureDate, Date.now.addingTimeInterval(1))
            return Date.now...safeEnd
        } else {
            // 이동 중: 출발시각 → 도착시각
            let start = min(context.state.departureDate, Date.now)
            let safeEnd = max(context.state.arrivalDate, start.addingTimeInterval(1))
            return start...safeEnd
        }
    }
}

// MARK: - Lock Screen Banner View

@available(iOS 16.2, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<BusLiveActivityAttributes>

    private var isWaiting: Bool { context.state.phase == .waitingForDeparture }

    private var targetDate: Date {
        isWaiting ? context.state.departureDate : context.state.arrivalDate
    }

    private var arrivalTimeText: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: context.state.arrivalDate)
    }

    private var progressInterval: ClosedRange<Date> {
        if isWaiting {
            let safeEnd = max(context.state.departureDate, Date.now.addingTimeInterval(1))
            return Date.now...safeEnd
        } else {
            let start = min(context.state.departureDate, Date.now)
            let safeEnd = max(context.state.arrivalDate, start.addingTimeInterval(1))
            return start...safeEnd
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(context.attributes.departureTime) 출발 · \(context.attributes.direction)")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(LiveActivityTheme.secondaryText)
                    .lineLimit(1)

                Spacer()

                Text(isWaiting ? "출발 대기" : "이동 중")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(LiveActivityTheme.chipBackground))
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(timerInterval: Date.now...max(targetDate, Date.now.addingTimeInterval(1)), countsDown: true)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Text("남음")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LiveActivityTheme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(timerInterval: progressInterval, countsDown: true, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                    .progressViewStyle(.linear)
                    .tint(LiveActivityTheme.accent)

                HStack {
                    Text(isWaiting ? "지금" : "\(context.attributes.departureTime) 출발")
                    Spacer()
                    Text(isWaiting ? "\(context.attributes.departureTime) 출발" : "\(arrivalTimeText) 도착")
                }
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(LiveActivityTheme.secondaryText)
            }
        }
        .padding(16)
        .activityBackgroundTint(LiveActivityTheme.background)
        .activitySystemActionForegroundColor(.white)
    }
}
