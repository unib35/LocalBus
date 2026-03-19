import SwiftUI
import UIKit

enum HomeDashboardTheme {
    static let screenBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 2/255,   green: 6/255,   blue: 15/255,  alpha: 1)
            : UIColor(red: 240/255, green: 246/255, blue: 255/255, alpha: 1)
    })
    static let border = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 31/255,  green: 41/255,  blue: 55/255,  alpha: 1)
            : UIColor(red: 191/255, green: 219/255, blue: 254/255, alpha: 1)
    })
    static let primaryText = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? .white
            : UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1)
    })
    static let secondaryText = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 156/255, green: 163/255, blue: 175/255, alpha: 1)
            : UIColor(red: 55/255,  green: 65/255,  blue: 81/255,  alpha: 1)
    })
    static let tertiaryText = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 107/255, green: 114/255, blue: 128/255, alpha: 1)
            : UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1)
    })
    static let segmentBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 15/255,  green: 23/255,  blue: 42/255,  alpha: 1)
            : UIColor(red: 219/255, green: 234/255, blue: 254/255, alpha: 1)
    })
    static let heroStart = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 6/255,   green: 18/255,  blue: 46/255,  alpha: 1)
            : UIColor(red: 30/255,  green: 64/255,  blue: 175/255, alpha: 1)
    })
    static let heroEnd = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 12/255,  green: 24/255,  blue: 52/255,  alpha: 1)
            : UIColor(red: 29/255,  green: 78/255,  blue: 216/255, alpha: 1)
    })
    static let heroOverlay = Color.white.opacity(0.06)
    static let cardBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 11/255,  green: 15/255,  blue: 24/255,  alpha: 1)
            : UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1)
    })
    static let noteBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 10/255,  green: 22/255,  blue: 48/255,  alpha: 1)
            : UIColor(red: 239/255, green: 246/255, blue: 255/255, alpha: 1)
    })
    static let iconBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 30/255,  green: 41/255,  blue: 59/255,  alpha: 1)
            : UIColor(red: 219/255, green: 234/255, blue: 254/255, alpha: 1)
    })
    static let chipBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 31/255,  green: 41/255,  blue: 55/255,  alpha: 1)
            : UIColor(red: 219/255, green: 234/255, blue: 254/255, alpha: 1)
    })
    static let sheetBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 30/255,  green: 30/255,  blue: 30/255,  alpha: 1)
            : UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1)
    })
    static let listCardBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 28/255,  green: 28/255,  blue: 30/255,  alpha: 1)
            : UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1)
    })
    static let listDivider = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 56/255,  green: 56/255,  blue: 58/255,  alpha: 1)
            : UIColor(red: 229/255, green: 231/255, blue: 235/255, alpha: 1)
    })
    static let success = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 16/255,  green: 185/255, blue: 129/255, alpha: 1)
            : UIColor(red: 5/255,   green: 150/255, blue: 105/255, alpha: 1)
    })
    static let primaryBlue = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 59/255,  green: 130/255, blue: 246/255, alpha: 1)
            : UIColor(red: 37/255,  green: 99/255,  blue: 235/255, alpha: 1)
    })
    static let departureGreen = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 74/255,  green: 222/255, blue: 128/255, alpha: 1)
            : UIColor(red: 22/255,  green: 163/255, blue: 74/255,  alpha: 1)
    })
    // 시간표 전용 (Zinc 팔레트)
    static let timetablePickerBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 24/255,  green: 24/255,  blue: 27/255,  alpha: 1)
            : UIColor(red: 241/255, green: 245/255, blue: 249/255, alpha: 1)
    })
    static let timetablePickerBorder = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 39/255,  green: 39/255,  blue: 42/255,  alpha: 1)
            : UIColor(red: 203/255, green: 213/255, blue: 225/255, alpha: 1)
    })
    static let timetablePickerSelected = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 63/255,  green: 63/255,  blue: 70/255,  alpha: 1)
            : UIColor(red: 186/255, green: 230/255, blue: 253/255, alpha: 1)
    })
    static let timetableMutedText = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 113/255, green: 113/255, blue: 122/255, alpha: 1)
            : UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1)
    })
    static let timetableSecondaryText = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 161/255, green: 161/255, blue: 170/255, alpha: 1)
            : UIColor(red: 71/255,  green: 85/255,  blue: 105/255, alpha: 1)
    })
    static let timetableNextBadge = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 191/255, green: 219/255, blue: 254/255, alpha: 1)
            : UIColor(red: 29/255,  green: 78/255,  blue: 216/255, alpha: 1)
    })
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
                    .foregroundStyle(HomeDashboardTheme.primaryText)

                Text(locationText)
                    .font(HomeDashboardTypography.headerLabel)
                    .foregroundStyle(HomeDashboardTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onNotificationTap) {
                Image(systemName: isNotificationEnabled ? "bell.fill" : "bell")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(HomeDashboardTheme.primaryText)
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

            if minuteText.isEmpty {
                Text(descriptionText)
                    .font(HomeDashboardTypography.heroValue)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.bottom, 6)
            } else {
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
            }

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
                .tint(HomeDashboardTheme.primaryText)
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
                    .foregroundStyle(HomeDashboardTheme.primaryText)

                Spacer()

                Text(badgeText)
                    .font(HomeDashboardTypography.sectionBadge)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(HomeDashboardTheme.primaryBlue)
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
                    .stroke(HomeDashboardTheme.border, lineWidth: 1)

                Image(systemName: "bus.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(HomeDashboardTheme.primaryBlue)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 8) {
                Text(bus.departureTime)
                    .font(HomeDashboardTypography.busTime)
                    .monospacedDigit()
                    .foregroundStyle(HomeDashboardTheme.primaryText)

                Text("\(destinationName) 도착 예정 ~\(bus.arrivalTime)")
                    .font(HomeDashboardTypography.busArrival)
                    .foregroundStyle(HomeDashboardTheme.secondaryText)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 10) {
                Text(bus.relativeText)
                    .font(bus.statusKind == .onTime ? HomeDashboardTypography.busRelativeStrong : HomeDashboardTypography.busRelativeMuted)
                    .foregroundStyle(bus.statusKind == .onTime ? HomeDashboardTheme.primaryText : HomeDashboardTheme.secondaryText)

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
                    .foregroundStyle(HomeDashboardTheme.primaryText)
            } else {
                Circle()
                    .fill(bus.statusKind == .nextDay ? HomeDashboardTheme.secondaryText : HomeDashboardTheme.success)
                    .frame(width: 7, height: 7)
            }

            Text(bus.statusText)
                .font(HomeDashboardTypography.statusChip)
                .foregroundStyle(HomeDashboardTheme.primaryText)
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

