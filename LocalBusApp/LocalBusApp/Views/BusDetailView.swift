import SwiftUI
import UIKit

// MARK: - 버스 상세 시트 뷰 (디자인 캔버스 개선안)
//
// 출발 시각 하나를 헤더로, 알림은 기본 버튼 하나로. 요금은 타일 한 줄, 정류장은 통과 시각과 함께.
// 시트 배경 위에 놓이므로 컨테이너 대신 구분선과 2차 서피스만 쓴다.

struct BusDetailView: View {
    let info: BusDetailInfo
    /// 이 버스에 걸린 알림 (없으면 nil). 시트 안에서 켜고 끄면 바로 갱신한다.
    @State private var alert: BusAlert?
    @State private var selectedLead: Int
    @State private var repeatsWeekdays: Bool
    @State private var notificationToast: ToastMessage?
    @State private var quickReport: QuickReportContext?
    /// (lead, 평일 반복) → 권한이 있어서 예약됐으면 true
    let onSetAlert: (Int, Bool) async -> Bool
    let onRemoveAlert: () async -> Void

    init(
        info: BusDetailInfo,
        alert: BusAlert?,
        onSetAlert: @escaping (Int, Bool) async -> Bool,
        onRemoveAlert: @escaping () async -> Void
    ) {
        self.info = info
        self._alert = State(initialValue: alert)
        self._selectedLead = State(initialValue: alert?.leadMinutes ?? 5)
        self._repeatsWeekdays = State(initialValue: alert?.repeatsWeekdays ?? false)
        self.onSetAlert = onSetAlert
        self.onRemoveAlert = onRemoveAlert
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header

                JourneyStripView(
                    departureTime: info.departureTime,
                    arrivalTime: info.arrivalTime,
                    destinationName: info.direction.arrivalName,
                    durationMinutes: info.durationMinutes
                )
                .padding(.top, 18)

                alertSection
                    .padding(.top, 26)

                fareSection
                    .padding(.top, 28)

                stopsSection
                    .padding(.top, 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(AppTheme.Color.sheetBackground.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .toast(item: $notificationToast)
        .sheet(item: $quickReport) { context in
            QuickReportView(context: context)
        }
    }

    // MARK: - 헤더

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(info.departureTime)
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .tracking(-1)
                .foregroundStyle(AppTheme.Color.primaryText)

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 6) {
                Text("\(info.directionDisplayName) · \(info.scheduleTypeLabel) · \(info.isVia ? "경유" : "직행")")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                HStack(spacing: 6) {
                    if let platform = info.platformNumber {
                        LabelChip(text: "탑승 \(platform)")
                    }
                    if info.isNightFare {
                        Text("심야 요금")
                            .font(AppTheme.Typography.footnote.weight(.bold))
                            .foregroundStyle(AppTheme.Color.nightFare)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 알림 (디자인 캔버스 AlertSetup)

    private var isAlertOn: Bool { alert?.isEnabled == true }

    private var previewAlert: BusAlert {
        BusAlert(busTime: info.departureTime, direction: info.direction, leadMinutes: selectedLead, repeatsWeekdays: repeatsWeekdays)
    }

    private var alertSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("알림")
                .font(AppTheme.Typography.groupTitle)
                .foregroundStyle(AppTheme.Color.primaryText)

            HStack(spacing: 8) {
                ForEach(BusAlert.leadOptions, id: \.self) { lead in
                    let isSelected = lead == selectedLead
                    Button {
                        guard selectedLead != lead else { return }
                        selectedLead = lead
                        UISelectionFeedbackGenerator().selectionChanged()
                        if isAlertOn { Task { await arm() } }
                    } label: {
                        Text("\(lead)분 전")
                            .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                            .monospacedDigit()
                            .foregroundStyle(isSelected ? AppTheme.Color.screenBackground : AppTheme.Color.primaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isSelected ? AppTheme.Color.primaryText : AppTheme.Color.surfaceSecondary)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(.top, 10)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("알림 시점")

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("평일마다 반복")
                        .font(AppTheme.Typography.rowBody)
                        .foregroundStyle(AppTheme.Color.primaryText)
                    Text("월–금 같은 시각에 알려드려요. 공휴일은 건너뛰어요")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Toggle("평일마다 반복", isOn: $repeatsWeekdays)
                    .labelsHidden()
                    .tint(AppTheme.Color.accent)
                    .onChange(of: repeatsWeekdays) { _ in
                        if isAlertOn { Task { await arm() } }
                    }
            }
            .padding(.leading, 16)
            .padding(.trailing, 14)
            .padding(.vertical, 12)
            .secondarySurface(cornerRadius: 12)
            .padding(.top, 10)

            if isAlertOn {
                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(AppTheme.Color.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(previewAlert.alertTime)에 알려드릴게요")
                                .font(AppTheme.Typography.rowBody.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.Color.primaryText)
                            Text(previewAlert.repeatText)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Color.secondaryText)
                        }
                    }
                    .accessibilityElement(children: .combine)

                    Spacer(minLength: 0)

                    Button {
                        Task { await disarm() }
                    } label: {
                        Text("알림 끄기")
                            .font(AppTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Color.primaryText)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(Capsule().fill(AppTheme.Color.secondaryButton))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 14)
            } else {
                Button {
                    Task { await arm() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bell")
                            .font(.system(size: 16, weight: .semibold))
                        Text("\(previewAlert.alertTime)에 알림 받기")
                            .monospacedDigit()
                    }
                }
                .buttonStyle(.primaryAction)
                .padding(.top, 14)
                .accessibilityLabel("알림 꺼짐")
                .accessibilityHint("탭하여 출발 \(selectedLead)분 전 알림을 설정합니다")
            }
        }
    }

    private func arm() async {
        let wasOn = isAlertOn
        let granted = await onSetAlert(selectedLead, repeatsWeekdays)
        guard granted else { return }
        alert = previewAlert
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if !wasOn {
            notificationToast = ToastMessage(icon: "bell.fill", message: "\(info.departureTime) 버스 알림이 켜졌습니다")
        }
    }

    private func disarm() async {
        await onRemoveAlert()
        alert = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        notificationToast = ToastMessage(icon: "bell.slash.fill", message: "\(info.departureTime) 버스 알림이 꺼졌습니다")
    }

    // MARK: - 요금

    private var fareSection: some View {
        let base = info.fare
        let effective = info.isNightFare ? (info.nightFare ?? base) : base

        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader(info.isNightFare ? "심야 요금" : "요금", reportKind: .fare, reportLabel: "요금 정보 수정 제보")

            HStack(spacing: 8) {
                fareTile(label: "성인", amount: effective)
                fareTile(label: "청소년", amount: Int(Double(effective) * 0.8))
                fareTile(label: "어린이", amount: Int(Double(effective) * 0.52))
            }

            fareNote
        }
    }

    /// "22:10 이후 심야 요금 3,000원 · 청소년·어린이는 추정값" 한 줄
    private var fareNote: some View {
        var note = Text("")
        if !info.isNightFare, let nightFare = info.nightFare, let start = info.nightFareStartTime {
            note = Text(start).foregroundColor(AppTheme.Color.nightFare).fontWeight(.bold)
                + Text(" 이후 심야 요금 \(formattedFare(nightFare))원 · ")
        }
        note = note + Text("청소년·어린이는 추정값")
        return note
            .font(AppTheme.Typography.caption)
            .monospacedDigit()
            .foregroundStyle(AppTheme.Color.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func sectionHeader(_ title: String, reportKind: QuickReportKind, reportLabel: String) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Typography.groupTitle)
                .foregroundStyle(AppTheme.Color.primaryText)
            Spacer(minLength: 0)
            EditReportLink(accessibilityLabel: reportLabel) {
                quickReport = QuickReportContext(entry: reportKind, info: info)
            }
            .padding(.trailing, -8)
        }
        .frame(height: 22)
    }

    private func fareTile(label: String, amount: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppTheme.Typography.footnote)
                .foregroundStyle(AppTheme.Color.secondaryText)
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(formattedFare(amount))
                    .font(AppTheme.Typography.rowTime.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.primaryText)
                Text("원")
                    .font(AppTheme.Typography.footnote)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .secondarySurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(amount)원")
    }

    private func formattedFare(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    // MARK: - 정류장

    private var stopsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("정류장", reportKind: .stops, reportLabel: "정류장 정보 수정 제보")

            if info.stops.isEmpty {
                Text("정류장 정보를 불러올 수 없습니다")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(info.stops.enumerated()), id: \.element.id) { index, stop in
                        StopTimelineRow(
                            name: stop.name,
                            time: estimatedTime(at: index),
                            role: index == 0 ? .departure : (index == info.stops.count - 1 ? .destination : .intermediate)
                        )
                    }
                }

                if info.stops.count > 2 {
                    Text("중간 정류장 시각은 출발 기준 예상값입니다")
                        .font(AppTheme.Typography.footnote)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }
            }
        }
    }

    /// 출발 정류장은 출발 시각, 종점은 도착 예상, 중간 정류장은 1분 간격 예상.
    private func estimatedTime(at index: Int) -> String {
        if index == 0 { return info.departureTime }
        if index == info.stops.count - 1 { return info.arrivalTime }
        return DateService.timeByAdding(minutes: index, to: info.departureTime) ?? "--:--"
    }
}

// MARK: - 정류장 타임라인 행

struct StopTimelineRow: View {
    enum Role { case departure, intermediate, destination }

    let name: String
    let time: String
    let role: Role

    var body: some View {
        HStack(spacing: 12) {
            Text(time)
                .font(AppTheme.Typography.caption.weight(role == .intermediate ? .medium : .semibold))
                .monospacedDigit()
                .foregroundStyle(role == .intermediate ? AppTheme.Color.secondaryText : AppTheme.Color.primaryText)
                .frame(width: 48, alignment: .leading)

            ZStack {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(AppTheme.Color.divider)
                        .frame(width: 2)
                        .opacity(role == .departure ? 0 : 1)
                    Rectangle()
                        .fill(AppTheme.Color.divider)
                        .frame(width: 2)
                        .opacity(role == .destination ? 0 : 1)
                }
                marker
            }
            .frame(width: 16)

            Text(name)
                .font(role == .intermediate ? AppTheme.Typography.rowBody : AppTheme.Typography.rowTitle)
                .foregroundStyle(AppTheme.Color.primaryText)
                .lineLimit(1)

            Spacer(minLength: 0)

            if role != .intermediate {
                Text(role == .departure ? "출발" : "도착")
                    .font(AppTheme.Typography.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
        }
        .frame(height: role == .intermediate ? 40 : 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(time) \(name)\(role == .departure ? ", 출발 정류장" : role == .destination ? ", 종점" : "")")
    }

    @ViewBuilder
    private var marker: some View {
        switch role {
        case .departure:
            Circle().fill(AppTheme.Color.accent).frame(width: 12, height: 12)
        case .destination:
            Circle()
                .stroke(AppTheme.Color.primaryText, lineWidth: 2.5)
                .background(Circle().fill(AppTheme.Color.sheetBackground))
                .frame(width: 12, height: 12)
        case .intermediate:
            Circle().fill(AppTheme.Color.tertiaryText).frame(width: 7, height: 7)
        }
    }
}

// MARK: - 버튼 스타일 지우개 (조건부 스타일 전환용)

struct AnyButtonStyle: ButtonStyle {
    private let makeBodyClosure: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        makeBodyClosure = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        makeBodyClosure(configuration)
    }
}

// MARK: - Preview

#Preview {
    BusDetailView(
        info: BusDetailInfo(
            departureTime: "07:20",
            arrivalTime: "07:46",
            durationMinutes: 26,
            isVia: false,
            isNightFare: false,
            fare: 2500,
            nightFare: 3000,
            platformNumber: "20번 홈",
            stops: [],
            direction: .jangyuToSasang,
            directionDisplayName: "장유 → 사상",
            scheduleTypeLabel: "평일",
            nightFareStartTime: "22:10",
            isNotificationEnabled: false
        ),
        alert: nil,
        onSetAlert: { _, _ in true },
        onRemoveAlert: {}
    )
    .preferredColorScheme(.dark)
}
