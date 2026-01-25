import SwiftUI

// MARK: - 첫차/막차 정보

/// 첫차와 막차 시간 표시 뷰
struct FirstLastBusInfo: View {
    let firstBus: String
    let lastBus: String

    var body: some View {
        HStack(spacing: 16) {
            InfoChip(icon: "sunrise.fill", title: "첫차", time: firstBus, color: .orange)
            InfoChip(icon: "sunset.fill", title: "막차", time: lastBus, color: .purple)
        }
    }
}

// MARK: - 정보 칩

/// 아이콘과 함께 정보를 표시하는 칩 컴포넌트
struct InfoChip: View {
    let icon: String
    let title: String
    let time: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(time)
                    .font(.subheadline.bold())
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview("FirstLastBusInfo") {
    FirstLastBusInfo(firstBus: "06:00", lastBus: "22:00")
        .padding()
}

#Preview("InfoChip") {
    InfoChip(icon: "sunrise.fill", title: "첫차", time: "06:00", color: .orange)
        .padding()
}
