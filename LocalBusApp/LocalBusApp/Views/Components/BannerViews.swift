import SwiftUI

// MARK: - 오프라인 배너

/// 오프라인 상태 알림 배너
struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text("오프라인 모드")
                .font(.caption.weight(.medium))
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

// MARK: - 공지 배너

/// 공지사항 표시 배너
struct NoticeBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.subheadline)
            Text(message)
                .font(.subheadline)
                .lineLimit(2)
            Spacer()
        }
        .foregroundStyle(.primary)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

// MARK: - Preview

#Preview("OfflineBanner") {
    OfflineBanner()
}

#Preview("NoticeBanner") {
    NoticeBanner(message: "설 연휴 특별 운행 안내")
}
