import SwiftUI

/// 시간표를 하나도 보여줄 수 없을 때(캐시·번들까지 없음)만 홈 대신 표시되는 전체 화면 (디자인 캔버스 OpsLoadFailed).
/// 연결만 끊긴 경우는 홈 상단 배너로 안내한다 — MainView 참고.
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    var onContact: (() -> Void)? = nil

    @State private var isRetrying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("장유사상버스")
                .font(AppTheme.Typography.caption.weight(.bold))
                .foregroundStyle(AppTheme.Color.secondaryText)
                .frame(height: 44)

            Image(systemName: "wifi.slash")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(AppTheme.Color.warning)
                .frame(width: 48, height: 48, alignment: .leading)
                .padding(.top, 96)

            Text("시간표를\n불러오지 못했어요")
                .font(.system(size: 28, weight: .heavy))
                .lineSpacing(3)
                .foregroundStyle(AppTheme.Color.primaryText)
                .padding(.top, 20)
                .accessibilityAddTraits(.isHeader)

            Text("인터넷 연결을 확인한 뒤 다시 시도해 주세요. 한 번 불러오면 그다음부터는 연결이 없어도 볼 수 있어요.")
                .font(AppTheme.Typography.rowValue)
                .lineSpacing(4)
                .foregroundStyle(AppTheme.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            VStack(spacing: 0) {
                infoRow("Wi-Fi 또는 셀룰러 데이터", value: "연결 안 됨")
                RowDivider()
                infoRow("저장된 시간표", value: "없음")
            }
            .surfaceCard()
            .padding(.top, 28)

            Spacer(minLength: 24)

            Button {
                guard !isRetrying else { return }
                isRetrying = true
                onRetry()
                // 재시도 결과는 홈이 대신 보여준다. 여기 남아 있으면 1.5초 뒤 버튼을 되살린다.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { isRetrying = false }
            } label: {
                HStack(spacing: 8) {
                    if isRetrying {
                        ProgressView().tint(AppTheme.Color.accentForeground)
                    }
                    Text(isRetrying ? "다시 불러오는 중" : "다시 시도")
                }
            }
            .buttonStyle(PrimaryButtonStyle(height: 52))
            .disabled(isRetrying)

            if let onContact {
                Button("계속 안 되면 문의하기", action: onContact)
                    .font(AppTheme.Typography.rowValue.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .buttonStyle(.plain)
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AmbientBackground())
    }

    private func infoRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Typography.rowBody)
                .foregroundStyle(AppTheme.Color.primaryText)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.rowValue)
                .foregroundStyle(AppTheme.Color.secondaryText)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview {
    ErrorView(message: "시간표를 불러올 수 없습니다.", onRetry: {}, onContact: {})
        .preferredColorScheme(.dark)
}
