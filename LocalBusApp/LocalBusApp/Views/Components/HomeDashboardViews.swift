import SwiftUI

enum HomeDashboardTheme {
    static let screenBackground = Color(red: 2.0 / 255.0, green: 6.0 / 255.0, blue: 15.0 / 255.0)
    static let border = Color(red: 31.0 / 255.0, green: 41.0 / 255.0, blue: 55.0 / 255.0)
    static let secondaryText = Color(red: 156.0 / 255.0, green: 163.0 / 255.0, blue: 175.0 / 255.0)
    static let tertiaryText = Color(red: 107.0 / 255.0, green: 114.0 / 255.0, blue: 128.0 / 255.0)
    static let segmentBackground = Color(red: 15.0 / 255.0, green: 23.0 / 255.0, blue: 42.0 / 255.0)
    static let heroStart = Color(red: 6.0 / 255.0, green: 18.0 / 255.0, blue: 46.0 / 255.0)
    static let heroEnd = Color(red: 12.0 / 255.0, green: 24.0 / 255.0, blue: 52.0 / 255.0)
    static let heroOverlay = Color.white.opacity(0.06)
    static let cardBackground = Color(red: 11.0 / 255.0, green: 15.0 / 255.0, blue: 24.0 / 255.0)
    static let noteBackground = Color(red: 10.0 / 255.0, green: 22.0 / 255.0, blue: 48.0 / 255.0)
    static let iconBackground = Color(red: 30.0 / 255.0, green: 41.0 / 255.0, blue: 59.0 / 255.0)
    static let chipBackground = Color(red: 31.0 / 255.0, green: 41.0 / 255.0, blue: 55.0 / 255.0)
    static let success = Color(red: 16.0 / 255.0, green: 185.0 / 255.0, blue: 129.0 / 255.0)
    static let primaryBlue = Color(red: 59.0 / 255.0, green: 130.0 / 255.0, blue: 246.0 / 255.0)
    static let departureGreen = Color(red: 74.0 / 255.0, green: 222.0 / 255.0, blue: 128.0 / 255.0)
    // 시간표 전용 (Zinc 팔레트)
    static let timetablePickerBackground = Color(red: 24.0 / 255.0, green: 24.0 / 255.0, blue: 27.0 / 255.0)
    static let timetablePickerBorder = Color(red: 39.0 / 255.0, green: 39.0 / 255.0, blue: 42.0 / 255.0)
    static let timetablePickerSelected = Color(red: 63.0 / 255.0, green: 63.0 / 255.0, blue: 70.0 / 255.0)
    static let timetableMutedText = Color(red: 113.0 / 255.0, green: 113.0 / 255.0, blue: 122.0 / 255.0)
    static let timetableSecondaryText = Color(red: 161.0 / 255.0, green: 161.0 / 255.0, blue: 170.0 / 255.0)
    static let timetableNextBadge = Color(red: 191.0 / 255.0, green: 219.0 / 255.0, blue: 254.0 / 255.0)
}

enum HomeDashboardTypography {
    static let headerLabel = Font.system(size: 14, weight: .medium)
    static let segmentSelected = Font.system(size: 14, weight: .bold)
    static let segmentDefault = Font.system(size: 14, weight: .medium)
    static let heroEyebrow = Font.system(size: 12, weight: .medium)
    static let heroValue = Font.system(size: 72, weight: .black, design: .rounded)
    static let heroUnit = Font.system(size: 24, weight: .bold)
    static let heroDescription = Font.system(size: 14, weight: .medium)
    static let heroMetaLabel = Font.system(size: 10, weight: .bold)
    static let heroMetaValue = Font.system(size: 20, weight: .bold, design: .monospaced)
    static let heroMetaSuffix = Font.system(size: 12, weight: .medium)
    static let sectionTitle = Font.system(size: 20, weight: .black, design: .rounded)
    static let sectionBadge = Font.system(size: 10, weight: .bold)
    static let busTime = Font.system(size: 18, weight: .bold, design: .monospaced)
    static let busRelativeStrong = Font.system(size: 14, weight: .bold)
    static let busRelativeMuted = Font.system(size: 14, weight: .medium)
    static let busArrival = Font.system(size: 12, weight: .medium)
    static let statusChip = Font.system(size: 12, weight: .medium)
    static let noticeTitle = Font.system(size: 14, weight: .bold)
    static let noticeBody = Font.system(size: 12, weight: .medium)
}

struct DashboardHeaderView: View {
    let locationText: String
    let isNotificationEnabled: Bool
    let onNotificationTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "location.north.line.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text(locationText)
                    .font(HomeDashboardTypography.headerLabel)
                    .foregroundStyle(HomeDashboardTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onNotificationTap) {
                Image(systemName: isNotificationEnabled ? "bell.fill" : "bell")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
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
                .foregroundStyle(HomeDashboardTheme.secondaryText)
                .padding(.bottom, 14)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(minuteText)
                    .font(HomeDashboardTypography.heroValue)
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Text(unitText)
                    .font(HomeDashboardTypography.heroUnit)
                    .foregroundStyle(Color.white.opacity(0.88))
                    .padding(.bottom, 10)
            }

            Text(descriptionText)
                .font(HomeDashboardTypography.heroDescription)
                .foregroundStyle(HomeDashboardTheme.secondaryText)
                .padding(.top, 6)

            progressBar
                .padding(.top, 28)

            HStack(spacing: 0) {
                dashboardMetaBlock(title: "출발 시간", value: departureTime, alignment: .leading)

                Rectangle()
                    .fill(HomeDashboardTheme.border)
                    .frame(width: 1, height: 36)

                dashboardMetaBlock(title: "도착 예정", value: arrivalTime, alignment: .center)

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
                    .fill(.white)
                    .frame(width: max(proxy.size.width * progress, 24))
            }
        }
        .frame(height: 4)
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
                .foregroundStyle(HomeDashboardTheme.secondaryText)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(HomeDashboardTypography.heroMetaValue)
                    .monospacedDigit()
                    .foregroundStyle(.white)

                if let suffix {
                    Text(suffix)
                        .font(HomeDashboardTypography.heroMetaSuffix)
                        .foregroundStyle(HomeDashboardTheme.secondaryText)
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
                .tint(.white)
                .scaleEffect(1.15)

            Text("시간표를 불러오는 중")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(HomeDashboardTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(HomeDashboardTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(HomeDashboardTheme.border, lineWidth: 1)
        )
    }
}

struct DashboardServiceEndedCard: View {
    let firstBusTime: String
    let remainingText: String

    var body: some View {
        VStack(spacing: 12) {
            Text("오늘 운행 종료")
                .font(HomeDashboardTypography.heroDescription)
                .foregroundStyle(HomeDashboardTheme.secondaryText)

            Text(firstBusTime)
                .font(HomeDashboardTypography.heroValue)
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.8)

            Text("다음 첫차")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)

            Text(remainingText)
                .font(HomeDashboardTypography.heroDescription)
                .foregroundStyle(HomeDashboardTheme.secondaryText)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 34)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [HomeDashboardTheme.heroStart, HomeDashboardTheme.cardBackground],
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
                    .foregroundStyle(.white)

                Spacer()

                Text(badgeText)
                    .font(HomeDashboardTypography.sectionBadge)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(HomeDashboardTheme.iconBackground)

                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)

                Image(systemName: "bus.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 8) {
                Text(bus.departureTime)
                    .font(HomeDashboardTypography.busTime)
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Text("\(destinationName) 도착 예정 ~\(bus.arrivalTime)")
                    .font(HomeDashboardTypography.busArrival)
                    .foregroundStyle(HomeDashboardTheme.secondaryText)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 10) {
                Text(bus.relativeText)
                    .font(bus.statusKind == .onTime ? HomeDashboardTypography.busRelativeStrong : HomeDashboardTypography.busRelativeMuted)
                    .foregroundStyle(bus.statusKind == .onTime ? .white : HomeDashboardTheme.secondaryText)

                statusChip
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HomeDashboardTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HomeDashboardTheme.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusChip: some View {
        HStack(spacing: 6) {
            if bus.statusKind == .delayed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .fill(bus.statusKind == .nextDay ? HomeDashboardTheme.secondaryText : HomeDashboardTheme.success)
                    .frame(width: 7, height: 7)
            }

            Text(bus.statusText)
                .font(HomeDashboardTypography.statusChip)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(HomeDashboardTheme.chipBackground)
        .clipShape(Capsule())
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
                .foregroundStyle(.white)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(HomeDashboardTypography.noticeTitle)
                    .foregroundStyle(.white)

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
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HomeDashboardTheme.noteBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HomeDashboardTheme.border, lineWidth: 1)
        )
    }
}

