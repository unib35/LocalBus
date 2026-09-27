import SwiftUI
import StoreKit

// MARK: - Pro 결제 화면 (디자인 캔버스 개선안)
//
// 반짝이 아이콘 대신 실제 위젯 미리보기로 가치를 보여주고, 혜택은 체크 리스트 세 줄,
// 가격과 "구독 아님"을 버튼 위로 분리한다. 닫기는 우상단 ✕ 하나.

struct PaywallView: View {

    @EnvironmentObject private var store: StoreService
    @Environment(\.dismiss) private var dismiss

    @State private var errorMessage: String?
    @State private var showRestoreAlert = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AmbientBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    widgetPreview
                        .padding(.top, 56)
                    header
                    benefits
                    purchaseSection
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .softScrollEdge()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .frame(width: 44, height: 44)
                    .glassCard(in: Circle(), fallback: AppTheme.Color.surfaceSecondary, interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("닫기")
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .task {
            if store.products.isEmpty {
                await store.loadProducts()
            }
        }
        .alert("알림", isPresented: $showRestoreAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(store.isPro ? "구매가 복원되었습니다." : "복원할 구매 내역이 없습니다.")
        }
        .alert("오류", isPresented: .constant(errorMessage != nil)) {
            Button("확인", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 위젯 미리보기

    /// 소형 위젯과 같은 구성의 정적 미리보기. 값은 예시.
    private var widgetPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("장유 → 사상")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.Color.secondaryText)

            Spacer(minLength: 4)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("12")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .tracking(-1.5)
                    .foregroundStyle(AppTheme.Color.accent)
                Text("분 후")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Color.primaryText)
            }

            Text("07:20 출발")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Color.primaryText)
                .padding(.top, 2)

            Spacer(minLength: 4)

            Text("다음 07:35 · 07:50")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.Color.secondaryText)
        }
        .padding(16)
        .frame(width: 170, height: 170, alignment: .topLeading)
        .surfaceCard(cornerRadius: 22)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("홈 화면 위젯 미리보기: 12분 후, 07:20 출발, 장유에서 사상")
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("홈 화면에서 바로\n다음 버스를 확인하세요")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(AppTheme.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("장유시외버스 Pro는 한 번 결제로 계속 쓰는 유료 옵션이에요")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefitRow("홈 화면·잠금 화면 위젯")
            benefitRow("광고 없음 (앞으로도)")
            benefitRow("시간표 업데이트를 이어가는 데 힘이 됩니다")
        }
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.Color.accent)
                .frame(width: 20, height: 22)
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var purchaseSection: some View {
        if store.isPro {
            proActiveView
        } else if let product = store.proProduct {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(product.displayPrice)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.Color.primaryText)
                    Text("한 번 결제 · 구독 아님")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }

                purchaseButton(for: product)
            }
        } else if store.isLoadingProducts {
            ProgressView()
                .tint(AppTheme.Color.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        } else {
            Text("상품 정보를 불러오지 못했어요. 잠시 후 다시 열어 주세요.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Color.secondaryText)
                .padding(.vertical, 12)
        }
    }

    private var proActiveView: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Color.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pro 이용 중")
                    .font(AppTheme.Typography.rowTitle)
                    .foregroundStyle(AppTheme.Color.primaryText)
                Text("모든 기능을 사용할 수 있어요")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
            Spacer()
        }
        .padding(16)
        .surfaceCard()
    }

    private func purchaseButton(for product: Product) -> some View {
        Button {
            Task { await buy(product) }
        } label: {
            ZStack {
                Text("Pro 시작하기")
                    .opacity(store.purchaseInFlight ? 0 : 1)
                if store.purchaseInFlight {
                    ProgressView().tint(AppTheme.Color.accentForeground)
                }
            }
        }
        .buttonStyle(PrimaryButtonStyle(height: 52))
        .disabled(store.purchaseInFlight)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                Task { await restore() }
            } label: {
                Text("구매 복원")
                    .font(AppTheme.Typography.buttonLabel)
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
            .disabled(store.purchaseInFlight)

            HStack(spacing: 6) {
                Link("이용약관", destination: URL(string: "https://unib35.github.io/LocalBus/terms.html")!)
                Text("·")
                Link("개인정보 처리방침", destination: URL(string: "https://unib35.github.io/LocalBus/privacy.html")!)
            }
            .font(AppTheme.Typography.footnote)
            .foregroundStyle(AppTheme.Color.tertiaryText)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Actions

    private func buy(_ product: Product) async {
        do {
            _ = try await store.purchase(product)
        } catch {
            errorMessage = "결제 중 오류가 발생했습니다: \(error.localizedDescription)"
        }
    }

    private func restore() async {
        await store.restorePurchases()
        showRestoreAlert = true
    }
}

#Preview {
    PaywallView()
        .environmentObject(StoreService())
        .preferredColorScheme(.dark)
}
