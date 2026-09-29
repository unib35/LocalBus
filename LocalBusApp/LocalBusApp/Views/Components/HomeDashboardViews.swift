import SwiftUI

// MARK: - 홈 대시보드 컴포넌트 (디자인 캔버스 개선안)
//
// 구성: RouteHeaderView(공통) → NextBusHeroCard → UpcomingBusListView → 서비스 요약 한 줄.
// 강조색은 히어로의 남은 시간("12분 후 출발")에만 쓴다. 운행 종료 뒤에는 같은 히어로가 내일 첫차를 보여주고
// '지금 탈 버스'가 아니므로 강조색을 쓰지 않는다.

// MARK: - 다음 버스 히어로

struct NextBusHeroCard: View {
    /// "다음 버스" / "오늘 운행 종료 · 내일 첫차"
    var label: String = "다음 버스"
    let departureTime: String
    let arrivalTime: String
    /// "12분 후 출발" / "내일 06:20 출발"
    let untilText: String
    /// 지금 탈 버스일 때만 강조색
    var isUntilAccent: Bool = true
    let durationText: String
    let basis: TrafficBasis
    /// 아직 출발 1시간 전이 아니어서 교통을 반영하지 않은 상태
    var awaitsTrafficWindow: Bool = false
    let destinationName: String
    let isNotificationEnabled: Bool
    /// 알림이 켜져 있으면 울릴 시각 ("18:25") — 버튼이 "18:25 알림 예약됨"으로 바뀐다
    var alertTime: String? = nil
    /// 알림이 꺼져 있을 때 버튼 문구. nil이면 "18:30 버스 5분 전 알림"
    var alertTitle: String? = nil
    let onDetail: () -> Void
    let onNotificationTap: () -> Void

    private var alertButtonText: String {
        isNotificationEnabled
            ? "\(alertTime ?? departureTime) 알림 예약됨"
            : (alertTitle ?? "\(departureTime) 버스 5분 전 알림")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onDetail) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(label)
                        Spacer()
                        HStack(spacing: 2) {
                            Text("상세")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                    }
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.secondaryText)

                    HStack(alignment: .bottom, spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("출발")
                                .font(AppTheme.Typography.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Color.secondaryText)
                            Text(departureTime)
                                .font(AppTheme.Typography.etaTime)
                                .monospacedDigit()
                                .tracking(-1)
                                .foregroundStyle(AppTheme.Color.primaryText)
                                .lineLimit(1)
                                .fixedSize()
                        }

                        Spacer(minLength: 4)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppTheme.Color.tertiaryText)
                            .padding(.bottom, 10)

                        Spacer(minLength: 4)

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(destinationName) 도착 예상")
                                .font(AppTheme.Typography.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Color.secondaryText)
                                .lineLimit(1)
                            HStack(alignment: .lastTextBaseline, spacing: 5) {
                                Text("약")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(AppTheme.Color.secondaryText)
                                Text(arrivalTime)
                                    .font(AppTheme.Typography.etaTime)
                                    .monospacedDigit()
                                    .tracking(-1)
                                    .foregroundStyle(AppTheme.Color.primaryText)
                                    .lineLimit(1)
                            }
                            .fixedSize()
                        }
                    }
                    .minimumScaleFactor(0.8)

                    HStack(spacing: 6) {
                        Text(untilText)
                            .fontWeight(.bold)
                            .foregroundStyle(isUntilAccent ? AppTheme.Color.accent : AppTheme.Color.primaryText)
                        Text("·")
                            .foregroundStyle(AppTheme.Color.tertiaryText)
                        Text(durationText)
                            .foregroundStyle(AppTheme.Color.primaryText)
                    }
                    .font(AppTheme.Typography.rowValue.weight(.semibold))
                    .monospacedDigit()

                    TrafficBasisLine(basis: basis, awaitsTrafficWindow: awaitsTrafficWindow)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(label) \(departureTime) 출발, \(destinationName) 약 \(arrivalTime) 도착 예상, \(untilText)")
            .accessibilityHint("탭하면 버스 상세를 봅니다")

            Button(action: onNotificationTap) {
                HStack(spacing: 8) {
                    Image(systemName: isNotificationEnabled ? "bell.fill" : "bell")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isNotificationEnabled ? AppTheme.Color.accent : AppTheme.Color.primaryText)
                    Text(alertButtonText)
                        .monospacedDigit()
                }
            }
            .buttonStyle(SecondaryButtonStyle(height: 46))
            .accessibilityLabel(alertButtonText)
            .accessibilityValue(isNotificationEnabled ? "켜짐" : "꺼짐")
            .accessibilityHint(isNotificationEnabled ? "탭하여 알림을 끕니다" : "탭하여 5분 전 알림을 설정합니다")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: AppTheme.Radius.hero)
    }
}

/// 도착 예상의 근거 한 줄: 채운 점(교통 반영) · 빈 고리(시간표 기준) · 스피너(갱신 중) · 오프라인
struct TrafficBasisLine: View {
    let basis: TrafficBasis
    /// 먼 시간대·내일 출발편이면 "출발 1시간 전부터 교통 반영"으로 알린다
    var awaitsTrafficWindow: Bool = false
    var font: Font = AppTheme.Typography.footnote
    var color: Color = AppTheme.Color.secondaryText

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(spacing: 7) {
                TrafficBasisDot(basis: basis)
                Text(ArrivalEstimator.statusText(for: basis, awaitsTrafficWindow: awaitsTrafficWindow, now: context.date))
            }
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .frame(height: 16)
        }
        .accessibilityElement(children: .combine)
    }
}

struct TrafficBasisDot: View {
    let basis: TrafficBasis

    var body: some View {
        switch basis {
        case .live:
            Circle().fill(AppTheme.Color.accent).frame(width: 8, height: 8)
        case .timetable:
            Circle().stroke(AppTheme.Color.secondaryText, lineWidth: 1.5).frame(width: 8, height: 8)
        case .refreshing:
            ProgressView().controlSize(.mini).tint(AppTheme.Color.secondaryText).frame(width: 12, height: 12)
        case .offline:
            Image(systemName: "wifi.slash")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.Color.warning)
        }
    }
}

// MARK: - 로딩

struct DashboardLoadingCard: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(AppTheme.Color.primaryText)
                .scaleEffect(1.15)

            Text("시간표를 불러오는 중")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Color.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .surfaceCard(cornerRadius: AppTheme.Radius.hero)
    }
}

// MARK: - 이어지는 버스

struct UpcomingBusListView: View {
    var title: String = "이어지는 버스"
    var footer: String? = nil
    let buses: [UpcomingBusSnapshot]
    let isVia: (String) -> Bool
    /// 알림이 걸린 버스면 울릴 시각 ("07:45"), 아니면 nil
    var alertTime: (String) -> String? = { _ in nil }
    /// 행을 누르면 버스 상세로
    var onSelect: ((String) -> Void)? = nil
    let onShowTimetable: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(AppTheme.Typography.groupTitle)
                    .foregroundStyle(AppTheme.Color.primaryText)

                Spacer()

                Button(action: onShowTimetable) {
                    HStack(spacing: 2) {
                        Text("전체 시간표")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    // 보이는 줄 높이는 22, 터치 영역은 44
                    .frame(height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(height: 22)

            if buses.isEmpty {
                Text("선택한 시간표에 남아 있는 운행 정보가 없어요.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .surfaceCard()
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text("출발").frame(width: 58, alignment: .leading)
                        Spacer(minLength: 0)
                        Text("예상 도착").frame(width: 78, alignment: .trailing)
                        Text("기준").frame(width: 90, alignment: .trailing)
                    }
                    .font(AppTheme.Typography.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .padding(.horizontal, 16)
                    .frame(height: 30)
                    .accessibilityHidden(true)

                    ForEach(buses) { bus in
                        RowDivider()
                        UpcomingBusRow(
                            bus: bus,
                            isVia: isVia(bus.departureTime),
                            alertTime: alertTime(bus.departureTime),
                            onSelect: onSelect.map { select in { select(bus.departureTime) } }
                        )
                    }
                }
                .surfaceCard()
            }

            if let footer {
                Text(footer)
                    .font(AppTheme.Typography.footnote)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .padding(.horizontal, 2)
                    .padding(.top, 2)
            }
        }
    }
}

struct UpcomingBusRow: View {
    let bus: UpcomingBusSnapshot
    let isVia: Bool
    var alertTime: String? = nil
    var onSelect: (() -> Void)? = nil

    var body: some View {
        Button {
            onSelect?()
        } label: {
            HStack(spacing: 0) {
                Text(bus.departureTime)
                    .font(AppTheme.Typography.rowTime)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .frame(width: 58, alignment: .leading)

                HStack(spacing: 7) {
                    if isVia {
                        ViaChip()
                    } else {
                        Text("직행")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Color.secondaryText)
                    }

                    if alertTime != nil {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.Color.accent)
                            .accessibilityLabel("알림 예약됨")
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                Text("약 \(bus.arrivalTime)")
                    .font(AppTheme.Typography.rowValue.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .frame(width: 78, alignment: .trailing)

                HStack(spacing: 6) {
                    if bus.usesTraffic {
                        Circle().fill(AppTheme.Color.accent).frame(width: 8, height: 8)
                    } else {
                        Circle().stroke(AppTheme.Color.secondaryText, lineWidth: 1.5).frame(width: 8, height: 8)
                    }
                    Text(bus.usesTraffic ? "교통 반영" : "시간표 기준")
                        .font(AppTheme.Typography.footnote.weight(.semibold))
                        .foregroundStyle(bus.usesTraffic ? AppTheme.Color.primaryText : AppTheme.Color.secondaryText)
                }
                .frame(width: 90, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onSelect == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = ["\(bus.departureTime) 출발", isVia ? "경유" : "직행", "약 \(bus.arrivalTime) 도착 예상", bus.usesTraffic ? "교통 반영" : "시간표 기준"]
        if let alertTime { parts.append("\(alertTime) 알림 예약됨") }
        return parts.joined(separator: ", ")
    }
}

/// 목록 행의 "경유" 칩 (12 semibold, 모서리 6)
struct ViaChip: View {
    var body: some View {
        Text("경유")
            .font(AppTheme.Typography.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.Color.primaryText.opacity(0.83))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(AppTheme.Color.secondaryButton)
            )
    }
}

struct DashboardNoticeCard: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Color.primaryText)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(AppTheme.Typography.noticeTitle)
                    .foregroundStyle(AppTheme.Color.primaryText)

                Text(message)
                    .font(AppTheme.Typography.caption)
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .surfaceCard()
    }
}

// MARK: - Preview

#Preview("Hero") {
    VStack(spacing: 24) {
        NextBusHeroCard(
            departureTime: "18:30",
            arrivalTime: "19:04",
            untilText: "12분 후 출발",
            durationText: "예상 소요 34분",
            basis: .live(updatedAt: Date().addingTimeInterval(-180)),
            destinationName: "사상",
            isNotificationEnabled: false,
            onDetail: {},
            onNotificationTap: {}
        )

        UpcomingBusListView(
            buses: [
                UpcomingBusSnapshot(id: "1", departureTime: "07:35", relativeText: "27분 후", arrivalTime: "08:01", statusText: "정시 운행", statusKind: .onTime),
                UpcomingBusSnapshot(id: "2", departureTime: "07:50", relativeText: "42분 후", arrivalTime: "08:16", statusText: "정시 운행", statusKind: .onTime),
                UpcomingBusSnapshot(id: "3", departureTime: "08:20", relativeText: "1시간 12분 후", arrivalTime: "08:46", statusText: "정시 운행", statusKind: .onTime)
            ],
            isVia: { $0 == "08:20" },
            onShowTimetable: {}
        )

        NextBusHeroCard(
            label: "오늘 운행 종료 · 내일 첫차",
            departureTime: "06:20",
            arrivalTime: "06:46",
            untilText: "내일 06:20 출발",
            isUntilAccent: false,
            durationText: "기본 소요 26분",
            basis: .timetable,
            awaitsTrafficWindow: true,
            destinationName: "사상",
            isNotificationEnabled: false,
            alertTitle: "내일 첫차 5분 전 알림",
            onDetail: {},
            onNotificationTap: {}
        )
    }
    .padding(20)
    .background(AppTheme.Color.screenBackground)
    .preferredColorScheme(.dark)
}
