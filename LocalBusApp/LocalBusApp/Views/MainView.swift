import SwiftUI
import UIKit

private enum MainTab: Hashable {
    case home
    case timetable
    case stops
    case settings
}

private enum AppDeepLink {
    static let scheme = "jangyusasang"
    static let host = "route"
    static let directionQueryItem = "direction"

    static func isPaywall(_ url: URL) -> Bool {
        url.scheme == scheme && url.host == "paywall"
    }

    static func routeDirection(from url: URL) -> RouteDirection? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == scheme,
              components.host == host,
              let directionValue = components.queryItems?
                .first(where: { $0.name == directionQueryItem })?
                .value else {
            return nil
        }

        return RouteDirection(rawValue: directionValue)
    }
}

/// 메인 화면
struct MainView: View {
    /// 정류장(지도) 탭. 끄려면 false 로 변경.
    private let isStopsTabEnabled = true

    @StateObject private var viewModel: MainViewModel

    init(viewModel: MainViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    @AppStorage("colorSchemePreference") private var colorSchemeRaw = AppColorScheme.dark.rawValue
    @State private var selectedTab: MainTab = .home
    @State private var showPaywall = false
    @State private var showAlertsHub = false
    @State private var showNoticeList = false
    @State private var homeBusDetail: BusDetailInfo?
    // 운영 상황 (디자인 캔버스 Ops*)
    @State private var showRecommendedUpdate = false
    @State private var showRequiredUpdate = false
    @State private var showContactFromError = false
    @State private var hasPresentedLaunchPrompts = false
    @State private var hasShownRecommendedUpdate = false
    @State private var importantNotice: NoticeItem?
    @State private var noticeToOpen: NoticeItem?
    @Environment(\.scenePhase) private var scenePhase
    /// 홈을 오래 켜 둔 동안 만료된 교통값을 다시 받는 주기
    private let trafficTick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @ObservedObject private var notificationHistory = NotificationHistoryStore.shared
    @EnvironmentObject private var storeService: StoreService
    @State private var stopsSheetPresentationToken = 0
    @State private var showTimetableShareSheet = false
    @State private var timetableShareImage: UIImage?
    @State private var isPreparingShare = false
    @State private var showNotificationDeniedAlert = false
    @State private var notificationToast: ToastMessage?

    private var preferredColorScheme: ColorScheme? {
        AppColorScheme(rawValue: colorSchemeRaw)?.colorScheme
    }

    /// 보여줄 시간표가 하나도 없을 때만. 다시 불러오는 동안에도 화면을 유지한다.
    private var loadFailureMessage: String? {
        if let message = viewModel.errorMessage { return message }
        if !viewModel.isLoading, UserDefaults.standard.bool(forKey: "forceLoadFailed") {
            return "시간표를 불러올 수 없습니다."
        }
        return nil
    }

    var body: some View {
        Group {
            if let loadFailureMessage {
                // 불러오기 실패는 탭 바 없는 전체 화면 (디자인 캔버스 OpsLoadFailed)
                ErrorView(
                    message: loadFailureMessage,
                    hasSavedTimetable: !viewModel.weekdayTimes.isEmpty || !viewModel.weekendTimes.isEmpty,
                    onRetry: { Task { await viewModel.refresh() } },
                    onContact: { showContactFromError = true }
                )
                .sheet(isPresented: $showContactFromError) {
                    NavigationStack { ContactView() }
                }
            } else {
                tabs
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .task {
            await viewModel.onAppear()
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task { await viewModel.refreshTrafficIfExpired() }
        }
        .onReceive(trafficTick) { _ in
            guard scenePhase == .active else { return }
            Task { await viewModel.refreshTrafficIfExpired() }
        }
        .onChange(of: viewModel.isLoading) { isLoading in
            guard !isLoading else { return }
            evaluateRequiredUpdate()
            guard !hasPresentedLaunchPrompts else { return }
            hasPresentedLaunchPrompts = true
            // 스플래시가 닫힌 뒤에 띄운다.
            DispatchQueue.main.asyncAfter(deadline: .now() + LaunchTiming.maximumDuration) {
                presentLaunchPrompts()
            }
        }
        .onChange(of: viewModel.ops) { _ in
            // 시간표를 새로 받을 때마다 최소·권장 버전을 다시 본다.
            evaluateRequiredUpdate()
            if hasPresentedLaunchPrompts { presentRecommendedUpdateIfNeeded() }
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            homeTab
                .tabItem { Label("홈", systemImage: "house") }
                .tag(MainTab.home)

            timetableTab
                .tabItem { Label("전체 시간표", systemImage: "calendar") }
                .tag(MainTab.timetable)

            if isStopsTabEnabled {
                stopsTab
                    .tabItem { Label("정류장", systemImage: "map") }
                    .tag(MainTab.stops)
            }

            NavigationStack {
                InfoView(viewModel: viewModel, onShowTimetable: { selectedTab = .timetable })
            }
            .tabItem { Label("설정", systemImage: "gearshape") }
            .tag(MainTab.settings)
        }
        .glassTabBarMinimize()
        .tint(AppTheme.Color.primaryText)
        .background(
            TabBarSelectionObserver { index, isReselection in
                guard isStopsTabEnabled,
                      index == MainTab.stops.tabIndex,
                      isReselection else { return }
                stopsSheetPresentationToken += 1
            }
        )
        .onChange(of: selectedTab) { newValue in
            guard isStopsTabEnabled, newValue == .stops else { return }
            stopsSheetPresentationToken += 1
        }
        .onOpenURL(perform: handleDeepLink)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(storeService)
        }
        .fullScreenCover(isPresented: $showRequiredUpdate) {
            if case .required(let version) = viewModel.updateRequirement {
                RequiredUpdateView(
                    currentVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                    requiredVersion: version
                )
                .preferredColorScheme(preferredColorScheme)
            }
        }
        .sheet(isPresented: $showRecommendedUpdate) {
            if case .recommended(let version) = viewModel.updateRequirement {
                RecommendedUpdateSheet(
                    version: version,
                    message: viewModel.updateMessage,
                    onUpdate: { UIApplication.shared.open(AppStoreLink.url) },
                    onSkipVersion: { RecommendedUpdateSheet.skip(version: version); showRecommendedUpdate = false },
                    onLater: { showRecommendedUpdate = false }
                )
                .preferredColorScheme(preferredColorScheme)
            }
        }
        .alert("알림 권한이 필요합니다", isPresented: $showNotificationDeniedAlert) {
            Button("설정으로 이동") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("버스 출발 알림을 받으려면\n설정 > 장유시외버스 > 알림을 허용해주세요.")
        }
    }

    // MARK: - 홈 탭

    private var homeTab: some View {
        NavigationStack {
            mainContent
                .background(AmbientBackground())
                .toolbar(.hidden, for: .navigationBar)
                // 탭 바 위에 뜨도록 탭 안쪽에 붙인다
                .toast(item: $notificationToast)
                .navigationDestination(isPresented: $showAlertsHub) {
                    AlertsHubView(
                        viewModel: viewModel,
                        onShowTimetable: { showAlertsHub = false; selectedTab = .timetable }
                    )
                }
                .navigationDestination(isPresented: $showNoticeList) {
                    NoticeListView(notices: viewModel.notices) { notice in
                        viewModel.markNoticeRead(notice.id)
                    }
                }
        }
        .sheet(item: $homeBusDetail) { info in
            BusDetailView(
                info: info,
                alert: viewModel.alert(for: info.departureTime),
                onSetAlert: { lead, repeats in
                    let status = await NotificationService.shared.authorizationStatus()
                    if status == .denied {
                        homeBusDetail = nil
                        showNotificationDeniedAlert = true
                        return false
                    }
                    return await viewModel.setAlert(for: info.departureTime, leadMinutes: lead, repeatsWeekdays: repeats)
                },
                onRemoveAlert: {
                    if let alert = viewModel.alert(for: info.departureTime) { viewModel.removeAlert(id: alert.id) }
                },
                onRefreshTraffic: {
                    await viewModel.refreshTrafficDuration(force: true)
                    return viewModel.arrivalEstimate(for: info.departureTime)
                }
            )
        }
        .sheet(item: $importantNotice) { notice in
            NoticeDialogView(
                notice: notice,
                onOpen: {
                    viewModel.markNoticeRead(notice.id)
                    importantNotice = nil
                    noticeToOpen = notice
                },
                onSnooze: {
                    viewModel.snoozeImportantNotice(id: notice.id)
                    importantNotice = nil
                },
                onClose: { importantNotice = nil }
            )
        }
        .sheet(item: $noticeToOpen) { notice in
            NavigationStack {
                NoticeDetailView(notice: notice)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("닫기") { noticeToOpen = nil }
                                .foregroundStyle(AppTheme.Color.primaryText)
                        }
                    }
            }
        }
    }

    // MARK: - 앱을 열자마자 뜨는 안내 (한 번에 하나)

    /// 필수 업데이트는 다른 안내보다 먼저, 닫을 수 없는 전체 화면으로.
    private func evaluateRequiredUpdate() {
        if case .required = viewModel.updateRequirement {
            importantNotice = nil
            showRecommendedUpdate = false
            showRequiredUpdate = true
        } else {
            showRequiredUpdate = false
        }
    }

    /// 중요 공지(임시 운휴·시간표 변경)가 업데이트 권장보다 급하다. 둘 다 아래쪽 시트라 함께 띄우지 않는다.
    private func presentLaunchPrompts() {
        guard !showRequiredUpdate else { return }
        if UserDefaults.standard.bool(forKey: "forceNoticeDialog"), let first = viewModel.notices.first {
            importantNotice = first
            return
        }
        if let notice = viewModel.importantNoticeToShow() {
            importantNotice = notice
            return
        }
        presentRecommendedUpdateIfNeeded()
    }

    private func presentRecommendedUpdateIfNeeded() {
        guard !hasShownRecommendedUpdate, !showRequiredUpdate,
              importantNotice == nil, noticeToOpen == nil, homeBusDetail == nil, !showPaywall,
              case .recommended(let version) = viewModel.updateRequirement,
              !RecommendedUpdateSheet.isSkipped(version: version) else { return }
        hasShownRecommendedUpdate = true
        showRecommendedUpdate = true
    }

    /// 홈 상단 오른쪽 종. 읽지 않은 알림이 있을 때만 강조색 점.
    private var alertsBell: some View {
        Button {
            showAlertsHub = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .frame(width: 44, height: 44)
                if notificationHistory.unreadCount > 0 {
                    Circle()
                        .fill(AppTheme.Color.accent)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(AppTheme.Color.screenBackground, lineWidth: 2))
                        .padding(.top, 9)
                        .padding(.trailing, 9)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(notificationHistory.unreadCount > 0 ? "알림 모아보기, 새 소식 있음" : "알림 모아보기")
    }

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            GlassGroup {
                mainContentStack
            }
        }
        .softScrollEdge()
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var mainContentStack: some View {
        // 간격은 디자인 캔버스 HomeUnified: 헤더 → 배너 12 → 히어로 16 → 목록 20 → 한 줄 안내 12 → 광고 12
        VStack(alignment: .leading, spacing: 0) {
            RouteHeaderView(
                direction: viewModel.selectedDirection,
                contextText: viewModel.scheduleContextText(),
                subtitle: viewModel.hasRoutes ? viewModel.routeSummaryText : nil,
                trailingAccessory: AnyView(alertsBell),
                onDirectionChange: { direction in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.changeDirection(to: direction)
                    }
                }
            )

            // 배너는 한 번에 하나만 (운휴 > 연결 없음 > 변경 예고 > 공휴일 > 오래됨 > 점검)
            if let banner = homeBanner {
                OperationsBannerView(banner: banner) { handleBannerTap(banner) }
                    .padding(.top, 12)
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let snapshot = viewModel.makeTimingSnapshot(at: context.date)

                let isTomorrowList = isShowingTomorrow(snapshot)
                VStack(alignment: .leading, spacing: 20) {
                    heroSection(using: snapshot, at: context.date)

                    UpcomingBusListView(
                        title: isTomorrowList ? "내일 아침 버스" : "이어지는 버스",
                        footer: footerText(isTomorrow: isTomorrowList, at: context.date),
                        buses: followingBuses(in: snapshot),
                        isVia: { viewModel.isViaBus(for: $0) },
                        alertTime: { viewModel.alert(for: $0).flatMap { $0.isEnabled ? $0.alertTime : nil } },
                        onSelect: { openBusDetail(for: $0) },
                        onShowTimetable: { selectedTab = .timetable }
                    )
                }
            }
            .padding(.top, 16)

            AdSlotView(
                placement: .homeBottom,
                isPro: storeService.isPro,
                isSuppressed: homeBanner != nil,
                onProTap: { showPaywall = true }
            )
            .padding(.top, 12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 28)
    }

    private var homeBanner: OperationsBanner? {
        viewModel.isLoading ? nil : viewModel.operationsBanner()
    }

    /// 오늘 운행이 끝나 히어로가 내일 첫차를 보여주는 상태
    private func isShowingTomorrow(_ snapshot: BusTimingSnapshot) -> Bool {
        !viewModel.isLoading && snapshot.isServiceEnded
    }

    /// 목록 아래 한 줄. 운행 종료 뒤에는 첫차·막차 대신 내일 적용될 시간표를 알린다.
    private func footerText(isTomorrow: Bool, at date: Date) -> String? {
        if isTomorrow { return viewModel.tomorrowContextText(at: date) }
        return viewModel.hasRoutes ? viewModel.serviceSummaryText : nil
    }

    /// 배너나 광고가 뜨면 이어지는 버스는 4대 → 3대 (히어로는 가리지 않음)
    private var upcomingRowLimit: Int {
        let hasBanner = homeBanner != nil
        let showsAd = AdSlotView.isVisible(isPro: storeService.isPro, isSuppressed: hasBanner)
        return (hasBanner || showsAd) ? 3 : 4
    }

    private func handleBannerTap(_ banner: OperationsBanner) {
        switch banner {
        case .closure:
            showNoticeList = true
        case .change:
            selectedTab = .timetable
        case .stale:
            selectedTab = .settings
        case .offline:
            Task { await viewModel.refresh() }
        case .holiday, .maintenance:
            break
        }
    }

    /// 히어로에 이미 보이는 버스(다음 버스 또는 내일 첫차)는 목록에서 뺀다.
    private func followingBuses(in snapshot: BusTimingSnapshot) -> [UpcomingBusSnapshot] {
        if isShowingTomorrow(snapshot) {
            return Array(snapshot.upcomingBuses.filter { $0.statusKind == .nextDay }.dropFirst().prefix(upcomingRowLimit))
        }
        guard let nextBusTime = snapshot.nextBusTime,
              let first = snapshot.upcomingBuses.first,
              first.departureTime == nextBusTime,
              first.statusKind != .nextDay else {
            return Array(snapshot.upcomingBuses.prefix(upcomingRowLimit))
        }
        return Array(snapshot.upcomingBuses.dropFirst().prefix(upcomingRowLimit))
    }

    @ViewBuilder
    private func heroSection(using snapshot: BusTimingSnapshot, at date: Date) -> some View {
        if viewModel.isLoading {
            DashboardLoadingCard()
        } else if let nextBusTime = snapshot.nextBusTime {
            // 오늘 남은 버스가 있으면 간격이 길어도 항상 같은 히어로
            NextBusHeroCard(
                departureTime: nextBusTime,
                arrivalTime: snapshot.nextBusArrivalTime,
                untilText: untilText(for: snapshot),
                durationText: snapshot.nextBusDurationText,
                basis: snapshot.nextBusBasis,
                awaitsTrafficWindow: snapshot.nextBusAwaitsTrafficWindow,
                destinationName: viewModel.currentArrivalHubName,
                isNotificationEnabled: isNextBusNotificationEnabled(for: snapshot),
                alertTime: viewModel.alert(for: nextBusTime)?.alertTime,
                onDetail: { openBusDetail(for: nextBusTime) },
                onNotificationTap: { handleNotificationTap(for: nextBusTime) }
            )
        } else if snapshot.isServiceEnded {
            // 막차가 지나면 구조는 그대로 두고 주인공만 내일 첫차로 (지금 탈 버스가 아니므로 강조색 없음)
            let busTime = snapshot.firstBusTime
            let estimate = viewModel.arrivalEstimate(for: busTime, isNextDay: true, at: date)
            NextBusHeroCard(
                label: "오늘 운행 종료 · 내일 첫차",
                departureTime: busTime,
                arrivalTime: estimate.arrivalTime,
                untilText: "내일 \(busTime) 출발",
                isUntilAccent: false,
                durationText: estimate.durationText,
                basis: estimate.basis,
                awaitsTrafficWindow: estimate.awaitsTrafficWindow,
                destinationName: viewModel.currentArrivalHubName,
                isNotificationEnabled: viewModel.isNotificationScheduled(for: busTime),
                alertTime: viewModel.alert(for: busTime)?.alertTime,
                alertTitle: "내일 첫차 5분 전 알림",
                onDetail: { openBusDetail(for: busTime) },
                onNotificationTap: { handleNotificationTap(for: busTime) }
            )
        } else {
            DashboardNoticeCard(
                title: "운행 정보를 준비 중입니다",
                message: "표시할 버스 정보가 없어서 잠시 후 다시 불러옵니다.",
                systemImage: "clock.badge.questionmark"
            )
        }
    }

    // MARK: - 시간표 탭

    private var timetableTab: some View {
        NavigationStack {
            TimetableScreenView(
                viewModel: viewModel,
                isPreparingShare: isPreparingShare,
                onShare: {
                    guard !isPreparingShare else { return }
                    Task {
                        isPreparingShare = true
                        await prepareTimetableShare()
                        isPreparingShare = false
                    }
                }
            )
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showTimetableShareSheet) {
            if let image = timetableShareImage {
                ShareSheet(activityItems: [
                    image,
                    "\(viewModel.selectedDirection.displayName) \(viewModel.selectedScheduleType.displayLabel) 시간표 | 장유시외버스 앱으로 확인하세요"
                ])
            }
        }
    }

    @MainActor
    private func prepareTimetableShare() async {
        timetableShareImage = renderTimetableShareImage(
            direction: viewModel.selectedDirection,
            scheduleType: viewModel.selectedScheduleType,
            times: viewModel.currentTimes,
            nightFareStartTime: viewModel.nightFareStartTime,
            viaTimes: viewModel.currentViaTimes
        )
        guard timetableShareImage != nil else { return }
        showTimetableShareSheet = true
    }

    // MARK: - 정류장 탭

    private var stopsTab: some View {
        StopsScreenView(
            viewModel: viewModel,
            presentationToken: stopsSheetPresentationToken
        )
    }

    // MARK: - 헬퍼

    /// "12분 후 출발" / "곧 출발" / "1시간 12분 후 출발"
    private func untilText(for snapshot: BusTimingSnapshot) -> String {
        if snapshot.nextBusMinuteDisplay.isEmpty { return "곧 출발" }
        if snapshot.nextBusUnitDisplay == "분" { return "\(snapshot.nextBusMinuteDisplay)분 후 출발" }
        let rest = snapshot.nextBusCountdownDescription.replacingOccurrences(of: " 후 출발", with: "").replacingOccurrences(of: "후 출발", with: "")
        return rest.isEmpty ? "\(snapshot.nextBusMinuteDisplay)시간 후 출발" : "\(snapshot.nextBusMinuteDisplay)시간 \(rest) 후 출발"
    }

    private func openBusDetail(for time: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        homeBusDetail = viewModel.makeBusDetailInfo(for: time)
    }

    private func isNextBusNotificationEnabled(for snapshot: BusTimingSnapshot) -> Bool {
        guard let nextBusTime = snapshot.nextBusTime else { return false }
        return viewModel.isNotificationScheduled(for: nextBusTime)
    }

    private func handleNotificationTap(for nextBusTime: String?) {
        guard let nextBusTime else { return }
        Task {
            let status = await NotificationService.shared.authorizationStatus()
            if status == .denied {
                showNotificationDeniedAlert = true
            } else {
                await viewModel.toggleNotification(for: nextBusTime)
                let isEnabled = viewModel.isNotificationScheduled(for: nextBusTime)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                notificationToast = isEnabled
                    ? ToastMessage(icon: "bell.fill", message: "\(nextBusTime) 버스 알림이 켜졌습니다")
                    : ToastMessage(icon: "bell.slash.fill", message: "\(nextBusTime) 버스 알림이 꺼졌습니다")
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        if AppDeepLink.isPaywall(url) {
            showPaywall = true
            return
        }
        guard let direction = AppDeepLink.routeDirection(from: url) else { return }

        selectedTab = .home
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.changeDirection(to: direction)
        }
    }
}

#Preview {
    MainView(viewModel: MainViewModel())
        .environmentObject(StoreService())
}

private extension MainTab {
    var tabIndex: Int {
        switch self {
        case .home:
            return 0
        case .timetable:
            return 1
        case .stops:
            return 2
        case .settings:
            return 3
        }
    }
}

private struct TabBarSelectionObserver: UIViewControllerRepresentable {
    let onSelection: (Int, Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelection: onSelection)
    }

    func makeUIViewController(context: Context) -> ObserverViewController {
        let controller = ObserverViewController()
        controller.coordinator = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ObserverViewController, context: Context) {
        context.coordinator.onSelection = onSelection
        uiViewController.coordinator = context.coordinator
        uiViewController.attachGestureIfNeeded()
    }

    final class ObserverViewController: UIViewController {
        weak var coordinator: Coordinator?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            attachGestureIfNeeded()
        }

        func attachGestureIfNeeded() {
            guard let tabBarController else { return }
            coordinator?.attachGestureRecognizer(to: tabBarController)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onSelection: (Int, Bool) -> Void
        private weak var observedTabBarController: UITabBarController?

        init(onSelection: @escaping (Int, Bool) -> Void) {
            self.onSelection = onSelection
        }

        func attachGestureRecognizer(to tabBarController: UITabBarController) {
            guard observedTabBarController !== tabBarController else { return }
            observedTabBarController = tabBarController

            let tap = UITapGestureRecognizer(target: self, action: #selector(tabBarTapped(_:)))
            tap.delegate = self
            tap.cancelsTouchesInView = false
            tabBarController.tabBar.addGestureRecognizer(tap)
        }

        @objc private func tabBarTapped(_ recognizer: UITapGestureRecognizer) {
            guard let tabBarController = observedTabBarController,
                  let tabBar = recognizer.view as? UITabBar else { return }

            let itemCount = tabBar.items?.count ?? 0
            guard itemCount > 0 else { return }

            let location = recognizer.location(in: tabBar)
            let itemWidth = tabBar.bounds.width / CGFloat(itemCount)
            let tappedIndex = max(0, min(itemCount - 1, Int(location.x / itemWidth)))
            let isReselection = tabBarController.selectedIndex == tappedIndex

            onSelection(tappedIndex, isReselection)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            return true
        }
    }
}
