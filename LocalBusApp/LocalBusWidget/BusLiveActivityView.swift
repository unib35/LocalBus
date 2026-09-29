import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Activity (디자인 캔버스 LiveActivitySet · DynamicIslandSet)
//
// 1 출발 대기(20~5분 전) · 2 곧 출발(5분 전부터, 남은 시간 강조색) · 3 출발 이후(정시 출발 기준 도착 예상, 진행 바 없음)
// 4 막차(놓치면 내일 첫차 · 심야 요금). 진행 바는 출발 전에만: 시간으로 채워지는 바가 버스 위치처럼 읽히지 않게.

/// 잠금 화면 카드는 화면 모드를 따르고, Dynamic Island는 항상 검정이라 다크 값만 쓴다.
private struct LiveActivityPalette {
    let background: Color
    let primaryText: Color
    let secondaryText: Color
    /// 칩·진행 바 트랙
    let chipBackground: Color
    let accent: Color
    /// 강조색 배경 위 글자
    let accentForeground: Color
    let nightFare: Color
    /// 막차 칩 (선택됨 모양)
    let selectedBackground: Color
    let selectedText: Color

    static let dark = LiveActivityPalette(
        background: Color(white: 0.04),                                   // #0A0A0A
        primaryText: .white,
        secondaryText: Color(white: 0.64),                                // #A3A3A3
        chipBackground: Color(white: 0.149),                              // #262626
        accent: Color(red: 74/255, green: 222/255, blue: 128/255),        // #4ADE80
        accentForeground: .black,
        nightFare: Color(red: 251/255, green: 146/255, blue: 60/255),     // #FB923C
        selectedBackground: .white,
        selectedText: .black
    )

    static let light = LiveActivityPalette(
        background: .white,
        primaryText: Color(white: 0.05),                                  // #0D0D0D
        secondaryText: Color(white: 0.322),                               // #525252
        chipBackground: Color(white: 0.92),                               // #EBEBEB
        accent: Color(red: 22/255, green: 101/255, blue: 52/255),         // #166534
        accentForeground: .white,
        nightFare: Color(red: 194/255, green: 65/255, blue: 12/255),      // #C2410C
        selectedBackground: Color(white: 0.05),
        selectedText: .white
    )

    static func resolve(_ scheme: ColorScheme) -> LiveActivityPalette {
        scheme == .dark ? .dark : .light
    }
}

@available(iOS 16.2, *)
private struct LiveActivityStage {
    let context: ActivityViewContext<BusLiveActivityAttributes>
    var palette: LiveActivityPalette = .dark

    /// 앱이 보낸 단계와 지금 시각으로 계산한 단계 중 더 나아간 쪽.
    /// 앱이 멈춰 있어 전환을 보내지 못해도, 화면이 다시 그려질 때(표시가 낡는 출발 시각 등) 맞는 단계가 된다.
    var phase: BusLiveActivityAttributes.ContentState.Phase {
        let state = context.state
        switch LiveActivityTiming.stage(now: .now, departure: state.departureDate, arrival: state.arrivalDate) {
        case .inTransit, .finished:
            return .inTransit
        case .departingSoon:
            return state.phase == .inTransit ? .inTransit : .departingSoon
        case .waiting:
            return state.phase
        }
    }

    var isDeparted: Bool { phase == .inTransit }
    var isSoon: Bool { phase == .departingSoon }
    var isLastBus: Bool { context.attributes.isLastBus && !isDeparted }

    var chipText: String {
        if isDeparted { return "정시 출발 기준" }
        if isLastBus { return "막차" }
        return isSoon ? "곧 출발" : "출발 대기"
    }

    var chipBackground: Color {
        if isDeparted { return palette.chipBackground }
        if isLastBus { return palette.selectedBackground }
        return isSoon ? palette.accent : palette.chipBackground
    }

    var chipForeground: Color {
        if isDeparted { return palette.primaryText }
        if isLastBus { return palette.selectedText }
        return isSoon ? palette.accentForeground : palette.primaryText
    }

    /// 눈에 띄어야 하는 칩(곧 출발·막차)만 굵게
    var chipWeight: Font.Weight {
        !isDeparted && (isLastBus || isSoon) ? .bold : .semibold
    }

    var timerColor: Color { isSoon ? palette.accent : palette.primaryText }

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
                        .foregroundStyle(stage.palette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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
                        .font(.system(size: 15, weight: .semibold))
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
                        .foregroundStyle(stage.palette.accent)
                        .frame(maxWidth: 52)
                        .multilineTextAlignment(.trailing)
                }
            } minimal: {
                if stage.isDeparted {
                    Image(systemName: "bus.fill")
                        .foregroundStyle(.white)
                } else {
                    MinimalRemainingText(stage: stage)
                }
            }
        }
    }
}

/// 다른 앱과 함께일 때의 원형: 남은 분만.
/// 혼자 갱신되는 숫자는 시스템 형식으로만 그릴 수 있어 단위("분")가 함께 붙는다. iOS 18 미만은 분:초 타이머.
@available(iOS 16.2, *)
private struct MinimalRemainingText: View {
    let stage: LiveActivityStage

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                Text(
                    .currentDate,
                    format: .offset(to: stage.context.state.departureDate, allowedFields: [.minute], maxFieldCount: 1, sign: .never)
                )
                .font(.system(size: 15, weight: .heavy, design: .rounded))
            } else {
                Text(timerInterval: stage.departureTimer, countsDown: true, showsHours: false)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
            }
        }
        .monospacedDigit()
        .foregroundStyle(stage.palette.accent)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.6)
        .lineLimit(1)
    }
}

// MARK: - 잠금 화면 카드

@available(iOS 16.2, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<BusLiveActivityAttributes>
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = LiveActivityPalette.resolve(colorScheme)
        let stage = LiveActivityStage(context: context, palette: palette)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(context.attributes.departureTime) 출발 · \(context.attributes.direction)")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
                Spacer()
                StageChip(stage: stage)
            }

            LiveActivityBody(stage: stage, timerSize: 36)
        }
        .padding(16)
        .activityBackgroundTint(palette.background)
        .activitySystemActionForegroundColor(palette.primaryText)
    }
}

@available(iOS 16.2, *)
private struct StageChip: View {
    let stage: LiveActivityStage

    var body: some View {
        Text(stage.chipText)
            .font(.system(size: 11, weight: stage.chipWeight))
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
        let palette = stage.palette
        VStack(alignment: .leading, spacing: 12) {
            if stage.isDeparted {
                HStack(alignment: .lastTextBaseline, spacing: 7) {
                    Text("\(attributes.destinationName)에")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(palette.primaryText)
                    Text("약")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(palette.secondaryText)
                    Text(stage.arrivalText)
                        .font(.system(size: timerSize, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .tracking(-0.5)
                        .foregroundStyle(palette.primaryText)
                    Text("도착")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(palette.primaryText)
                }

                HStack(spacing: 6) {
                    if attributes.usesTraffic {
                        Circle().fill(palette.accent).frame(width: 7, height: 7)
                    } else {
                        Circle().stroke(palette.secondaryText, lineWidth: 1.5).frame(width: 7, height: 7)
                    }
                    Text(stage.basisText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(palette.secondaryText)
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
                            .foregroundStyle(palette.secondaryText)
                    }
                    Spacer(minLength: 8)
                    HStack(alignment: .lastTextBaseline, spacing: 5) {
                        Text("\(attributes.destinationName) 도착 약")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.secondaryText)
                        Text(stage.arrivalText)
                            .font(.system(size: 18, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(palette.primaryText)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    DepartureProgressBar(interval: progressInterval, palette: palette)

                    HStack {
                        Text(stage.progressLeading)
                        Spacer()
                        if stage.isLastBus, let nightFare = attributes.nightFareText {
                            HStack(spacing: 3) {
                                Text("심야").fontWeight(.bold).foregroundStyle(palette.nightFare)
                                Text(nightFare.replacingOccurrences(of: "심야 ", with: ""))
                            }
                        } else {
                            Text("\(attributes.departureTime) 출발")
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
                }
            }
        }
    }

    /// 표시 시작(출발 20분 전) → 출발 시각. 시작 시각을 몰라도 20분 창으로 고정해 바가 뒤로 가지 않게 한다.
    private var progressInterval: ClosedRange<Date> {
        let end = max(stage.context.state.departureDate, Date.now.addingTimeInterval(1))
        let start = min(end.addingTimeInterval(-LiveActivityTiming.startLead), Date.now)
        return start...end
    }
}

/// 출발까지의 진행 바 (높이 6, 모서리 3).
/// 혼자 채워지는 바는 시스템 바만 가능해서, 시스템 바(높이 4)를 세로로 늘리고 캔버스의 트랙 색을 뒤에 깐다.
@available(iOS 16.2, *)
private struct DepartureProgressBar: View {
    let interval: ClosedRange<Date>
    let palette: LiveActivityPalette

    private let height: CGFloat = 6
    private let systemHeight: CGFloat = 4

    var body: some View {
        ProgressView(timerInterval: interval, countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() })
            .progressViewStyle(.linear)
            .tint(palette.accent)
            .scaleEffect(x: 1, y: height / systemHeight, anchor: .center)
            .frame(height: height)
            .background(palette.chipBackground)
            .clipShape(Capsule())
            .accessibilityHidden(true)
    }
}
