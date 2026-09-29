import SwiftUI
import UIKit

// MARK: - 도착 시각으로 찾기 (디자인 캔버스 추가 제안)
//
// 목표 도착 시각만 정하면 탈 버스 한 대를 강조색으로 추천하고, 한 대 앞·놓쳤을 때를 함께 보여준다.

struct ArriveByView: View {
    @ObservedObject var viewModel: MainViewModel
    /// 알림을 켜거나 끄고, 시트 안에 띄울 결과 안내를 돌려준다 (권한이 없어 시트를 닫을 때는 nil)
    let onNotificationTap: (String) async -> ToastMessage?

    /// 목표 도착 시각 (자정부터의 분). 05:00 ~ 23:50
    @State private var targetMinutes: Int
    @State private var showsWheel = false
    @State private var toast: ToastMessage?

    init(viewModel: MainViewModel, onNotificationTap: @escaping (String) async -> ToastMessage?) {
        self.viewModel = viewModel
        self.onNotificationTap = onNotificationTap
        _targetMinutes = State(initialValue: Self.defaultTargetMinutes())
    }

    private var targetText: String {
        ArrivalPlanner.timeText(minutes: targetMinutes)
    }

    /// 목표 시각은 대개 한참 뒤라 현재 교통이 아니라 노선의 평소 소요 시간으로 계산한다
    private var durationMinutes: Int {
        viewModel.durationMinutes
    }

    private var plan: ArrivalPlan {
        ArrivalPlanner.plan(
            times: viewModel.currentTimes,
            durationMinutes: durationMinutes,
            arriveBy: targetText
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("도착 시각으로 찾기")
                        .font(AppTheme.Typography.sheetTitle)
                        .foregroundStyle(AppTheme.Color.primaryText)
                    Text("\(viewModel.selectedDirection.displayName) · \(scheduleText) · \(durationMinutes)분 소요")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }

                targetPicker
                    .padding(.top, 18)

                if let best = plan.best {
                    recommendation(best: best)
                } else {
                    noBus
                }

                Text("평소 소요 시간 \(durationMinutes)분으로 계산했어요. 출퇴근 시간에는 더 걸릴 수 있어요.")
                    .font(AppTheme.Typography.footnote)
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 34)
        }
        .background(AppTheme.Color.sheetBackground.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // 시트 아래 화면이 아니라 시트 안에 띄워야 가려지지 않는다
        .toast(item: $toast)
    }

    private var scheduleText: String {
        viewModel.selectedScheduleType == viewModel.todayScheduleType()
            ? "오늘 \(viewModel.selectedScheduleType == .weekday ? "평일" : "주말") 시간표"
            : (viewModel.selectedScheduleType == .weekday ? "평일 시간표" : "주말 시간표")
    }

    // MARK: - 목표 시각

    private var targetPicker: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                stepButton(systemImage: "minus", label: "10분 앞당기기") { shift(by: -10) }

                Spacer(minLength: 0)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showsWheel.toggle() }
                } label: {
                    VStack(spacing: 4) {
                        Text("\(viewModel.currentArrivalStopName)에")
                            .font(AppTheme.Typography.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.Color.secondaryText)
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text(targetText)
                                .font(AppTheme.Typography.etaTime)
                                .monospacedDigit()
                                .tracking(-1)
                                .foregroundStyle(AppTheme.Color.primaryText)
                            Text("까지")
                                .font(AppTheme.Typography.rowTime.weight(.bold))
                                .foregroundStyle(AppTheme.Color.primaryText)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("목표 도착 시각 \(targetText)")
                .accessibilityHint("탭하면 시각을 직접 고를 수 있어요")

                Spacer(minLength: 0)

                stepButton(systemImage: "plus", label: "10분 늦추기") { shift(by: 10) }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)

            if showsWheel {
                DatePicker("도착 시각", selection: wheelSelection, in: Self.wheelRange, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                    .environment(\.timeZone, Self.koreaTimeZone)
                    .frame(height: 150)
                    .clipped()
            }
        }
        .sheetTileSurface(cornerRadius: 16)
    }

    private func stepButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.Color.primaryText)
                .frame(width: 48, height: 48)
                .background(Circle().fill(AppTheme.Color.secondaryButton))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func shift(by minutes: Int) {
        let shifted = ArrivalPlanner.shiftedTarget(minutes: targetMinutes, by: minutes)
        guard shifted != targetMinutes else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        targetMinutes = shifted
    }

    // MARK: - 추천

    private func recommendation(best: String) -> some View {
        let plan = plan
        return VStack(alignment: .leading, spacing: 0) {
            Text("이 버스를 타세요")
                .font(AppTheme.Typography.groupTitle)
                .foregroundStyle(AppTheme.Color.primaryText)
                .padding(.top, 26)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .lastTextBaseline) {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(best)
                            .font(.system(size: 52, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .tracking(-1.5)
                            .foregroundStyle(AppTheme.Color.accent)
                        Text("출발")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppTheme.Color.primaryText)
                    }
                    Spacer()
                    if let slack = plan.slackMinutes {
                        Text(slack == 0 ? "딱 맞게 도착" : "\(ArrivalPlanner.spanText(slack)) 여유")
                            .font(.system(size: 14, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.Color.primaryText)
                    }
                }

                JourneyStripView(
                    departureTime: best,
                    arrivalTime: plan.arrival(of: best),
                    destinationName: viewModel.currentArrivalHubName,
                    durationMinutes: durationMinutes
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sheetTileSurface(cornerRadius: 16)
            .padding(.top, 10)
            .accessibilityElement(children: .combine)

            VStack(spacing: 0) {
                if let earlier = plan.earlier {
                    let slack = DateService.minutesBetween(from: plan.arrival(of: earlier), to: plan.target) ?? 0
                    alternativeRow(tag: "한 대 앞", departure: earlier, note: "\(ArrivalPlanner.spanText(slack)) 여유", noteColor: AppTheme.Color.secondaryText)
                }
                if let later = plan.later {
                    if plan.earlier != nil { RowDivider() }
                    let late = plan.lateMinutes ?? 0
                    alternativeRow(tag: "놓치면", departure: later, note: "\(ArrivalPlanner.spanText(late)) 늦어요", noteColor: AppTheme.Color.warning)
                }
            }
            .sheetTileSurface(cornerRadius: 16)
            .padding(.top, 10)

            Button {
                Task {
                    if let message = await onNotificationTap(best) { toast = message }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isNotificationScheduled(for: best) ? "bell.fill" : "bell")
                        .font(.system(size: 16, weight: .semibold))
                    Text(viewModel.isNotificationScheduled(for: best) ? "\(best) 버스 알림 켜짐" : "\(best) 버스 5분 전 알림 받기")
                }
            }
            .buttonStyle(viewModel.isNotificationScheduled(for: best) ? AnyButtonStyle(.secondaryAction) : AnyButtonStyle(.primaryAction))
            .padding(.top, 18)
        }
    }

    private func alternativeRow(tag: String, departure: String, note: String, noteColor: Color) -> some View {
        HStack(spacing: 12) {
            Text(tag)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Color.secondaryText)
                .frame(width: 56, alignment: .leading)

            HStack(spacing: 8) {
                Text(departure)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.Color.tertiaryText)
                Text(plan.arrival(of: departure))
            }
            .font(AppTheme.Typography.rowTitle)
            .monospacedDigit()
            .foregroundStyle(AppTheme.Color.primaryText)
            .fixedSize()

            Spacer(minLength: 8)

            Text(note)
                .font(AppTheme.Typography.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(noteColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .accessibilityElement(children: .combine)
    }

    private var noBus: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("그 시각까지 도착하는 버스가 없어요")
                .font(AppTheme.Typography.rowTitle)
                .foregroundStyle(AppTheme.Color.primaryText)
            if let first = plan.later {
                Text("첫차 \(first)을 타면 \(plan.arrival(of: first))에 도착해요")
                    .font(AppTheme.Typography.caption)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheetTileSurface(cornerRadius: 16)
        .padding(.top, 26)
    }

    // MARK: - 헬퍼

    private static let koreaTimeZone = TimeZone(identifier: "Asia/Seoul") ?? .current

    private static var koreaCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = koreaTimeZone
        return calendar
    }

    /// 기본 목표: 지금부터 1시간 뒤를 10분 단위로 올림 (05:00 ~ 23:50)
    private static func defaultTargetMinutes(now: Date = Date()) -> Int {
        let components = koreaCalendar.dateComponents([.hour, .minute], from: now)
        return ArrivalPlanner.defaultTargetMinutes(nowMinutes: (components.hour ?? 0) * 60 + (components.minute ?? 0))
    }

    // 시간 휠은 Date를 다루므로 오늘 날짜 위에서 분만 오간다
    private static func date(forMinutes minutes: Int) -> Date {
        let calendar = koreaCalendar
        let startOfDay = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .minute, value: minutes, to: startOfDay) ?? startOfDay
    }

    private static var wheelRange: ClosedRange<Date> {
        date(forMinutes: ArrivalPlanner.targetRange.lowerBound)...date(forMinutes: ArrivalPlanner.targetRange.upperBound)
    }

    private var wheelSelection: Binding<Date> {
        Binding(
            get: { Self.date(forMinutes: targetMinutes) },
            set: { newValue in
                let components = Self.koreaCalendar.dateComponents([.hour, .minute], from: newValue)
                targetMinutes = ArrivalPlanner.clampedTarget(minutes: (components.hour ?? 0) * 60 + (components.minute ?? 0))
            }
        )
    }
}
