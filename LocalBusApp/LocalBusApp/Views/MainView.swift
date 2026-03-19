import SwiftUI

/// 메인 화면
struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @AppStorage("colorSchemePreference") private var colorSchemeRaw = AppColorScheme.dark.rawValue

    private var preferredColorScheme: ColorScheme? {
        AppColorScheme(rawValue: colorSchemeRaw)?.colorScheme
    }

    var body: some View {
        TabView {
            homeTab
                .tabItem { Label("홈", systemImage: "house") }

            timetableTab
                .tabItem { Label("전체 시간표", systemImage: "calendar") }

            stopsTab
                .tabItem { Label("정류장 위치", systemImage: "map") }

            NavigationStack {
                InfoView(viewModel: viewModel)
            }
            .tabItem { Label("설정", systemImage: "gearshape") }
        }
        .preferredColorScheme(preferredColorScheme)
        .task {
            await viewModel.onAppear()
        }
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
                DashboardHeaderView(
                    locationText: viewModel.dashboardLocationText,
                    isNotificationEnabled: isNextBusNotificationEnabled,
                    onNotificationTap: handleNotificationTap
                )

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

                heroSection

                UpcomingBusesSectionView(
                    title: "예정된 버스",
                    badgeText: viewModel.scheduleBadgeText,
                    buses: viewModel.upcomingBuses,
                    destinationName: viewModel.currentArrivalHubName
                )

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
    private var heroSection: some View {
        if viewModel.isLoading {
            DashboardLoadingCard()
        } else if viewModel.isServiceEnded {
            DashboardServiceEndedCard(
                firstBusTime: viewModel.firstBusTime,
                remainingText: firstBusRemainingText
            )
        } else if let nextBusTime = viewModel.nextBusTime {
            NextBusHeroCard(
                minuteText: viewModel.nextBusMinuteDisplay,
                unitText: viewModel.nextBusUnitDisplay,
                descriptionText: viewModel.nextBusCountdownDescription,
                progress: viewModel.nextBusProgress,
                departureTime: nextBusTime,
                arrivalTime: viewModel.nextBusArrivalTime,
                nextBusTime: viewModel.followingBusTime
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
                .toolbarBackground(Color.black, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
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
                .foregroundStyle(.white)
            Text(" → ")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(red: 100/255, green: 116/255, blue: 139/255))
            Text(parts.last ?? "")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - 정류장 탭

    private var stopsTab: some View {
        StopsScreenView(viewModel: viewModel)
    }

    // MARK: - 헬퍼

    private var firstBusRemainingText: String {
        if viewModel.hoursUntilFirstBus > 0 {
            return "\(viewModel.hoursUntilFirstBus)시간 \(viewModel.minutesUntilFirstBus)분 후 첫차"
        }
        return "\(viewModel.minutesUntilFirstBus)분 후 첫차"
    }

    private var isNextBusNotificationEnabled: Bool {
        guard let nextBusTime = viewModel.nextBusTime else { return false }
        return viewModel.isNotificationScheduled(for: nextBusTime)
    }

    private func handleNotificationTap() {
        guard let nextBusTime = viewModel.nextBusTime else { return }
        Task {
            await viewModel.toggleNotification(for: nextBusTime)
        }
    }
}

#Preview {
    MainView()
}
