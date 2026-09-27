import SwiftUI

// MARK: - 홈 대시보드 컴포넌트 (디자인 캔버스 개선안)
//
// 구성: RouteHeaderView(공통) → NextBusHeroCard → UpcomingBusListView → 서비스 요약 한 줄.
// 강조색은 히어로의 남은 시간 숫자에만 쓴다.

// MARK: - 다음 버스 히어로

struct NextBusHeroCard: View {
    let minuteText: String
    let unitText: String
    let descriptionText: String
    let departureTime: String
    let arrivalTime: String
    let destinationName: String
    let durationMinutes: Int
    let isNotificationEnabled: Bool
    let onNotificationTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("다음 버스")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.secondaryText)

                Spacer()

                Text("\(departureTime) 출발")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.primaryText)
            }

            countdown
                .padding(.top, 10)

            JourneyStripView(
                departureTime: departureTime,
                arrivalTime: arrivalTime,
                destinationName: destinationName,
                durationMinutes: durationMinutes
            )
            .padding(.top, 18)

            notificationButton
                .padding(.top, 18)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: AppTheme.Radius.hero)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var countdown: some View {
        if minuteText.isEmpty {
            Text(descriptionText)
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.Color.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(minuteText)
                        .font(AppTheme.Typography.heroNumber)
                        .monospacedDigit()
                        .tracking(-2)
                        .foregroundStyle(AppTheme.Color.accent)

                    Text("\(unitText) 후")
                        .font(AppTheme.Typography.heroUnitLabel)
                        .foregroundStyle(AppTheme.Color.primaryText)
                }

                // "1시간" 처럼 단위가 시간이면 남은 분을 설명 줄에 보여준다.
                if unitText != "분" {
                    Text(descriptionText)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(minuteText)\(unitText) 후 출발")
        }
    }

    private var notificationButton: some View {
        Button(action: onNotificationTap) {
            HStack(spacing: 8) {
                Image(systemName: isNotificationEnabled ? "bell.fill" : "bell")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isNotificationEnabled ? AppTheme.Color.accent : AppTheme.Color.primaryText)
                Text(isNotificationEnabled
                     ? "\(departureTime) 버스 5분 전에 알려드려요"
                     : "\(departureTime) 버스 5분 전 알림")
            }
        }
        .buttonStyle(SecondaryButtonStyle(height: 46))
        .accessibilityLabel(isNotificationEnabled ? "알림 켜짐" : "알림 꺼짐")
        .accessibilityHint(isNotificationEnabled ? "탭하여 알림을 끕니다" : "탭하여 다음 버스 5분 전 알림을 설정합니다")
    }
}

// MARK: - 로딩 / 운행 종료

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

struct DashboardServiceEndedCard: View {
    let firstBusTime: String
    let remainingText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("오늘 운행 종료")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.secondaryText)
                Spacer()
                Text("내일 첫차")
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.primaryText)
            }

            Text(firstBusTime)
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .tracking(-2)
                .foregroundStyle(AppTheme.Color.primaryText)
                .padding(.top, 10)

            Text(remainingText)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Color.secondaryText)
                .padding(.top, 4)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: AppTheme.Radius.hero)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 이어지는 버스

struct UpcomingBusListView: View {
    let buses: [UpcomingBusSnapshot]
    let isVia: (String) -> Bool
    let onShowTimetable: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("이어지는 버스")
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
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }

            if buses.isEmpty {
                Text("선택한 시간표에 남아 있는 운행 정보가 없어요.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .surfaceCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(buses.enumerated()), id: \.element.id) { index, bus in
                        UpcomingBusRow(bus: bus, isVia: isVia(bus.departureTime))
                        if index < buses.count - 1 {
                            RowDivider()
                        }
                    }
                }
                .surfaceCard()
            }
        }
    }
}

struct UpcomingBusRow: View {
    let bus: UpcomingBusSnapshot
    let isVia: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(bus.departureTime)
                .font(AppTheme.Typography.rowTime)
                .monospacedDigit()
                .foregroundStyle(AppTheme.Color.primaryText)
                .frame(width: 60, alignment: .leading)

            HStack(spacing: 6) {
                if isVia {
                    LabelChip(text: "경유")
                } else {
                    Text("직행")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }

                if let statusLabel {
                    Text(statusLabel)
                        .font(AppTheme.Typography.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Color.nightFare)
                }
            }

            Spacer(minLength: 8)

            Text(bus.relativeText)
                .font(AppTheme.Typography.rowValue)
                .monospacedDigit()
                .foregroundStyle(bus.statusKind == .nextDay ? AppTheme.Color.secondaryText : AppTheme.Color.primaryText)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// 막차·심야만 라벨로 보여준다. "정시 운행"은 정보가 없어 생략.
    private var statusLabel: String? {
        switch bus.statusKind {
        case .lastBus, .nightBus, .nextDay:
            return bus.statusText
        case .onTime, .delayed:
            return nil
        }
    }

    private var accessibilityText: String {
        var parts = ["\(bus.departureTime) 출발", isVia ? "경유" : "직행", bus.relativeText]
        if let statusLabel { parts.append(statusLabel) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - 안내 카드

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
            minuteText: "12",
            unitText: "분",
            descriptionText: "후 출발",
            departureTime: "07:20",
            arrivalTime: "07:46",
            destinationName: "사상",
            durationMinutes: 26,
            isNotificationEnabled: false,
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

        DashboardServiceEndedCard(firstBusTime: "06:20", remainingText: "6시간 40분 후 첫차")
    }
    .padding(20)
    .background(AppTheme.Color.screenBackground)
    .preferredColorScheme(.dark)
}
