import SwiftUI

// HomeDashboardTheme / HomeDashboardTypography 는 DesignSystem.swift 로 이전됨.
// typealias 를 통해 이 파일에서 기존 이름을 그대로 사용할 수 있음.

struct DashboardHeaderView: View {
    let locationText: String
    let isNotificationEnabled: Bool
    let onNotificationTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(locationText)
                .font(HomeDashboardTypography.headerLabel)
                .foregroundStyle(HomeDashboardTheme.secondaryText)
                .lineLimit(1)

            Spacer()

            Button(action: onNotificationTap) {
                Image(systemName: isNotificationEnabled ? "bell.fill" : "bell")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(HomeDashboardTheme.primaryText)
                    .frame(width: 44, height: 44)
                    .glassCard(in: Circle(), fallback: HomeDashboardTheme.iconBackground, interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isNotificationEnabled ? "알림 켜짐" : "알림 꺼짐")
            .accessibilityHint(isNotificationEnabled ? "탭하여 알림을 끕니다" : "탭하여 다음 버스 5분 전 알림을 설정합니다")
        }
    }
}

struct NextBusHeroCard: View {
    let minuteText: String
    let unitText: String
    let descriptionText: String
    let progress: Double
    let departureTime: String
    let arrivalTime: String
    let nextBusTime: String

    var body: some View {
        VStack(spacing: 0) {
            Text("다음 버스")
                .font(HomeDashboardTypography.heroEyebrow)
                .tracking(1.2)
                .foregroundStyle(HomeDashboardTheme.heroText.opacity(0.75))
                .padding(.bottom, 14)

            if minuteText.isEmpty {
                Text(descriptionText)
                    .font(HomeDashboardTypography.heroValue)
                    .foregroundStyle(HomeDashboardTheme.heroText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.bottom, 6)
            } else {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(minuteText)
                        .font(HomeDashboardTypography.heroValue)
                        .monospacedDigit()
                        .foregroundStyle(HomeDashboardTheme.heroText)

                    Text(unitText)
                        .font(HomeDashboardTypography.heroUnit)
                        .foregroundStyle(HomeDashboardTheme.heroText.opacity(0.88))
                        .padding(.bottom, 10)
                }

                Text(descriptionText)
                    .font(HomeDashboardTypography.heroDescription)
                    .foregroundStyle(HomeDashboardTheme.heroText.opacity(0.75))
                    .padding(.top, 6)
            }

            progressBar
                .padding(.top, 28)

            HStack(spacing: 0) {
                dashboardMetaBlock(title: "출발 시간", value: departureTime, alignment: .leading)

                Rectangle()
                    .fill(HomeDashboardTheme.border)
                    .frame(width: 1, height: 36)

                dashboardMetaBlock(title: "예상 도착", value: arrivalTime, alignment: .center)

                Rectangle()
                    .fill(HomeDashboardTheme.border)
                    .frame(width: 1, height: 36)

                dashboardMetaBlock(title: "다음 배차", value: nextBusTime, alignment: .trailing)
            }
            .padding(.top, 24)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(HomeDashboardTheme.border.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 22, x: 0, y: 14)
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(HomeDashboardTheme.border)

                Capsule()
                    .fill(HomeDashboardTheme.heroText)
                    .frame(width: max(proxy.size.width * progress, 24))
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }

    private var heroBackground: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [HomeDashboardTheme.heroStart, HomeDashboardTheme.heroEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(HomeDashboardTheme.heroOverlay)
                .frame(width: 170, height: 170)
                .offset(x: 72, y: -78)
        }
    }

    private func dashboardMetaBlock(
        title: String,
        value: String,
        alignment: HorizontalAlignment,
        suffix: String? = nil
    ) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(title)
                .font(HomeDashboardTypography.heroMetaLabel)
                .tracking(0.5)
                .foregroundStyle(HomeDashboardTheme.heroText.opacity(0.75))

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(HomeDashboardTypography.heroMetaValue)
                    .monospacedDigit()
                    .foregroundStyle(HomeDashboardTheme.heroText)

                if let suffix {
                    Text(suffix)
                        .font(HomeDashboardTypography.heroMetaSuffix)
                        .foregroundStyle(HomeDashboardTheme.heroText.opacity(0.75))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : alignment == .center ? .center : .trailing)
    }
}

struct DashboardLoadingCard: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(HomeDashboardTheme.primaryText)
                .scaleEffect(1.15)

            Text("시간표를 불러오는 중")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(HomeDashboardTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250)
        .glassCard(cornerRadius: 20, fallback: HomeDashboardTheme.cardBackground)
        .fallbackCardBorder(cornerRadius: 20, color: HomeDashboardTheme.border)
    }
}

struct DashboardServiceEndedCard: View {
    let firstBusTime: String
    let remainingText: String

    var body: some View {
        VStack(spacing: 12) {
            Text("오늘 운행 종료")
                .font(HomeDashboardTypography.heroDescription)
                .foregroundStyle(HomeDashboardTheme.heroText.opacity(0.7))

            Text(firstBusTime)
                .font(HomeDashboardTypography.heroValue)
                .monospacedDigit()
                .foregroundStyle(HomeDashboardTheme.heroText)
                .minimumScaleFactor(0.8)

            Text("다음 첫차")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(HomeDashboardTheme.heroText)

            Text(remainingText)
                .font(HomeDashboardTypography.heroDescription)
                .foregroundStyle(HomeDashboardTheme.heroText.opacity(0.7))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 34)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [HomeDashboardTheme.heroStart, HomeDashboardTheme.heroEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(HomeDashboardTheme.border, lineWidth: 1)
        )
    }
}

struct UpcomingBusesSectionView: View {
    let title: String
    let badgeText: String
    let buses: [UpcomingBusSnapshot]
    let destinationName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(HomeDashboardTypography.sectionTitle)
                    .foregroundStyle(HomeDashboardTheme.primaryText)

                Spacer()

                Text(badgeText)
                    .font(HomeDashboardTypography.sectionBadge)
                    .foregroundStyle(HomeDashboardTheme.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassCard(cornerRadius: 6, fallback: HomeDashboardTheme.chipBackground)
            }

            if buses.isEmpty {
                DashboardNoticeCard(
                    title: "표시할 버스가 없습니다",
                    message: "선택한 시간표에 남아 있는 운행 정보가 없어요.",
                    systemImage: "clock.badge.xmark"
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(buses) { bus in
                        UpcomingBusCardView(
                            bus: bus,
                            destinationName: destinationName
                        )
                    }
                }
            }
        }
    }
}

struct UpcomingBusCardView: View {
    let bus: UpcomingBusSnapshot
    let destinationName: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(bus.departureTime)
                    .font(HomeDashboardTypography.busTime)
                    .monospacedDigit()
                    .foregroundStyle(HomeDashboardTheme.primaryText)

                Text("\(destinationName) 예상 도착 ~\(bus.arrivalTime)")
                    .font(HomeDashboardTypography.busArrival)
                    .foregroundStyle(HomeDashboardTheme.secondaryText)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 6) {
                Text(bus.relativeText)
                    .font(bus.statusKind == .onTime ? HomeDashboardTypography.busRelativeStrong : HomeDashboardTypography.busRelativeMuted)
                    .foregroundStyle(bus.statusKind == .onTime ? HomeDashboardTheme.primaryText : HomeDashboardTheme.secondaryText)

                statusLabel
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 14, fallback: HomeDashboardTheme.cardBackground)
        .fallbackCardBorder(cornerRadius: 14, color: HomeDashboardTheme.border)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bus.departureTime) 출발, \(destinationName) 예상 도착 \(bus.arrivalTime), \(bus.statusText)")
    }

    @ViewBuilder
    private var statusLabel: some View {
        Text(bus.statusText)
            .font(HomeDashboardTypography.statusChip)
            .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch bus.statusKind {
        case .delayed, .lastBus:
            return AppTheme.Color.nightFare
        case .nightBus:
            return .purple
        case .nextDay:
            return HomeDashboardTheme.secondaryText
        case .onTime:
            return HomeDashboardTheme.secondaryText
        }
    }
}

struct FirstLastBusSectionView: View {
    let firstBusTime: String
    let lastBusTime: String

    var body: some View {
        HStack(spacing: 12) {
            chip(label: "첫차", time: firstBusTime)
            chip(label: "막차", time: lastBusTime)
        }
    }

    private func chip(label: String, time: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(HomeDashboardTheme.tertiaryText)
            Text(time)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(HomeDashboardTheme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 12, fallback: HomeDashboardTheme.cardBackground)
        .fallbackCardBorder(cornerRadius: 12, color: HomeDashboardTheme.border)
    }
}

struct DashboardNoticeCard: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(HomeDashboardTheme.primaryText)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(HomeDashboardTypography.noticeTitle)
                    .foregroundStyle(HomeDashboardTheme.primaryText)

                Text(message)
                    .font(HomeDashboardTypography.noticeBody)
                    .lineSpacing(3)
                    .foregroundStyle(HomeDashboardTheme.secondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCard(cornerRadius: 14, fallback: HomeDashboardTheme.noteBackground)
        .fallbackCardBorder(cornerRadius: 14, color: HomeDashboardTheme.border)
    }
}

