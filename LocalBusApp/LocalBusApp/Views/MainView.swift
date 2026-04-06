import SwiftUI

private enum MainTab: Hashable {
    case home
    case timetable
    case stops
    case settings
}

private enum AppDeepLink {
    static let scheme = "localbus"
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
    @StateObject private var viewModel = MainViewModel()
    @AppStorage("colorSchemePreference") private var colorSchemeRaw = AppColorScheme.dark.rawValue
    @State private var selectedTab: MainTab = .home
    @State private var stopsSheetPresentationToken = 0

    private var preferredColorScheme: ColorScheme? {
        AppColorScheme(rawValue: colorSchemeRaw)?.colorScheme
    }

    private var selectedTabBinding: Binding<MainTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if selectedTab == newValue {
                    handleTabReselection(newValue)
                } else {
                    selectedTab = newValue
                    handleTabSelectionChange(to: newValue)
                }
            }
        )
    }

    var body: some View {
        TabView(selection: selectedTabBinding) {
            homeTab
                .tabItem { Label("홈", systemImage: "house") }
                .tag(MainTab.home)

            timetableTab
                .tabItem { Label("전체 시간표", systemImage: "calendar") }
                .tag(MainTab.timetable)

            stopsTab
                .tabItem { Label("정류장 위치", systemImage: "map") }
                .tag(MainTab.stops)

            NavigationStack {
                InfoView(viewModel: viewModel)
            }
            .tabItem { Label("설정", systemImage: "gearshape") }
            .tag(MainTab.settings)
        }
        .preferredColorScheme(preferredColorScheme)
        .task {
            await viewModel.onAppear()
        }
        .onOpenURL(perform: handleDeepLink)
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
            .background(HomeDashboardTheme.screenBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let snapshot = viewModel.makeTimingSnapshot(at: context.date)
                    DashboardHeaderView(
                        locationText: viewModel.dashboardLocationText,
                        isNotificationEnabled: isNextBusNotificationEnabled(for: snapshot),
                        onNotificationTap: { handleNotificationTap(for: snapshot.nextBusTime) }
                    )
                }

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
                            title: "예정된 버스",
                            badgeText: viewModel.scheduleBadgeText,
                            buses: snapshot.upcomingBuses,
                            destinationName: viewModel.currentArrivalHubName
                        )
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
        .refreshable {
            await viewModel.refresh()
        }
    }

    @ViewBuilder
    private func heroSection(using snapshot: BusTimingSnapshot) -> some View {
        if viewModel.isLoading {
            DashboardLoadingCard()
        } else if snapshot.isServiceEnded {
            DashboardServiceEndedCard(
                firstBusTime: snapshot.firstBusTime,
                remainingText: firstBusRemainingText(for: snapshot)
            )
        } else if let nextBusTime = snapshot.nextBusTime {
            NextBusHeroCard(
                minuteText: snapshot.nextBusMinuteDisplay,
                unitText: snapshot.nextBusUnitDisplay,
                descriptionText: snapshot.nextBusCountdownDescription,
                progress: snapshot.nextBusProgress,
                departureTime: nextBusTime,
                arrivalTime: snapshot.nextBusArrivalTime,
                nextBusTime: snapshot.followingBusTime
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
            TimetableScreenView(viewModel: viewModel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(HomeDashboardTheme.screenBackground.opacity(0.95), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        directionTitle(viewModel.selectedDirection)
                    }
                }
        }
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

    private func firstBusRemainingText(for snapshot: BusTimingSnapshot) -> String {
        if snapshot.hoursUntilFirstBus > 0 {
            return "\(snapshot.hoursUntilFirstBus)시간 \(snapshot.minutesUntilFirstBus)분 후 첫차"
        }
        return "\(snapshot.minutesUntilFirstBus)분 후 첫차"
    }

    private func isNextBusNotificationEnabled(for snapshot: BusTimingSnapshot) -> Bool {
        guard let nextBusTime = snapshot.nextBusTime else { return false }
        return viewModel.isNotificationScheduled(for: nextBusTime)
    }

    private func handleNotificationTap(for nextBusTime: String?) {
        guard let nextBusTime else { return }
        Task {
            await viewModel.toggleNotification(for: nextBusTime)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard let direction = AppDeepLink.routeDirection(from: url) else { return }

        selectedTab = .home
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.changeDirection(to: direction)
        }
    }

    private func handleTabSelectionChange(to newValue: MainTab) {
        guard newValue == .stops else { return }
        stopsSheetPresentationToken += 1
    }

    private func handleTabReselection(_ tab: MainTab) {
        guard tab == .stops else { return }
        stopsSheetPresentationToken += 1
    }
}

#Preview {
    MainView()
}
