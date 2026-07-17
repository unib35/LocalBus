import SwiftUI
import UIKit

// MARK: - 버스 상세 시트 뷰

struct BusDetailView: View {
    let info: BusDetailInfo
    @State private var isNotificationEnabled: Bool
    @State private var notificationToast: ToastMessage?
    let onNotificationTap: () async -> Void

    init(info: BusDetailInfo, onNotificationTap: @escaping () async -> Void) {
        self.info = info
        self._isNotificationEnabled = State(initialValue: info.isNotificationEnabled)
        self.onNotificationTap = onNotificationTap
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                headerSection
                timeHeroCard
                notificationCard

                if info.platformNumber != nil {
                    platformCard
                }

                fareCard
                stopsCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 40)
        }
        .background(HomeDashboardTheme.sheetBackground.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .toast(item: $notificationToast)
    }

    // MARK: - 헤더

    private var headerSection: some View {
        HStack(spacing: 8) {
            Text(info.directionDisplayName)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(HomeDashboardTheme.primaryText)

            Spacer()

            typeBadge(text: info.isVia ? "경유" : "직행",
                      isAccent: !info.isVia)

            typeBadge(text: info.scheduleTypeLabel,
                      isAccent: false)
        }
    }

    private func typeBadge(text: String, isAccent: Bool) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(isAccent
                ? HomeDashboardTheme.primaryBlue
                : HomeDashboardTheme.timetableSecondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isAccent
                        ? HomeDashboardTheme.primaryBlue.opacity(0.12)
                        : HomeDashboardTheme.timetablePickerBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(isAccent
                                ? HomeDashboardTheme.primaryBlue.opacity(0.3)
                                : HomeDashboardTheme.timetablePickerSelected,
                                    lineWidth: 1)
                    )
            )
    }

    // MARK: - 출발/도착 시간 카드

    private var timeHeroCard: some View {
        HStack(spacing: 0) {
            // 출발
            VStack(alignment: .leading, spacing: 4) {
                Text("출발")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(HomeDashboardTheme.departureGreen)

                Text(info.departureTime)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .tracking(-1)
                    .foregroundStyle(HomeDashboardTheme.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 소요시간
            VStack(spacing: 4) {
                Text("\(info.durationMinutes)분")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                if info.isNightFare {
                    Text("심야")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.Color.nightFare)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppTheme.Color.nightFare.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)

            // 도착
            VStack(alignment: .trailing, spacing: 4) {
                Text("예상 도착")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(HomeDashboardTheme.primaryBlue)

                Text(info.arrivalTime)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .tracking(-1)
                    .foregroundStyle(HomeDashboardTheme.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .glassCard(cornerRadius: 12, fallback: HomeDashboardTheme.cardBackground)
        .fallbackCardBorder(cornerRadius: 12, color: HomeDashboardTheme.border)
    }

    // MARK: - 알림 카드

    private var notificationCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("출발 5분 전 알림")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(HomeDashboardTheme.primaryText)
                Text("\(info.departureTime) 출발 기준")
                    .font(.system(.caption, weight: .regular))
                    .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isNotificationEnabled },
                set: { _ in
                    isNotificationEnabled.toggle()
                    let newState = isNotificationEnabled
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    notificationToast = newState
                        ? ToastMessage(icon: "bell.fill", message: "\(info.departureTime) 버스 알림이 켜졌습니다")
                        : ToastMessage(icon: "bell.slash.fill", message: "\(info.departureTime) 버스 알림이 꺼졌습니다")
                    Task { await onNotificationTap() }
                }
            ))
            .labelsHidden()
            .tint(HomeDashboardTheme.primaryBlue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 10, fallback: HomeDashboardTheme.cardBackground)
        .fallbackCardBorder(cornerRadius: 10, color: HomeDashboardTheme.border, lineWidth: 0.5)
    }

    // MARK: - 플랫폼 카드

    private var platformCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("탑승홈")
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                Text(info.platformNumber ?? "")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(HomeDashboardTheme.primaryText)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .tintedGlass(
            HomeDashboardTheme.primaryBlue.opacity(0.25),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous),
            fallback: HomeDashboardTheme.primaryBlue.opacity(0.1)
        )
        .fallbackCardBorder(cornerRadius: 10, color: HomeDashboardTheme.primaryBlue.opacity(0.3))
    }

    // MARK: - 요금 카드

    private var fareCard: some View {
        let baseFare = info.fare
        let effectiveFare = info.isNightFare ? (info.nightFare ?? baseFare) : baseFare

        return VStack(spacing: 16) {
            // 헤더
            Text("요금 정보")
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(HomeDashboardTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(HomeDashboardTheme.border)
                        .frame(height: 1)
                }

            // 요금 행
            VStack(spacing: 0) {
                if info.isNightFare {
                    fareRow(label: "심야 성인", amount: effectiveFare, isNight: true)
                    fareRowDivider
                    fareRow(label: "심야 청소년 (13-18세)", amount: Int(Double(effectiveFare) * 0.8), isNight: true)
                    fareRowDivider
                    fareRow(label: "심야 어린이 (6-12세)", amount: Int(Double(effectiveFare) * 0.52), isNight: true)
                } else {
                    fareRow(label: "성인", amount: baseFare)
                    fareRowDivider
                    fareRow(label: "청소년 (13-18세)", amount: Int(Double(baseFare) * 0.8))
                    fareRowDivider
                    fareRow(label: "어린이 (6-12세)", amount: Int(Double(baseFare) * 0.52))

                    if let nightFare = info.nightFare {
                        Rectangle()
                            .fill(HomeDashboardTheme.border)
                            .frame(height: 1)
                            .padding(.vertical, 4)
                        HStack {
                            HStack(spacing: 4) {
                                Text("심야")
                                    .font(.system(.caption2, weight: .bold))
                                    .foregroundStyle(AppTheme.Color.nightFare)
                                Text("(성인 기준)")
                                    .font(.system(.caption, weight: .medium))
                                    .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                            }
                            Spacer()
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text(formattedFare(nightFare))
                                    .font(.system(.callout, weight: .bold))
                                    .foregroundStyle(HomeDashboardTheme.primaryText)
                                Text("원")
                                    .font(.system(.caption))
                                    .foregroundStyle(HomeDashboardTheme.timetableMutedText)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
            }

            Text("청소년·어린이 요금은 성인 기준 추정값입니다")
                .font(.system(.caption2))
                .foregroundStyle(HomeDashboardTheme.timetableMutedText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .glassCard(cornerRadius: 8, fallback: HomeDashboardTheme.cardBackground)
        .fallbackCardBorder(cornerRadius: 8, color: HomeDashboardTheme.border)
    }

    private func fareRow(label: String, amount: Int, isNight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isNight
                    ? AppTheme.Color.nightFare
                    : HomeDashboardTheme.timetableSecondaryText)
            Spacer()
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(formattedFare(amount))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(HomeDashboardTheme.primaryText)
                Text("원")
                    .font(.system(size: 12))
                    .foregroundStyle(HomeDashboardTheme.timetableMutedText)
            }
        }
        .padding(.vertical, 12)
    }

    private var fareRowDivider: some View {
        Rectangle()
            .fill(HomeDashboardTheme.border.opacity(0.6))
            .frame(height: 0.5)
    }

    private func formattedFare(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    // MARK: - 정류장 카드

    private var stopsCard: some View {
        VStack(spacing: 16) {
            // 헤더
            Text("정류장")
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(HomeDashboardTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(HomeDashboardTheme.border)
                        .frame(height: 1)
                }

            if info.stops.isEmpty {
                Text("정류장 정보를 불러올 수 없습니다")
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(info.stops.enumerated()), id: \.element.id) { index, stop in
                        StopRowView(
                            stop: stop,
                            isFirst: index == 0,
                            isLast: index == info.stops.count - 1,
                            isSelected: false,
                            onTap: {}
                        )
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 8, fallback: HomeDashboardTheme.cardBackground)
        .fallbackCardBorder(cornerRadius: 8, color: HomeDashboardTheme.border)
    }
}

