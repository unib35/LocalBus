import SwiftUI
import StoreKit

// MARK: - Pro 결제 화면 (디자인 캔버스 개선안 2)
//
// 위젯 미리보기를 소형·중형·잠금 화면으로 바꿔 보며 무엇을 사는지 먼저 보여준다.
// 혜택은 위젯 종류를 구체적으로, 무료로 남는 기능도 밝힌다. 결제 상태는 버튼 안·위에서 제자리로 바뀐다.

struct PaywallView: View {

    private enum PreviewKind: String, CaseIterable, Identifiable {
        case small = "소형"
        case medium = "중형"
        case lock = "잠금 화면"
        var id: String { rawValue }
    }

    @EnvironmentObject private var store: StoreService
    @Environment(\.dismiss) private var dismiss

    @State private var preview: PreviewKind = .small
    @State private var didFail = false
    @State private var didPurchase = false
    @State private var showSuccessGuide = false
    @State private var showRestoreAlert = false

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 0) {
                HStack {
                    Text("장유사상버스 Pro")
                        .font(AppTheme.Typography.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Color.secondaryText)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.Color.primaryText)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(AppTheme.Color.surfaceSecondary))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("닫기")
                }
                .frame(height: 44)
                .padding(.trailing, -8)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        previewStage
                            .padding(.top, 8)

                        previewSwitcher
                            .padding(.top, 10)
                            .frame(maxWidth: .infinity)

                        Text("앱을 열지 않아도\n다음 버스가 보여요")
                            .font(.system(size: 28, weight: .heavy))
                            .lineSpacing(3)
                            .foregroundStyle(AppTheme.Color.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 22)

                        VStack(alignment: .leading, spacing: 12) {
                            benefitRow("홈 화면 위젯 소형·중형·대형")
                            benefitRow("잠금 화면 위젯")
                            benefitRow("광고가 생겨도 Pro에는 없음")
                        }
                        .padding(.top, 18)

                        Text("시간표·버스 알림·Live Activity는 지금처럼 무료예요.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Color.secondaryText)
                            .padding(.top, 14)
                    }
                }
                .softScrollEdge()

                purchaseSection
                    .padding(.top, 12)

                footer
            }
            .padding(.horizontal, 20)
        }
        .task {
            if store.products.isEmpty {
                await store.loadProducts()
            }
        }
        .sheet(isPresented: $showSuccessGuide, onDismiss: { dismiss() }) {
            PaywallSuccessView()
        }
        .alert("구매 복원", isPresented: $showRestoreAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(store.isPro ? "구매가 복원되었어요." : "복원할 구매 내역이 없어요.")
        }
    }

    // MARK: - 미리보기

    private var previewStage: some View {
        ZStack {
            switch preview {
            case .small: smallPreview
            case .medium: mediumPreview
            case .lock: lockPreview
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 178)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 42/255, green: 42/255, blue: 44/255))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(preview.rawValue) 위젯 미리보기: 12분 후, 07:20 출발, 장유에서 사상")
    }

    private var previewSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(PreviewKind.allCases) { kind in
                let isSelected = kind == preview
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { preview = kind }
                } label: {
                    Text(kind.rawValue)
                        .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                        .foregroundStyle(isSelected ? AppTheme.Color.screenBackground : AppTheme.Color.secondaryText)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? AppTheme.Color.primaryText : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppTheme.Color.surface))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("위젯 미리보기 종류")
    }

    private var widgetSurface: Color { Color(white: 0.08) }

    private var smallPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("장유 → 사상")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.Color.secondaryText)
            Spacer(minLength: 0)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("12")
                    .font(.system(size: 50, weight: .heavy, design: .rounded))
                    .tracking(-1.5)
                    .foregroundStyle(AppTheme.Color.accent)
                Text("분")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("07:20 출발")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.top, 5)
            Spacer(minLength: 0)
            Text("다음 07:35 · 07:50")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.Color.secondaryText)
        }
        .padding(14)
        .frame(width: 150, height: 150, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(widgetSurface))
    }

    private var mediumPreview: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text("장유 → 사상 · 평일")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.secondaryText)
                Spacer(minLength: 0)
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text("12")
                        .font(.system(size: 50, weight: .heavy, design: .rounded))
                        .tracking(-1.5)
                        .foregroundStyle(AppTheme.Color.accent)
                    Text("분 후")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 0)
                Text("07:20 출발 · 07:46 도착")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                ForEach([("07:35", "27분"), ("07:50", "42분"), ("08:05", "57분")], id: \.0) { time, remain in
                    HStack {
                        Text(time).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                        Spacer()
                        Text(remain).font(.system(size: 12, weight: .medium)).foregroundStyle(AppTheme.Color.secondaryText)
                    }
                    .frame(height: 30)
                    if time != "08:05" {
                        Rectangle().fill(Color(white: 0.13)).frame(height: 1)
                    }
                }
            }
            .frame(width: 112)
        }
        .padding(14)
        .frame(width: 322, height: 150)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(widgetSurface))
    }

    private var lockPreview: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text("장유 → 사상")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer(minLength: 0)
                Text("07:20 출발 · 12분 후")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Text("다음 07:35 · 07:50")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(width: 164, height: 72, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.14)))

            ZStack {
                Circle().fill(Color.white.opacity(0.14))
                Circle()
                    .trim(from: 0, to: 0.4)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(3)
                VStack(spacing: 1) {
                    Text("12")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("분 후")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            .frame(width: 72, height: 72)
        }
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.Color.accent)
                .frame(width: 20, height: 22)
            Text(text)
                .font(AppTheme.Typography.rowBody)
                .foregroundStyle(AppTheme.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 결제

    @ViewBuilder
    private var purchaseSection: some View {
        if store.isPro && !didPurchase {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pro 이용 중")
                        .font(AppTheme.Typography.rowTitle)
                        .foregroundStyle(AppTheme.Color.primaryText)
                    Text("위젯을 아직 안 넣었다면 추가 방법을 확인해 보세요")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .surfaceCard()

            Button("위젯 추가 방법 보기") { showSuccessGuide = true }
                .buttonStyle(SecondaryButtonStyle(height: 52))
                .padding(.top, 12)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if didFail {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.Color.nightFare)
                        Text("결제가 끝나지 않았어요. 요금은 청구되지 않았어요.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Color.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 12)
                    .accessibilityElement(children: .combine)
                }

                HStack(alignment: .lastTextBaseline) {
                    Text(store.proProduct?.displayPrice ?? "₩--")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.Color.primaryText)
                        .redacted(reason: store.proProduct == nil ? .placeholder : [])
                    Spacer()
                    Text("한 번 결제 · 구독 아님 · 기기 바꿔도 유지")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                if didPurchase {
                    Button {
                        showSuccessGuide = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("구매 완료 · 위젯 추가하러 가기")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(height: 52))
                    .padding(.top, 14)
                } else {
                    Button {
                        if let product = store.proProduct {
                            Task { await buy(product) }
                        } else if !store.isLoadingProducts {
                            Task { await store.loadProducts() }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if store.purchaseInFlight || store.isLoadingProducts {
                                ProgressView().tint(AppTheme.Color.accentForeground)
                            }
                            Text(buyButtonTitle)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(height: 52))
                    .disabled(store.purchaseInFlight || store.isLoadingProducts)
                    .padding(.top, 14)
                }
            }
        }
    }

    private var buyButtonTitle: String {
        if store.purchaseInFlight { return "결제 중…" }
        if store.proProduct != nil { return "Pro 시작하기" }
        return store.isLoadingProducts ? "상품 정보 불러오는 중" : "상품 정보 다시 불러오기"
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Button {
                Task { await restore() }
            } label: {
                Text("이전에 구매했어요 · 구매 복원")
                    .font(AppTheme.Typography.rowValue)
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
            .disabled(store.purchaseInFlight)
            .padding(.top, 6)

            HStack(spacing: 6) {
                Link("이용약관", destination: URL(string: "https://unib35.github.io/LocalBus/terms.html")!)
                Text("·")
                Link("개인정보 처리방침", destination: URL(string: "https://unib35.github.io/LocalBus/privacy.html")!)
            }
            .font(AppTheme.Typography.footnote)
            .foregroundStyle(AppTheme.Color.tertiaryText)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Actions

    private func buy(_ product: Product) async {
        didFail = false
        do {
            let success = try await store.purchase(product)
            if success {
                withAnimation(.easeInOut(duration: 0.2)) { didPurchase = true }
            }
        } catch {
            withAnimation(.easeInOut(duration: 0.2)) { didFail = true }
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
