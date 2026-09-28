import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Activity (디자인 캔버스 LiveActivitySet · DynamicIslandSet)
//
// 1 출발 대기(20~5분 전) · 2 곧 출발(5분 전부터, 남은 시간 강조색) · 3 출발 이후(정시 출발 기준 도착 예상, 진행 바 없음)
// 4 막차(놓치면 내일 첫차 · 심야 요금). 진행 바는 출발 전에만: 시간으로 채워지는 바가 버스 위치처럼 읽히지 않게.

private enum LiveActivityTheme {
    static let accent = Color(red: 74/255, green: 222/255, blue: 128/255)
    static let nightFare = Color(red: 251/255, green: 146/255, blue: 60/255)
    static let secondaryText = Color(white: 0.64)
    static let chipBackground = Color(white: 0.15)
    static let track = Color(white: 0.15)
    static let background = Color(white: 0.04)
}

@available(iOS 16.2, *)
private struct LiveActivityStage {
    let context: ActivityViewContext<BusLiveActivityAttributes>

    var phase: BusLiveActivityAttributes.ContentState.Phase { context.state.phase }
    var isDeparted: Bool { phase == .inTransit }
    var isSoon: Bool { phase == .departingSoon }
    var isLastBus: Bool { context.attributes.isLastBus && !isDeparted }

    var chipText: String {
        if isDeparted { return "정시 출발 기준" }
        if isLastBus { return "막차" }
        return isSoon ? "곧 출발" : "출발 대기"
    }

    var chipBackground: Color {
        if isDeparted { return LiveActivityTheme.chipBackground }
        if isLastBus { return .white }
        return isSoon ? LiveActivityTheme.accent : LiveActivityTheme.chipBackground
    }

    var chipForeground: Color { (isLastBus || isSoon) && !isDeparted ? .black : .white }

    var timerColor: Color { isSoon ? LiveActivityTheme.accent : .white }

    var departureTimer: ClosedRange<Date> {
        Date.now...max(context.state.departureDate, Date.now.addingTimeInterval(1))
    }

    var arrivalText: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: context.state.arrivalDate)
    }

    var basisText: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "HH:mm"
        if context.attributes.usesTraffic, let at = context.attributes.trafficUpdatedAt {
            return "현재 교통 반영 · \(formatter.string(from: at)) 기준 · 버스 위치는 확인하지 않아요"
        }
        return "시간표 기준 · 기본 소요 \(context.attributes.durationMinutes)분 · 버스 위치는 확인하지 않아요"
    }

    /// 진행 바 아래 왼쪽 문구
    var progressLeading: String {
        if isLastBus, let first = context.attributes.nextDayFirstBusTime { return "놓치면 다음 버스는 내일 \(first)" }
        if isSoon, !context.attributes.boardingStopName.isEmpty { return "\(context.attributes.boardingStopName) 승차" }
        return "지금"
    }
}

@available(iOS 16.2, *)
struct BusLiveActivityView: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusLiveActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            let stage = LiveActivityStage(context: context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("\(context.attributes.departureTime) 출발 · \(context.attributes.direction)")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(LiveActivityTheme.secondaryText)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StageChip(stage: stage)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LiveActivityBody(stage: stage, timerSize: 40)
                        .padding(.top, 6)
                }
            } compactLeading: {
                HStack(spacing: 5) {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(context.attributes.departureTime)
                        .font(.system(size: 14, weight: .bold))
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
            } compactTrailing: {
                if stage.isDeparted {
                    Text("약 \(stage.arrivalText)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                } else {
                    Text(timerInterval: stage.departureTimer, countsDown: true, showsHours: false)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(LiveActivityTheme.accent)
                        .frame(maxWidth: 52)
                        .multilineTextAlignment(.trailing)
                }
            } minimal: {
                if stage.isDeparted {
                    Image(systemName: "bus.fill")
                        .foregroundStyle(.white)
                } else {
                    Text(timerInterval: stage.departureTimer, countsDown: true, showsHours: false)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(LiveActivityTheme.accent)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

// MARK: - 잠금 화면 카드

@available(iOS 16.2, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<BusLiveActivityAttributes>

    var body: some View {
        let stage = LiveActivityStage(context: context)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(context.attributes.departureTime) 출발 · \(context.attributes.direction)")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(LiveActivityTheme.secondaryText)
                    .lineLimit(1)
                Spacer()
                StageChip(stage: stage)
            }

            LiveActivityBody(stage: stage, timerSize: 36)
        }
        .padding(16)
        .activityBackgroundTint(LiveActivityTheme.background)
        .activitySystemActionForegroundColor(.white)
    }
}

@available(iOS 16.2, *)
private struct StageChip: View {
    let stage: LiveActivityStage

    var body: some View {
        Text(stage.chipText)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(stage.chipForeground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(stage.chipBackground))
    }
}

/// 남은 시간 + 도착 예상 + 진행 바 (출발 전) / "사상에 약 19:04 도착" (출발 후)
@available(iOS 16.2, *)
private struct LiveActivityBody: View {
    let stage: LiveActivityStage
    let timerSize: CGFloat

    var body: some View {
        let attributes = stage.context.attributes
        VStack(alignment: .leading, spacing: 12) {
            if stage.isDeparted {
                HStack(alignment: .lastTextBaseline, spacing: 7) {
                    Text("\(attributes.destinationName)에")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text("약")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LiveActivityTheme.secondaryText)
                    Text(stage.arrivalText)
                        .font(.system(size: timerSize, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .tracking(-0.5)
                        .foregroundStyle(.white)
                    Text("도착")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }

                HStack(spacing: 6) {
                    if attributes.usesTraffic {
                        Circle().fill(LiveActivityTheme.accent).frame(width: 7, height: 7)
                    } else {
                        Circle().stroke(LiveActivityTheme.secondaryText, lineWidth: 1.5).frame(width: 7, height: 7)
                    }
                    Text(stage.basisText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(LiveActivityTheme.secondaryText)
            } else {
                HStack(alignment: .lastTextBaseline) {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(timerInterval: stage.departureTimer, countsDown: true, showsHours: false)
                            .font(.system(size: timerSize, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .tracking(-0.5)
                            .foregroundStyle(stage.timerColor)
                            .frame(maxWidth: timerSize * 3.2, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        Text("남음")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(LiveActivityTheme.secondaryText)
                    }
                    Spacer(minLength: 8)
                    HStack(alignment: .lastTextBaseline, spacing: 5) {
                        Text("\(attributes.destinationName) 도착 약")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LiveActivityTheme.secondaryText)
                        Text(stage.arrivalText)
                            .font(.system(size: 18, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    ProgressView(timerInterval: progressInterval, countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                        .progressViewStyle(.linear)
                        .tint(LiveActivityTheme.accent)

                    HStack {
                        Text(stage.progressLeading)
                        Spacer()
                        if stage.isLastBus, let nightFare = attributes.nightFareText {
                            HStack(spacing: 3) {
                                Text("심야").fontWeight(.bold).foregroundStyle(LiveActivityTheme.nightFare)
                                Text(nightFare.replacingOccurrences(of: "심야 ", with: ""))
                            }
                        } else {
                            Text("\(attributes.departureTime) 출발")
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(LiveActivityTheme.secondaryText)
                    .lineLimit(1)
                }
            }
        }
    }

    /// 활동 시작(출발 20분 전) → 출발 시각. 시작 시각을 몰라도 20분 창으로 고정해 바가 뒤로 가지 않게 한다.
    private var progressInterval: ClosedRange<Date> {
        let end = max(stage.context.state.departureDate, Date.now.addingTimeInterval(1))
        let start = min(end.addingTimeInterval(-20 * 60), Date.now)
        return start...end
    }
}
