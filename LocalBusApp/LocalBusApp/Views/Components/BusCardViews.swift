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
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("다음 버스")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(nextBusTime)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("남은 시간")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(countdownText)
                        .font(.system(size: 32, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }

            HStack {
                Text(direction)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                Button(action: onNotificationTap) {
                    HStack(spacing: 4) {
                        Image(systemName: isNotificationScheduled ? "bell.fill" : "bell")
                        Text(isNotificationScheduled ? "알림 ON" : "5분 전 알림")
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isNotificationScheduled ? Color.white : Color.white.opacity(0.2))
                    .foregroundStyle(isNotificationScheduled ? .blue : .white)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.blue, Color.indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// MARK: - 로딩 카드

/// 데이터 로딩 중 표시 카드
struct LoadingCard: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("시간표 로딩 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - 운행 종료 카드

/// 운행 종료 안내 카드
struct EndOfServiceCard: View {
    let firstBusTime: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 44))
                .foregroundStyle(.indigo)

            Text("오늘 운행이 종료되었습니다")
                .font(.headline)

            Text("내일 첫차는 \(firstBusTime) 입니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
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

#Preview("LoadingCard") {
    LoadingCard()
        .padding()
}

#Preview("EndOfServiceCard") {
    EndOfServiceCard(firstBusTime: "06:00")
        .padding()
}
