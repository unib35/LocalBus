import SwiftUI
import FirebaseMessaging
import ActivityKit
import UserNotifications

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
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var viewModel: MainViewModel
    @EnvironmentObject private var storeService: StoreService

    @AppStorage("lastBusReminderUpdateError") private var lastBusUpdateError = ""
    @AppStorage("lastMileAlertEnabled") private var lastMileAlertEnabled = false
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled = true
    @AppStorage("noticeAlertEnabled") private var noticeAlertEnabled = false
    @AppStorage("colorSchemePreference") private var colorSchemeRaw = AppColorScheme.dark.rawValue

    @State private var isUpdatingNotifications = false
    @State private var notificationPermissionGranted = false
    @State private var liveActivityAllowed = false
    @State private var lastBusSummary: String?
    @State private var settingsError: String?
    @State private var showPermissionAlert = false
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
                return "설정할 때 선택한 노선의 막차 30분 전 시각에 매일 알립니다. 아래에서 예약된 노선과 시각을 확인할 수 있습니다."
            case .liveActivity:
                return "출발까지 20분 이내인 버스의 알림을 켜면 잠금화면에 출발 예정·도착 예상 시각을 표시합니다. 실제 운행 상태를 추적하지 않습니다. 예정 시간이 지나면 오래된 정보로 표시되며 앱을 다시 열 때 정리합니다. 더 일찍 예약한 버스는 자동으로 시작되지 않습니다. 시스템에서도 실시간 현황을 허용해야 합니다."
            case .notice:
                return "시간표 변경, 임시 운휴 등 중요한 공지사항을 푸시 알림으로 즉시 전달합니다."
            }
        }
    }

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let shareURL = URL(string: "https://unib35.github.io/LocalBus/")!

    private var colorScheme: AppColorScheme {
        AppColorScheme(rawValue: colorSchemeRaw) ?? .dark
    }

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // v1.0 무료 출시: IAP 미적용 상태이므로 Pro 업그레이드 진입점을 숨긴다.
                    // IAP 도입 시 아래 줄의 주석을 해제하면 결제 화면 진입점이 복원된다.
                    // proSection
                    notificationSection
                    displaySection
                    infoSection
                    dataSection

                    Text("장유시외버스")
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
        .task { if !PreviewRuntime.isRunning { await refreshNotificationState() } }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await refreshNotificationState() } }
        }
        .alert("알림 권한이 필요합니다", isPresented: $showPermissionAlert) {
            Button("설정으로 이동") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("iOS 설정에서 장유시외버스의 알림을 허용해주세요.")
        }
        .alert("설정을 변경하지 못했어요", isPresented: Binding(
            get: { settingsError != nil }, set: { if !$0 { settingsError = nil } }
        )) {
            Button("확인", role: .cancel) { settingsError = nil }
        } message: { Text(settingsError ?? "") }
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
                        .font(.footnote)
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
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("알림")
            if !notificationPermissionGranted {
                Button {
                    Task {
                        if await requestNotificationPermission() { await refreshNotificationState() }
                    }
                } label: {
                    Label("알림 권한을 허용해주세요", systemImage: "bell.badge")
                        .font(.subheadline)
                }
                .padding(.horizontal, 12)
            }
            VStack(spacing: 0) {
                if !notificationPermissionGranted {
                    if lastMileAlertEnabled {
                        Button("예약된 막차 알림 삭제") { Task { await setLastBusReminder(false) } }
                            .font(.subheadline).padding(12)
                    }
                    if noticeAlertEnabled {
                        Button("저장된 공지 구독 해제") { Task { await setNoticeAlerts(false) } }
                            .font(.subheadline).padding(12)
                    }
                }
                notificationRow(title: "막차 30분 전 알림", infoItem: .lastMile,
                    isOn: Binding(get: { lastMileAlertEnabled && notificationPermissionGranted },
                                  set: { enabled in Task { await setLastBusReminder(enabled) } }))
                if !lastBusUpdateError.isEmpty {
                    Text(lastBusUpdateError).font(.footnote).foregroundStyle(.orange).padding(12)
                }
                if let summary = lastBusSummary {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(HomeDashboardTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.bottom, 12)
                    Button("현재 노선으로 다시 설정") {
                        Task { await setLastBusReminder(true) }
                    }
                    .font(.subheadline).padding(.bottom, 12)
                }
                rowDivider
                notificationRow(title: "공지사항 알림", infoItem: .notice,
                    isOn: Binding(get: { noticeAlertEnabled && notificationPermissionGranted },
                                  set: { enabled in Task { await setNoticeAlerts(enabled) } }))
                if isUpdatingNotifications {
                    ProgressView("알림 설정을 확인하는 중")
                        .font(.footnote).padding(12)
                }
            }
            .settingsCard()
            .disabled(isUpdatingNotifications)

            if #available(iOS 17.0, *) {
                notificationRow(title: "잠금화면 카운트다운", infoItem: .liveActivity,
                    isOn: Binding(get: { liveActivityEnabled && liveActivityAllowed }, set: { enabled in
                        if enabled && !ActivityAuthorizationInfo().areActivitiesEnabled {
                            settingsError = "iOS 설정에서 실시간 현황을 허용해주세요."
                            return
                        }
                        liveActivityEnabled = enabled
                        if !enabled { LiveActivityService.shared.endActivity() }
                    }))
                    .settingsCard()
            } else {
                Text("잠금화면 카운트다운은 iOS 17 이상에서 사용할 수 있습니다.")
                    .font(.footnote).foregroundStyle(HomeDashboardTheme.secondaryText)
            }
        }
    }

    @MainActor
    private func requestNotificationPermission() async -> Bool {
        guard !PreviewRuntime.isRunning else { return false }
        let granted = await NotificationService.shared.requestAuthorization()
        notificationPermissionGranted = granted
        if !granted { showPermissionAlert = true }
        return granted
    }

    @MainActor
    private func refreshNotificationState() async {
        guard !PreviewRuntime.isRunning else { return }
        guard !isUpdatingNotifications else { return }
        let status = await NotificationService.shared.authorizationStatus()
        notificationPermissionGranted = status == .authorized || status == .provisional || status == .ephemeral
        if #available(iOS 17.0, *) { liveActivityAllowed = ActivityAuthorizationInfo().areActivitiesEnabled }
        lastBusSummary = await NotificationService.shared.lastBusReminderSummary()
        lastMileAlertEnabled = lastBusSummary != nil
    }

    @MainActor
    private func setLastBusReminder(_ enabled: Bool) async {
        guard !isUpdatingNotifications else { return }
        isUpdatingNotifications = true
        defer { isUpdatingNotifications = false }
        if enabled {
            guard await requestNotificationPermission() else { return }
            do {
                try await viewModel.scheduleLastBusNotification()
                lastMileAlertEnabled = true
                lastBusUpdateError = ""
                lastBusSummary = await NotificationService.shared.lastBusReminderSummary()
                UserDefaults.standard.set(viewModel.selectedDirection.rawValue, forKey: "lastBusDirection")
                toast = ToastMessage(icon: "bell.fill", message: "막차 알림을 설정했습니다")
            } catch { settingsError = error.localizedDescription }
        } else {
            viewModel.cancelLastBusNotification()
            lastMileAlertEnabled = false
            lastBusUpdateError = ""
            lastBusSummary = nil
            UserDefaults.standard.removeObject(forKey: "lastBusDirection")
            toast = ToastMessage(icon: "bell.slash.fill", message: "막차 알림을 껐습니다")
        }
    }

    @MainActor
    private func setNoticeAlerts(_ enabled: Bool) async {
        guard !PreviewRuntime.isRunning else { return }
        guard !isUpdatingNotifications else { return }
        isUpdatingNotifications = true
        defer { isUpdatingNotifications = false }
        if enabled {
            guard await requestNotificationPermission() else { return }
        }
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let completion: @Sendable (Error?) -> Void = { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: ()) }
                }
                if enabled { Messaging.messaging().subscribe(toTopic: AppDelegate.noticeTopic, completion: completion) }
                else { Messaging.messaging().unsubscribe(fromTopic: AppDelegate.noticeTopic, completion: completion) }
            }
            noticeAlertEnabled = enabled
            toast = ToastMessage(icon: "megaphone", message: enabled ? "공지 알림을 켰습니다" : "공지 알림을 껐습니다")
        } catch { settingsError = "공지 알림 설정에 실패했습니다. 네트워크 연결을 확인하고 다시 시도해주세요." }
    }

    private func notificationRow(
        title: String,
        infoItem: NotificationInfoItem,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.body)
                .foregroundStyle(HomeDashboardTheme.primaryText)

            NotificationInfoButton(item: infoItem)

            Spacer()

            Toggle(title, isOn: isOn)
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
                                .font(.body)
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
                        .font(.body)
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
                NavigationLink(destination: BusTipsView(direction: viewModel.selectedDirection, departureStopName: viewModel.currentDepartureStopName)) {
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
                ShareLink(item: shareURL, message: Text("장유·율하–사상 버스 시간표 앱 안내")) {
                    Label("앱 안내 페이지 공유", systemImage: "square.and.arrow.up")
                        .font(.body)
                        .foregroundStyle(HomeDashboardTheme.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .settingsCard()
        }
    }

    // MARK: - 데이터 관리

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("시간표")

            VStack(spacing: 0) {
                // 시간표 기준일
                HStack {
                    Text("시간표 기준일")
                        .font(.body)
                        .foregroundStyle(HomeDashboardTheme.primaryText)
                    Spacer()
                    Text(viewModel.updatedAtText)
                        .font(.system(size: 15))
                        .foregroundStyle(HomeDashboardTheme.secondaryText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                rowDivider

                // 시간표 업데이트
                Button {
                    Task {
                        isRefreshing = true
                        let result = await viewModel.refresh()
                        isRefreshing = false
                        switch result {
                        case .updated:
                            toast = ToastMessage(icon: "checkmark.circle", message: "시간표를 업데이트했습니다")
                        case .alreadyCurrent:
                            toast = ToastMessage(icon: "checkmark.circle", message: "이미 최신 시간표입니다")
                        case .unavailable:
                            toast = ToastMessage(icon: "wifi.slash", message: "업데이트를 확인하지 못해 기존 시간표를 유지합니다")
                        }
                    }
                } label: {
                    HStack {
                        if isRefreshing || viewModel.isCheckingTimetableUpdate {
                            ProgressView()
                                .tint(HomeDashboardTheme.secondaryText)
                                .frame(width: 16, height: 16)
                        }
                        Text(isRefreshing ? "업데이트 중..." : "시간표 업데이트")
                            .font(.body)
                            .foregroundStyle(isRefreshing ? HomeDashboardTheme.secondaryText : HomeDashboardTheme.primaryText)
                        Spacer()
                        if viewModel.hasTimetableUpdate {
                            Text("업데이트 있음")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.12), in: Capsule())
                        } else if viewModel.isOffline {
                            Text("확인 실패")
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
                .disabled(isRefreshing || viewModel.isCheckingTimetableUpdate || viewModel.isUpdatingTimetable)
            }
            .settingsCard()

            Text(timetableUpdateDescription)
                .font(.footnote)
                .foregroundStyle(HomeDashboardTheme.secondaryText)
                .padding(.horizontal, 12)
        }
    }

    private var timetableUpdateDescription: String {
        if viewModel.hasTimetableUpdate { return "새 시간표가 있습니다. 시간표 업데이트를 눌러 적용해주세요." }
        if viewModel.isCheckingTimetableUpdate { return "새 시간표가 있는지 확인하고 있습니다." }
        if viewModel.isOffline { return "업데이트를 확인하지 못했습니다. 저장된 시간표를 사용 중입니다." }
        if viewModel.hasCheckedTimetableUpdate { return "최신 시간표를 사용 중입니다." }
        return "시간표 업데이트를 눌러 새 시간표가 있는지 확인하세요."
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
                .font(.body)
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
                .font(.body)
                .foregroundStyle(HomeDashboardTheme.secondaryText)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title + " 설명")
        .popover(isPresented: $showPopover, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HomeDashboardTheme.primaryText)
                Text(item.description)
                    .font(.footnote)
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
            .environmentObject(StoreService()).defaultAppStorage(PreviewRuntime.defaults)
    }
    .preferredColorScheme(.dark)
}
