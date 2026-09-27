import SwiftUI

/// 에러 화면. 캐시·번들 시간표까지 모두 없을 때만 홈 대신 표시된다.
/// (연결만 끊긴 경우는 홈 상단 배너로 안내한다 — MainView 참고)
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Image(systemName: "wifi.slash")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(AppTheme.Color.secondaryText)

            Text("시간표를 불러오지 못했어요")
                .font(AppTheme.Typography.sheetTitle)
                .foregroundStyle(AppTheme.Color.primaryText)
                .padding(.top, 20)

            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            Text("네트워크 연결을 확인한 뒤 다시 시도해 주세요. 한 번 불러온 시간표는 이후 연결 없이도 볼 수 있어요.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                    Text("다시 시도")
                }
            }
            .buttonStyle(.primaryAction)
            .padding(.top, 28)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(AmbientBackground())
    }
}

// MARK: - Preview

#Preview {
    ErrorView(message: "시간표를 불러올 수 없습니다.") {
        print("Retry tapped")
    }
    .preferredColorScheme(.dark)
}
