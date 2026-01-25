import SwiftUI

// MARK: - 오프라인 배너

/// 오프라인 상태 알림 배너
struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text("오프라인 모드")
                .font(.caption.bold())
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.gray)
    }
}

// MARK: - 공지 배너

/// 공지사항 표시 배너
struct NoticeBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "megaphone.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .lineLimit(2)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }
}

// MARK: - Preview

#Preview("OfflineBanner") {
    OfflineBanner()
}

#Preview("NoticeBanner") {
    NoticeBanner(message: "설 연휴 특별 운행 안내")
}
