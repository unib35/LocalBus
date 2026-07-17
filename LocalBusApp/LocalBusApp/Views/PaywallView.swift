import SwiftUI
import StoreKit

struct PaywallView: View {

    @EnvironmentObject private var store: StoreService
    @Environment(\.dismiss) private var dismiss

    @State private var errorMessage: String?
    @State private var showRestoreAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        header
                        benefits
                        purchaseSection
                        footer
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("장유시외버스 Pro")
            .navigationBarTitleDisplayMode(.inline)
            .legacyToolbarBackground(HomeDashboardTheme.screenBackground.opacity(0.95))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(HomeDashboardTheme.primaryText)
                }
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
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(HomeDashboardTheme.primaryBlue)
                .padding(20)
                .background(HomeDashboardTheme.primaryBlue.opacity(0.12))
                .clipShape(Circle())

            Text("장유시외버스를 더 편리하게")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(HomeDashboardTheme.primaryText)

            Text("Pro로 업그레이드하고\n모든 기능을 잠금 해제하세요")
                .font(.system(size: 14))
                .foregroundStyle(HomeDashboardTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 0) {
            BenefitRow(
                icon: "rectangle.stack.fill",
                title: "위젯 기능 사용",
                description: "홈 화면 위젯에서 다음 버스 시간을 바로 확인"
            )
            rowDivider
            BenefitRow(
                icon: "nosign",
                title: "광고 없는 깔끔한 화면",
                description: "향후 추가될 모든 광고에서 자유로워집니다"
            )
            rowDivider
            BenefitRow(
                icon: "heart.fill",
                title: "개발자 후원",
                description: "지속적인 시간표 업데이트에 도움이 됩니다"
            )
        }
        .padding(.vertical, 4)
        .glassCard(cornerRadius: 12, fallback: HomeDashboardTheme.cardBackground)
        .fallbackCardBorder(cornerRadius: 12, color: HomeDashboardTheme.border)
    }

    @ViewBuilder
    private var purchaseSection: some View {
        if store.isPro {
            proActiveView
        } else if let product = store.proProduct {
            purchaseButton(for: product)
        } else if store.isLoadingProducts {
            ProgressView()
                .tint(HomeDashboardTheme.primaryText)
                .padding(.vertical, 20)
        } else {
            Text("상품을 불러올 수 없습니다")
                .font(.system(size: 13))
                .foregroundStyle(HomeDashboardTheme.secondaryText)
                .padding(.vertical, 20)
        }
    }

    private var proActiveView: some View {
        VStack(spacing: 8) {
            Label("Pro 이용 중", systemImage: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HomeDashboardTheme.success)
            Text("모든 기능을 사용할 수 있습니다")
                .font(.system(size: 13))
                .foregroundStyle(HomeDashboardTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassCard(cornerRadius: 12, fallback: HomeDashboardTheme.cardBackground)
        .fallbackCardBorder(cornerRadius: 12, color: HomeDashboardTheme.border)
    }

    private func purchaseButton(for product: Product) -> some View {
        Button {
            Task { await buy(product) }
        } label: {
            ZStack {
                VStack(spacing: 4) {
                    Text("\(product.displayPrice) · 한 번 결제로 영구 이용")
                        .font(.system(size: 16, weight: .semibold))
                    Text("자동 결제 없음")
                        .font(.system(size: 12))
                        .opacity(0.85)
                }
                .opacity(store.purchaseInFlight ? 0 : 1)

                if store.purchaseInFlight {
                    ProgressView().tint(HomeDashboardTheme.primaryForeground)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(HomeDashboardTheme.primaryForeground)
            .tintedGlass(
                HomeDashboardTheme.primaryBlue.opacity(0.85),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous),
                fallback: HomeDashboardTheme.primaryBlue,
                interactive: true
            )
        }
        .buttonStyle(.plain)
        .disabled(store.purchaseInFlight)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            Button {
                Task { await restore() }
            } label: {
                Text("구매 복원")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(HomeDashboardTheme.primaryBlue)
            }
            .disabled(store.purchaseInFlight)

            HStack(spacing: 16) {
                Link("이용약관", destination: URL(string: "https://unib35.github.io/LocalBus/terms.html")!)
                Link("개인정보 처리방침", destination: URL(string: "https://unib35.github.io/LocalBus/privacy.html")!)
            }
            .font(.system(size: 12))
            .foregroundStyle(HomeDashboardTheme.tertiaryText)
        }
        .padding(.top, 4)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(HomeDashboardTheme.border)
            .frame(height: 0.5)
            .padding(.leading, 60)
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

// MARK: - Subviews

private struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HomeDashboardTheme.primaryBlue)
                .frame(width: 32, height: 32)
                .background(HomeDashboardTheme.primaryBlue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HomeDashboardTheme.primaryText)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(HomeDashboardTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    PaywallView()
        .environmentObject(StoreService())
        .preferredColorScheme(.dark)
}
