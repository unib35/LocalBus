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

    var body: some View {
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
        .preferredColorScheme(preferredColorScheme)
        .task {
            await viewModel.onAppear()
        }
        .onChange(of: selectedTab) { newValue in
            guard isStopsTabEnabled, newValue == .stops else { return }
            stopsSheetPresentationToken += 1
        }
        .onOpenURL(perform: handleDeepLink)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(storeService)
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
        .toast(item: $notificationToast)
    }

    // MARK: - 홈 탭

    private var homeTab: some View {
        NavigationStack {
            Group {
                if let errorMessage = viewModel.errorMessage, !viewModel.isLoading {
                    ErrorView(message: errorMessage) {
                        Task { await viewModel.refresh() }
                    }
                } else {
                    mainContent
                }
            }
            .background(AmbientBackground())
            .toolbar(.hidden, for: .navigationBar)
        }
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
        VStack(alignment: .leading, spacing: 20) {
            RouteHeaderView(
                direction: viewModel.selectedDirection,
                contextText: viewModel.scheduleContextText(),
                subtitle: viewModel.hasRoutes ? viewModel.routeSummaryText : nil,
                onDirectionChange: { direction in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.changeDirection(to: direction)
                    }
                }
            )

            if viewModel.isOffline {
                InlineBanner(
                    systemImage: "wifi.slash",
                    message: "연결 없음 · \(viewModel.updatedAtText) 기준 저장된 시간표를 보여드려요",
                    actionTitle: "다시 시도",
                    action: { Task { await viewModel.refresh() } }
                )
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let snapshot = viewModel.makeTimingSnapshot(at: context.date)

                let isTomorrowList = isShowingTomorrow(snapshot)
                VStack(alignment: .leading, spacing: 22) {
                    heroSection(using: snapshot)

                    UpcomingBusListView(
                        title: isTomorrowList ? "내일 아침 버스" : "이어지는 버스",
                        footer: isTomorrowList ? viewModel.tomorrowContextText(at: context.date) : nil,
                        buses: followingBuses(in: snapshot),
                        isVia: { viewModel.isViaBus(for: $0) },
                        onShowTimetable: { selectedTab = .timetable }
                    )
                }
            }

            if viewModel.hasRoutes {
                Text(viewModel.serviceSummaryText)
                    .font(AppTheme.Typography.footnote)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .padding(.horizontal, 2)
            }

            if viewModel.hasNotice, let noticeMessage = viewModel.noticeMessage {
                DashboardNoticeCard(
                    title: "운행 일정 조정 안내",
                    message: noticeMessage,
                    systemImage: "info.circle.fill"
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 28)
    }

    /// 오늘 운행이 끝나 히어로가 내일 첫차를 보여주는 상태
    private func isShowingTomorrow(_ snapshot: BusTimingSnapshot) -> Bool {
        !viewModel.isLoading && snapshot.isServiceEnded && snapshot.nextBusTime == nil
    }

    /// 히어로에 이미 보이는 버스(다음 버스 또는 내일 첫차)는 목록에서 뺀다.
    private func followingBuses(in snapshot: BusTimingSnapshot) -> [UpcomingBusSnapshot] {
        if isShowingTomorrow(snapshot) {
            return Array(snapshot.upcomingBuses.filter { $0.statusKind == .nextDay }.dropFirst().prefix(4))
        }
        guard let nextBusTime = snapshot.nextBusTime,
              let first = snapshot.upcomingBuses.first,
              first.departureTime == nextBusTime,
              first.statusKind != .nextDay else {
            return Array(snapshot.upcomingBuses.prefix(4))
        }
        return Array(snapshot.upcomingBuses.dropFirst().prefix(4))
    }

    @ViewBuilder
    private func heroSection(using snapshot: BusTimingSnapshot) -> some View {
        if viewModel.isLoading {
            DashboardLoadingCard()
        } else if snapshot.isServiceEnded {
            // 오늘 막차가 지났으면 내일 첫차, 아직 오늘 버스가 남았지만 한참 뒤면 그 버스를 주인공으로
            let busTime = snapshot.nextBusTime ?? snapshot.firstBusTime
            let isTomorrow = snapshot.nextBusTime == nil
            DashboardServiceEndedCard(
                eyebrow: isTomorrow ? "오늘 운행 종료" : "지금은 운행 간격이 길어요",
                remainingText: isTomorrow
                    ? remainingText(hours: snapshot.hoursUntilFirstBus, minutes: snapshot.minutesUntilFirstBus)
                    : remainingText(hours: (snapshot.minutesUntilNextBus ?? 0) / 60, minutes: (snapshot.minutesUntilNextBus ?? 0) % 60),
                busTime: busTime,
                busLabel: isTomorrow ? "내일 첫차" : "다음 버스",
                arrivalTime: DateService.timeByAdding(minutes: viewModel.currentDurationMinutes, to: busTime) ?? "--:--",
                destinationName: viewModel.currentArrivalHubName,
                durationMinutes: viewModel.currentDurationMinutes,
                isNotificationEnabled: viewModel.isNotificationScheduled(for: busTime),
                notificationTitle: isTomorrow ? "내일 첫차 5분 전 알림" : "\(busTime) 버스 5분 전 알림",
                onNotificationTap: { handleNotificationTap(for: busTime) }
            )
        } else if let nextBusTime = snapshot.nextBusTime {
            NextBusHeroCard(
                minuteText: snapshot.nextBusMinuteDisplay,
                unitText: snapshot.nextBusUnitDisplay,
                descriptionText: snapshot.nextBusCountdownDescription,
                departureTime: nextBusTime,
                arrivalTime: snapshot.nextBusArrivalTime,
                destinationName: viewModel.currentArrivalHubName,
                durationMinutes: viewModel.currentDurationMinutes,
                isNotificationEnabled: isNextBusNotificationEnabled(for: snapshot),
                onNotificationTap: { handleNotificationTap(for: nextBusTime) }
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

    private func remainingText(hours: Int, minutes: Int) -> String {
        hours > 0 ? "\(hours)시간 \(minutes)분 후" : "\(minutes)분 후"
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
