import SwiftUI
import FirebaseMessaging

// MARK: - 색상 모드 설정

enum AppColorScheme: Int, CaseIterable {
    case light = 0
    case dark = 1
    case system = 2

    var label: String {
        switch self {
        case .light: return "라이트 모드"
        case .dark: return "다크 모드"
        case .system: return "시스템 설정"
        }
    }

    /// 세그먼트용 짧은 라벨
    var shortLabel: String {
        switch self {
        case .light: return "라이트"
        case .dark: return "다크"
        case .system: return "시스템"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - 설정 화면 (디자인 캔버스 개선안)
//
// 알림 토글은 그룹 하나에 모으고 ⓘ 팝오버 대신 항목 아래 한 줄 설명을 둔다.
// 화면 모드는 체크 행 3개 대신 세그먼트 하나. 카드 테두리 없이 구분선만.

struct InfoView: View {
    @ObservedObject var viewModel: MainViewModel
    @EnvironmentObject private var storeService: StoreService

    @AppStorage("lastMileAlertEnabled") private var lastMileAlertEnabled = true
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled = true
    @AppStorage("noticeAlertEnabled") private var noticeAlertEnabled = true
    @AppStorage("colorSchemePreference") private var colorSchemeRaw = AppColorScheme.dark.rawValue

    @State private var showClearCacheConfirm = false
    @State private var isRefreshing = false
    @State private var toast: ToastMessage?
    @State private var showPaywall = false

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let shareMessage = "장유-사상 시외버스 시간표 앱 장유시외버스를 사용해보세요!"

    private var colorScheme: AppColorScheme {
        AppColorScheme(rawValue: colorSchemeRaw) ?? .dark
    }

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    Text("설정")
                        .font(AppTheme.Typography.screenTitle)
                        .foregroundStyle(AppTheme.Color.primaryText)
                        .padding(.top, 8)

                    // v1.0 무료 출시: IAP 미적용 상태이므로 Pro 업그레이드 진입점을 숨긴다.
                    // IAP 도입 시 아래 줄의 주석을 해제하면 결제 화면 진입점이 복원된다.
                    // proSection
                    notificationSection
                    displaySection
                    infoSection
                    dataSection
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .softScrollEdge()
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("캐시를 삭제하면 최신 데이터를 다시 불러옵니다.", isPresented: $showClearCacheConfirm, titleVisibility: .visible) {
            Button("캐시 삭제 및 새로고침", role: .destructive) {
                Task {
                    isRefreshing = true
                    await viewModel.clearCacheAndRefresh()
                    isRefreshing = false
                }
            }
            Button("취소", role: .cancel) {}
        }
        .toast(item: $toast)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(storeService)
        }
    }

    // MARK: - Pro 업그레이드

    private var proSection: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: storeService.isPro ? "checkmark.seal.fill" : "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(storeService.isPro ? AppTheme.Color.accent : AppTheme.Color.primaryText)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(storeService.isPro ? "장유시외버스 Pro 이용 중" : "장유시외버스 Pro로 업그레이드")
                        .font(AppTheme.Typography.rowTitle)
                        .foregroundStyle(AppTheme.Color.primaryText)
                    Text(storeService.isPro ? "모든 기능을 사용 중입니다" : "위젯 기능과 광고 제거")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }

                Spacer()

                if !storeService.isPro {
                    chevron
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .surfaceCard(interactive: true)
    }

    // MARK: - 알림

    private var notificationSection: some View {
        settingsGroup("알림") {
            toggleRow(
                title: "막차 30분 전 알림",
                description: "매일 막차 출발 30분 전에 알려드려요",
                isOn: $lastMileAlertEnabled
            )
            .onChange(of: lastMileAlertEnabled) { enabled in
                Task {
                    if enabled {
                        await viewModel.scheduleLastBusNotification()
                    } else {
                        viewModel.cancelLastBusNotification()
                    }
                }
                toast = enabled
                    ? ToastMessage(icon: "bell.fill", message: "막차 알림이 켜졌습니다")
                    : ToastMessage(icon: "bell.slash.fill", message: "막차 알림이 꺼졌습니다")
            }

            RowDivider()

            toggleRow(
                title: "Live Activity",
                description: "알림 설정한 버스가 20분 안에 출발하면 잠금 화면과 Dynamic Island에 카운트다운",
                isOn: $liveActivityEnabled
            )
            .onChange(of: liveActivityEnabled) { enabled in
                toast = enabled
                    ? ToastMessage(icon: "livephoto", message: "Live Activity가 활성화됩니다")
                    : ToastMessage(icon: "livephoto.slash", message: "Live Activity가 비활성화됩니다")
            }

            RowDivider()

            toggleRow(
                title: "공지사항 알림",
                description: "시간표 변경·임시 운휴 같은 공지를 푸시로 받아요",
                isOn: $noticeAlertEnabled
            )
            .onChange(of: noticeAlertEnabled) { enabled in
                if enabled {
                    Messaging.messaging().subscribe(toTopic: "notices")
                } else {
                    Messaging.messaging().unsubscribe(fromTopic: "notices")
                }
                toast = enabled
                    ? ToastMessage(icon: "megaphone.fill", message: "공지 알림이 켜졌습니다")
                    : ToastMessage(icon: "megaphone.fill", message: "공지 알림이 꺼졌습니다")
            }
        }
    }

    private func toggleRow(title: String, description: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppTheme.Typography.rowBody)
                    .foregroundStyle(AppTheme.Color.primaryText)
                Text(description)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(AppTheme.Color.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 화면

    private var displaySection: some View {
        settingsGroup("화면") {
            VStack(alignment: .leading, spacing: 10) {
                Text("화면 모드")
                    .font(AppTheme.Typography.rowBody)
                    .foregroundStyle(AppTheme.Color.primaryText)

                PillSegment(
                    items: AppColorScheme.allCases,
                    selected: colorScheme,
                    label: { $0.shortLabel },
                    onSelect: { colorSchemeRaw = $0.rawValue }
                )
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.Color.surfaceSecondary)
                )
            }
            .padding(16)
        }
    }

    // MARK: - 정보

    private var infoSection: some View {
        settingsGroup("정보") {
            NavigationLink(destination: BusTipsView()) {
                navigationRow("버스 이용 안내")
            }
            .buttonStyle(.plain)

            RowDivider()

            NavigationLink(destination: ReportView()) {
                navigationRow("시간표 제보")
            }
            .buttonStyle(.plain)

            RowDivider()

            NavigationLink(destination: ContactView()) {
                navigationRow("문의하기")
            }
            .buttonStyle(.plain)

            RowDivider()

            ShareLink(item: shareMessage) {
                navigationRow("앱 공유", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 데이터

    private var dataSection: some View {
        settingsGroup("데이터") {
            HStack {
                Text("시간표 기준일")
                    .font(AppTheme.Typography.rowBody)
                    .foregroundStyle(AppTheme.Color.primaryText)
                Spacer()
                Text(viewModel.updatedAtText)
                    .font(AppTheme.Typography.rowValue)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)

            RowDivider()

            Button {
                showClearCacheConfirm = true
            } label: {
                HStack(spacing: 10) {
                    if isRefreshing {
                        ProgressView()
                            .tint(AppTheme.Color.secondaryText)
                    }
                    Text(isRefreshing ? "새로고침 중..." : "최신 데이터로 새로고침")
                        .font(AppTheme.Typography.rowBody)
                        .foregroundStyle(isRefreshing ? AppTheme.Color.secondaryText : AppTheme.Color.primaryText)
                    Spacer()
                    if viewModel.isOffline {
                        LabelChip(text: "오프라인")
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)
        }
    }

    // MARK: - 푸터

    private var footer: some View {
        HStack(spacing: 6) {
            Text("v\(appVersion)")
            Text("·")
            NavigationLink(destination: PrivacyPolicyView()) {
                Text("이용약관 및 개인정보 처리방침")
                    .underline()
            }
            .buttonStyle(.plain)
        }
        .font(AppTheme.Typography.footnote)
        .foregroundStyle(AppTheme.Color.tertiaryText)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
        .padding(.top, 4)
    }

    // MARK: - 헬퍼 뷰

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppTheme.Typography.groupTitle)
                .foregroundStyle(AppTheme.Color.primaryText)

            VStack(spacing: 0) {
                content()
            }
            .surfaceCard()
        }
    }

    private func navigationRow(_ title: String, systemImage: String? = nil) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Typography.rowBody)
                .foregroundStyle(AppTheme.Color.primaryText)
            Spacer()
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.secondaryText)
            } else {
                chevron
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .contentShape(Rectangle())
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.Color.secondaryText)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InfoView(viewModel: MainViewModel())
            .environmentObject(StoreService())
    }
    .preferredColorScheme(.dark)
}
