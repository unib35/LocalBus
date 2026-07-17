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

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - 설정 화면

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

    enum NotificationInfoItem: String, Identifiable {
        case lastMile
        case liveActivity
        case notice

        var id: String { rawValue }

        var title: String {
            switch self {
            case .lastMile:     return "막차 30분 전 알림"
            case .liveActivity: return "Live Activity"
            case .notice:       return "공지사항 알림"
            }
        }

        var description: String {
            switch self {
            case .lastMile:
                return "매일 막차 출발 30분 전, 자동으로 알림을 보내드립니다. 알림은 매일 반복됩니다."
            case .liveActivity:
                return "알림을 설정한 버스가 20분 이내로 출발할 때 Dynamic Island와 잠금화면에 실시간 카운트다운을 표시합니다."
            case .notice:
                return "시간표 변경, 임시 운휴 등 중요한 공지사항을 푸시 알림으로 즉시 전달합니다."
            }
        }
    }

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let shareMessage = "장유-사상 시외버스 시간표 앱 장유시외버스를 사용해보세요!"

    private var colorScheme: AppColorScheme {
        AppColorScheme(rawValue: colorSchemeRaw) ?? .dark
    }

    var body: some View {
        ZStack {
            HomeDashboardTheme.screenBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // v1.0 무료 출시: IAP 미적용 상태이므로 Pro 업그레이드 진입점을 숨긴다.
                    // IAP 도입 시 아래 줄의 주석을 해제하면 결제 화면 진입점이 복원된다.
                    // proSection
                    notificationSection
                    displaySection
                    infoSection
                    dataSection

                    Text("Bus Schedule App © 2024")
                        .font(.system(size: 11))
                        .foregroundStyle(HomeDashboardTheme.tertiaryText)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .legacyToolbarBackground(HomeDashboardTheme.screenBackground.opacity(0.95))
        .toolbarColorScheme(nil, for: .navigationBar)
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
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(storeService.isPro ? Color.green : HomeDashboardTheme.primaryBlue)
                    .frame(width: 36, height: 36)
                    .background(
                        (storeService.isPro ? Color.green : HomeDashboardTheme.primaryBlue)
                            .opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(storeService.isPro ? "장유시외버스 Pro 이용 중" : "장유시외버스 Pro로 업그레이드")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(HomeDashboardTheme.primaryText)
                    Text(storeService.isPro ? "모든 기능을 사용 중입니다" : "위젯 기능과 광고 제거")
                        .font(.system(size: 13))
                        .foregroundStyle(HomeDashboardTheme.secondaryText)
                }

                Spacer()

                if !storeService.isPro {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HomeDashboardTheme.tertiaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .settingsCard()
    }

    // MARK: - 알림 설정

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("알림 설정")

            // 버스 알림 그룹
            VStack(alignment: .leading, spacing: 0) {
                notificationGroupHeader("버스 알림")

                notificationRow(
                    title: "막차 30분 전 알림",
                    infoItem: .lastMile,
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

                rowDivider

                notificationRow(
                    title: "Live Activity",
                    infoItem: .liveActivity,
                    isOn: $liveActivityEnabled
                )
                .onChange(of: liveActivityEnabled) { enabled in
                    toast = enabled
                        ? ToastMessage(icon: "livephoto", message: "Live Activity가 활성화됩니다")
                        : ToastMessage(icon: "livephoto.slash", message: "Live Activity가 비활성화됩니다")
                }
            }
            .settingsCard()

            // 공지 알림 그룹
            VStack(alignment: .leading, spacing: 0) {
                notificationGroupHeader("공지 알림")

                notificationRow(
                    title: "공지사항 알림",
                    infoItem: .notice,
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
            .settingsCard()
        }
    }

    private func notificationGroupHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(HomeDashboardTheme.secondaryText)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    private func notificationRow(
        title: String,
        infoItem: NotificationInfoItem,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(HomeDashboardTheme.primaryText)

            NotificationInfoButton(item: infoItem)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(HomeDashboardTheme.primaryBlue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - 디스플레이

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("디스플레이")

            VStack(spacing: 0) {
                ForEach(Array(AppColorScheme.allCases.enumerated()), id: \.element.rawValue) { index, scheme in
                    Button {
                        colorSchemeRaw = scheme.rawValue
                    } label: {
                        HStack {
                            Text(scheme.label)
                                .font(.system(size: 16))
                                .foregroundStyle(HomeDashboardTheme.primaryText)
                            Spacer()
                            if colorScheme == scheme {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(HomeDashboardTheme.primaryBlue)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < AppColorScheme.allCases.count - 1 {
                        rowDivider
                    }
                }
            }
            .settingsCard()
        }
    }

    // MARK: - 정보

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("정보")

            VStack(spacing: 0) {
                // 버전 정보
                HStack {
                    Text("버전 정보")
                        .font(.system(size: 16))
                        .foregroundStyle(HomeDashboardTheme.primaryText)
                    Spacer()
                    Text("v\(appVersion)")
                        .font(.system(size: 15))
                        .foregroundStyle(HomeDashboardTheme.secondaryText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                rowDivider

                // 이용 안내
                NavigationLink(destination: BusTipsView()) {
                    infoNavigationRow("버스 이용 안내")
                }
                .buttonStyle(.plain)

                rowDivider

                // 시간표 제보
                NavigationLink(destination: ReportView()) {
                    infoNavigationRow("시간표 제보")
                }
                .buttonStyle(.plain)

                rowDivider

                // 문의하기
                NavigationLink(destination: ContactView()) {
                    infoNavigationRow("문의하기")
                }
                .buttonStyle(.plain)

                rowDivider

                // 이용약관 및 개인정보 처리방침
                NavigationLink(destination: PrivacyPolicyView()) {
                    infoNavigationRow("이용약관 및 개인정보 처리방침")
                }
                .buttonStyle(.plain)

                rowDivider

                // 앱 공유
                ShareLink(item: shareMessage) {
                    infoNavigationRow("앱 공유")
                }
                .buttonStyle(.plain)
            }
            .settingsCard()
        }
    }

    // MARK: - 데이터 관리

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("데이터")

            VStack(spacing: 0) {
                // 시간표 기준일
                HStack {
                    Text("시간표 기준일")
                        .font(.system(size: 16))
                        .foregroundStyle(HomeDashboardTheme.primaryText)
                    Spacer()
                    Text(viewModel.updatedAtText)
                        .font(.system(size: 15))
                        .foregroundStyle(HomeDashboardTheme.secondaryText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                rowDivider

                // 캐시 초기화
                Button {
                    showClearCacheConfirm = true
                } label: {
                    HStack {
                        if isRefreshing {
                            ProgressView()
                                .tint(HomeDashboardTheme.secondaryText)
                                .frame(width: 16, height: 16)
                        }
                        Text(isRefreshing ? "새로고침 중..." : "최신 데이터로 새로고침")
                            .font(.system(size: 16))
                            .foregroundStyle(isRefreshing ? HomeDashboardTheme.secondaryText : HomeDashboardTheme.primaryText)
                        Spacer()
                        if viewModel.isOffline {
                            Text("오프라인")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(HomeDashboardTheme.tertiaryText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(HomeDashboardTheme.border)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
            }
            .settingsCard()

            if viewModel.isOffline {
                Text("네트워크 연결이 없어 저장된 데이터를 사용 중입니다.")
                    .font(.system(size: 13))
                    .foregroundStyle(HomeDashboardTheme.secondaryText)
                    .padding(.horizontal, 12)
            }
        }
    }

    // MARK: - 공지사항 데이터

    private var sampleNotices: [NoticeItem] {
        [
            NoticeItem(
                id: "notice-001",
                title: "2025년 8월 25일부\n운행 시간표 변경 안내",
                date: "2025.08.14",
                author: "관리자",
                isNew: true,
                body: [
                    "안녕하세요. 장유-사상 시외버스 운행 시간표가 2025년 8월 25일부로 일부 변경됩니다.",
                    "이번 변경은 최근 출퇴근 시간대의 교통 혼잡도 증가와 이용객 수요 변화를 반영하여 더 효율적인 배차 간격을 제공하기 위함입니다. 이용에 착오 없으시길 바랍니다.",
                    "자세한 변경 시간표는 아래를 참고해 주시기 바랍니다."
                ],
                timetableSummary: NoticeTimetableSummary(
                    effectiveDate: "2025.08.25",
                    departureLabel: "장유 출발",
                    arrivalLabel: "사상 도착",
                    rows: [
                        NoticeTimetableRow(departure: "06:20", arrival: "06:46", isNew: false),
                        NoticeTimetableRow(departure: "06:40", arrival: "07:06", isNew: true),
                        NoticeTimetableRow(departure: "07:00", arrival: "07:26", isNew: false),
                        NoticeTimetableRow(departure: "07:20", arrival: "07:46", isNew: true),
                        NoticeTimetableRow(departure: "07:35", arrival: "08:01", isNew: false)
                    ],
                    note: "* 도로 사정에 따라 도착 시간이 지연될 수 있습니다.",
                    fullScheduleImageURL: nil
                )
            ),
            NoticeItem(
                id: "notice-002",
                title: "[안내] 시스템 정기 점검에 따른 서비스 일시 중단",
                date: "2023.10.20",
                author: "관리자",
                body: ["정기 서버 점검으로 인해 일부 기능이 일시 중단될 수 있습니다."],
                timetableSummary: nil
            ),
            NoticeItem(
                id: "notice-003",
                title: "추석 연휴 기간 셔틀버스 운행 안내",
                date: "2023.09.25",
                author: "관리자",
                body: ["추석 연휴 기간 동안 주말 시간표로 운행됩니다."],
                timetableSummary: nil
            )
        ]
    }

    // MARK: - 헬퍼 뷰

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .tracking(0.3)
            .foregroundStyle(HomeDashboardTheme.secondaryText)
            .padding(.horizontal, 12)
    }

    private func infoNavigationRow(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(HomeDashboardTheme.primaryText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HomeDashboardTheme.tertiaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(HomeDashboardTheme.border)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }
}

// MARK: - Notification Info Button

private struct NotificationInfoButton: View {
    let item: InfoView.NotificationInfoItem
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(HomeDashboardTheme.tertiaryText)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HomeDashboardTheme.primaryText)
                Text(item.description)
                    .font(.system(size: 13))
                    .foregroundStyle(HomeDashboardTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: 260, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .compactPopoverAdaptation()
            .glassCard(cornerRadius: 12, fallback: HomeDashboardTheme.cardBackground)
        }
    }
}

// MARK: - View Modifier

private struct SettingsCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassCard(cornerRadius: 12, fallback: HomeDashboardTheme.cardBackground)
            .fallbackCardBorder(cornerRadius: 12, color: HomeDashboardTheme.border)
    }
}

private extension View {
    func settingsCard() -> some View {
        modifier(SettingsCardModifier())
    }

    @ViewBuilder
    func compactPopoverAdaptation() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationCompactAdaptation(.popover)
        } else {
            self
        }
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
