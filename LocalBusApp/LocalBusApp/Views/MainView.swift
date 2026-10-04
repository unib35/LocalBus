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
    // 정류장 지도와 목록을 제품 탭으로 제공합니다.
    private let isStopsTabEnabled = true

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = MainViewModel()
    @AppStorage("colorSchemePreference") private var colorSchemeRaw = AppColorScheme.dark.rawValue
    @State private var selectedTab: MainTab = .home
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
                .tabItem { Label("홈", systemImage: "house").accessibilityIdentifier(AccessibilityID.Tab.home) }
                .tag(MainTab.home)

            timetableTab
                .tabItem { Label("전체 시간표", systemImage: "calendar").accessibilityIdentifier(AccessibilityID.Tab.timetable) }
                .tag(MainTab.timetable)

            if isStopsTabEnabled {
                stopsTab
                    .tabItem { Label("정류장 위치", systemImage: "map") }
                    .tag(MainTab.stops)
            }

            NavigationStack {
                InfoView(viewModel: viewModel)
                    .accessibilityIdentifier(AccessibilityID.Settings.root)
            }
            .tabItem { Label("설정", systemImage: "gearshape").accessibilityIdentifier(AccessibilityID.Tab.settings) }
            .badge(viewModel.hasTimetableUpdate ? "N" : nil)
            .tag(MainTab.settings)
        }
        .glassTabBarMinimize()
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
            await viewModel.refreshScheduledNotifications()
            if #available(iOS 16.2, *) { await LiveActivityService.shared.reconcileActivities() }
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active, !viewModel.isLoading else { return }
            Task {
                await viewModel.refreshScheduledNotifications()
                if #available(iOS 16.2, *) { await LiveActivityService.shared.reconcileActivities() }
                await viewModel.checkForTimetableUpdate()
            }
        }
        .onChange(of: selectedTab) { newValue in
            guard isStopsTabEnabled, newValue == .stops else { return }
            stopsSheetPresentationToken += 1
        }
        .onOpenURL(perform: handleDeepLink)
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
        .accessibilityIdentifier(AccessibilityID.Home.root)
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
        VStack(alignment: .leading, spacing: 24) {
                if viewModel.hasRoutes {
                    DirectionSelector(
                        selectedDirection: viewModel.selectedDirection,
                        onDirectionChange: { direction in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                viewModel.changeDirection(to: direction)
                            }
                        }
                        )
                }

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let snapshot = viewModel.makeTimingSnapshot(at: context.date)

                    VStack(alignment: .leading, spacing: 24) {
                        heroSection(using: snapshot)

                        UpcomingBusesSectionView(
                            title: "그다음 버스",
                            badgeText: viewModel.scheduleBadgeText,
                            buses: followingBuses(using: snapshot),
                            destinationName: viewModel.currentArrivalHubName
                        )
                        .accessibilityIdentifier(AccessibilityID.Home.upcomingBuses)

                        if viewModel.hasRoutes {
                            FirstLastBusSectionView(
                                firstBusTime: viewModel.firstBusTime,
                                lastBusTime: viewModel.lastBusTime
                            )
                            .accessibilityIdentifier(AccessibilityID.Home.firstLastBus)
                        }
                    }
                }


                if viewModel.isOffline {
                    DashboardNoticeCard(
                        title: "오프라인 모드",
                        message: "네트워크 연결 없이 저장된 시간표를 표시하고 있습니다.",
                        systemImage: "wifi.slash"
                    )
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
        .padding(.top, 16)
        .padding(.bottom, 28)
    }

    @ViewBuilder
    private func heroSection(using snapshot: BusTimingSnapshot) -> some View {
        if viewModel.isLoading {
            DashboardLoadingCard()
                .accessibilityIdentifier(AccessibilityID.Home.heroLoading)
        } else if snapshot.isServiceEnded {
            DashboardServiceEndedCard(
                firstBusTime: snapshot.firstBusTime,
                remainingText: firstBusRemainingText(for: snapshot)
            )
            .accessibilityIdentifier(AccessibilityID.Home.heroServiceEnded)
        } else if let nextBusTime = snapshot.nextBusTime {
            NextBusHeroCard(
                minuteText: snapshot.nextBusMinuteDisplay,
                unitText: snapshot.nextBusUnitDisplay,
                descriptionText: snapshot.nextBusCountdownDescription,
                departureTime: nextBusTime,
                arrivalTime: snapshot.nextBusArrivalTime,
                isNotificationEnabled: isNextBusNotificationEnabled(for: snapshot),
                isDepartingSoon: (DateService.minutesUntil(timeString: nextBusTime, from: Date()) ?? 99) <= 5,
                onNotificationTap: { handleNotificationTap(for: nextBusTime) }
            )
            .accessibilityIdentifier(AccessibilityID.Home.heroNextBus)
        } else {
            DashboardNoticeCard(
                title: "운행 정보를 준비 중입니다",
                message: "표시할 버스 정보가 없어서 잠시 후 다시 불러옵니다.",
                systemImage: "clock.badge.questionmark"
            )
            .accessibilityIdentifier(AccessibilityID.Home.heroUnavailable)
        }
    }

    // MARK: - 시간표 탭

    private var timetableTab: some View {
        NavigationStack {
            TimetableScreenView(viewModel: viewModel)
                .navigationBarTitleDisplayMode(.inline)
                .legacyToolbarBackground(HomeDashboardTheme.screenBackground.opacity(0.95))
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        directionTitle(viewModel.selectedDirection)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            guard !isPreparingShare else { return }
                            Task {
                                isPreparingShare = true
                                await prepareTimetableShare()
                                isPreparingShare = false
                            }
                        } label: {
                            if isPreparingShare {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(HomeDashboardTheme.secondaryText)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(HomeDashboardTheme.secondaryText)
                            }
                        }
                        .disabled(isPreparingShare)
                    }
                }
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

    private func directionTitle(_ direction: RouteDirection) -> some View {
        let parts = direction.displayName.components(separatedBy: " → ")
        return HStack(spacing: 0) {
            Text(parts.first ?? "")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(HomeDashboardTheme.primaryText)
            Text(" → ")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(HomeDashboardTheme.tertiaryText)
            Text(parts.last ?? "")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(HomeDashboardTheme.primaryText)
        }
    }

    // MARK: - 정류장 탭

    private var stopsTab: some View {
        StopsScreenView(
            viewModel: viewModel,
            presentationToken: stopsSheetPresentationToken
        )
    }

    // MARK: - 헬퍼

    private func followingBuses(using snapshot: BusTimingSnapshot) -> [UpcomingBusSnapshot] {
        guard !snapshot.isServiceEnded, snapshot.nextBusTime != nil else {
            return snapshot.upcomingBuses
        }
        return Array(snapshot.upcomingBuses.dropFirst())
    }

    private func firstBusRemainingText(for snapshot: BusTimingSnapshot) -> String {
        if snapshot.hoursUntilFirstBus > 0 {
            return "\(snapshot.hoursUntilFirstBus)시간 \(snapshot.minutesUntilFirstBus)분 후 첫차"
        }
        return "\(snapshot.minutesUntilFirstBus)분 후 첫차"
    }

    private func isNextBusNotificationEnabled(for snapshot: BusTimingSnapshot) -> Bool {
        guard let nextBusTime = snapshot.nextBusTime else { return false }
        return viewModel.isNotificationScheduled(for: nextBusTime, useSelectedSchedule: false)
    }

    private func handleNotificationTap(for nextBusTime: String?) {
        guard let nextBusTime else { return }
        Task {
            let result = await viewModel.toggleNotification(for: nextBusTime, useSelectedSchedule: false)
            if case .denied = result { showNotificationDeniedAlert = true }
            else { notificationToast = ToastMessage(icon: "bell", message: result.message) }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard let direction = AppDeepLink.routeDirection(from: url) else { return }

        selectedTab = .home
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.changeDirection(to: direction)
        }
    }
}

#Preview("전체 앱 · 라이트") {
    MainView().environmentObject(StoreService()).defaultAppStorage(PreviewRuntime.defaults).preferredColorScheme(.light)
}

#Preview("전체 앱 · 다크") {
    MainView().environmentObject(StoreService()).defaultAppStorage(PreviewRuntime.defaults).preferredColorScheme(.dark)
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
