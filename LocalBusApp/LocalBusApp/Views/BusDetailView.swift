import SwiftUI

// MARK: - 버스 상세 시트 뷰

struct BusDetailView: View {
    let info: BusDetailInfo
    @State private var isNotificationEnabled: Bool
    let onNotificationTap: () async -> Void

    init(info: BusDetailInfo, onNotificationTap: @escaping () async -> Void) {
        self.info = info
        self._isNotificationEnabled = State(initialValue: info.isNotificationEnabled)
        self.onNotificationTap = onNotificationTap
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                headerSection

                timeHeroSection

                sectionDivider

                notificationRow

                if info.platformNumber != nil {
                    sectionDivider
                    platformSection
                }

                sectionDivider

                fareSection

                sectionDivider

                stopsSection
            }
            .padding(.bottom, 40)
        }
        .background(HomeDashboardTheme.screenBackground.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 헤더

    private var headerSection: some View {
        HStack(spacing: 8) {
            Text(info.directionDisplayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HomeDashboardTheme.primaryText)

            Spacer()

            // 직행/경유 배지
            Text(info.isVia ? "경유" : "직행")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(info.isVia
                    ? HomeDashboardTheme.timetableSecondaryText
                    : HomeDashboardTheme.primaryBlue)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(info.isVia
                            ? HomeDashboardTheme.timetablePickerBackground
                            : HomeDashboardTheme.primaryBlue.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(info.isVia
                                    ? HomeDashboardTheme.timetablePickerSelected
                                    : HomeDashboardTheme.primaryBlue.opacity(0.3),
                                        lineWidth: 1)
                        )
                )

            // 평일/주말 배지
            Text(info.scheduleTypeLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(HomeDashboardTheme.timetablePickerBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(HomeDashboardTheme.timetablePickerSelected, lineWidth: 1)
                        )
                )
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - 출발/도착 시간 히어로

    private var timeHeroSection: some View {
        HStack(spacing: 0) {
            // 출발 시간
            VStack(alignment: .leading, spacing: 4) {
                Text("출발")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)

                Text(info.departureTime)
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .tracking(-1)
                    .foregroundStyle(HomeDashboardTheme.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 구분선
            Rectangle()
                .fill(HomeDashboardTheme.border)
                .frame(width: 1, height: 64)

            // 도착 예정 + 소요시간
            VStack(alignment: .trailing, spacing: 4) {
                Text("도착 예정")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)

                Text(info.arrivalTime)
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .tracking(-1)
                    .foregroundStyle(HomeDashboardTheme.primaryText)

                HStack(spacing: 4) {
                    Text("약 \(info.durationMinutes)분 소요")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)

                    if info.isNightFare {
                        Text("심야")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(HomeDashboardTheme.cardBackground.opacity(0.5))
    }

    // MARK: - 알림 토글

    private var notificationRow: some View {
        HStack(spacing: 12) {
            Image(systemName: isNotificationEnabled ? "bell.fill" : "bell")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isNotificationEnabled
                    ? HomeDashboardTheme.primaryBlue
                    : HomeDashboardTheme.timetableSecondaryText)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("출발 5분 전 알림")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(HomeDashboardTheme.primaryText)

                Text("\(info.departureTime) 출발 기준")
                    .font(.system(size: 12))
                    .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isNotificationEnabled },
                set: { _ in
                    isNotificationEnabled.toggle()
                    Task { await onNotificationTap() }
                }
            ))
            .labelsHidden()
            .tint(HomeDashboardTheme.primaryBlue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - 플랫폼 번호

    private var platformSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "signpost.right")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(HomeDashboardTheme.primaryBlue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("탑승 홈")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)

                Text("\(info.platformNumber ?? "")번 홈")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HomeDashboardTheme.primaryText)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - 요금

    private var fareSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("요금")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            HStack(spacing: 0) {
                fareItem(label: info.isNightFare ? "심야 요금" : "기본 요금",
                         amount: info.isNightFare ? (info.nightFare ?? info.fare) : info.fare,
                         isHighlighted: true)

                if let nightFare = info.nightFare, !info.isNightFare {
                    Rectangle()
                        .fill(HomeDashboardTheme.border)
                        .frame(width: 1, height: 40)

                    fareItem(label: "심야 요금", amount: nightFare, isHighlighted: false)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private func fareItem(label: String, amount: Int, isHighlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)

            Text(formattedFare(amount))
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(isHighlighted
                    ? HomeDashboardTheme.primaryText
                    : HomeDashboardTheme.timetableSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formattedFare(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: amount)) ?? "\(amount)") + "원"
    }

    // MARK: - 정류장 목록

    private var stopsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("정류장")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)

            ForEach(Array(info.stops.enumerated()), id: \.element.id) { index, stop in
                StopRowView(
                    stop: stop,
                    isFirst: index == 0,
                    isLast: index == info.stops.count - 1,
                    isSelected: false,
                    onTap: {}
                )
                .padding(.horizontal, 12)
            }
        }
    }

    // MARK: - 구분선

    private var sectionDivider: some View {
        Rectangle()
            .fill(HomeDashboardTheme.border.opacity(0.6))
            .frame(height: 1)
            .padding(.horizontal, 20)
    }
}
