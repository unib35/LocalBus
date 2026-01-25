import SwiftUI

// MARK: - 실시간 카운트다운 카드

/// 다음 버스 실시간 카운트다운 카드
struct LiveCountdownCard: View {
    let nextBusTime: String
    let countdownText: String
    let direction: String
    let isNotificationScheduled: Bool
    let onNotificationTap: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("다음 버스")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(nextBusTime)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text("남은 시간")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(countdownText)
                        .font(.system(size: 36, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                }
            }

            HStack {
                Text(direction)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: onNotificationTap) {
                    HStack(spacing: 4) {
                        Image(systemName: isNotificationScheduled ? "bell.fill" : "bell")
                        Text(isNotificationScheduled ? "알림 ON" : "5분 전 알림")
                            .font(.footnote.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isNotificationScheduled ? Color.primary : Color.clear)
                    .foregroundStyle(isNotificationScheduled ? Color(uiColor: .systemBackground) : .primary)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .padding(24)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 로딩 카드

/// 데이터 로딩 중 표시 카드
struct LoadingCard: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("시간표 로딩 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 운행 종료 카드

/// 운행 종료 안내 카드
struct EndOfServiceCard: View {
    let firstBusTime: String
    let hoursUntilFirstBus: Int
    let minutesUntilFirstBus: Int

    init(firstBusTime: String, hoursUntilFirstBus: Int = 0, minutesUntilFirstBus: Int = 0) {
        self.firstBusTime = firstBusTime
        self.hoursUntilFirstBus = hoursUntilFirstBus
        self.minutesUntilFirstBus = minutesUntilFirstBus
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("운행종료")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)

            VStack(spacing: 4) {
                Text("첫차 \(firstBusTime)")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)

                if hoursUntilFirstBus > 0 || minutesUntilFirstBus > 0 {
                    Text(remainingTimeText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var remainingTimeText: String {
        if hoursUntilFirstBus > 0 {
            return "\(hoursUntilFirstBus)시간 \(minutesUntilFirstBus)분 후"
        } else {
            return "\(minutesUntilFirstBus)분 후"
        }
    }
}

// MARK: - Preview

#Preview("LiveCountdownCard") {
    LiveCountdownCard(
        nextBusTime: "06:30",
        countdownText: "15:30",
        direction: "장유 → 사상",
        isNotificationScheduled: false,
        onNotificationTap: {}
    )
    .padding()
}

#Preview("LiveCountdownCard - Notification ON") {
    LiveCountdownCard(
        nextBusTime: "06:30",
        countdownText: "15:30",
        direction: "장유 → 사상",
        isNotificationScheduled: true,
        onNotificationTap: {}
    )
    .padding()
}

#Preview("LoadingCard") {
    LoadingCard()
        .padding()
}

#Preview("EndOfServiceCard") {
    EndOfServiceCard(
        firstBusTime: "06:00",
        hoursUntilFirstBus: 5,
        minutesUntilFirstBus: 30
    )
    .padding()
}
