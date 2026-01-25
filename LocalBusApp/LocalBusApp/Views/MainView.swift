import SwiftUI

/// 메인 화면
struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showingInfo = false

    var body: some View {
        NavigationStack {
            Group {
                // 에러 상태일 때 ErrorView 표시
                if let errorMessage = viewModel.errorMessage, !viewModel.isLoading {
                    ErrorView(message: errorMessage) {
                        Task {
                            await viewModel.refresh()
                        }
                    }
                } else {
                    mainContent
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("시외버스")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingInfo) {
                InfoView()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            await viewModel.onAppear()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 오프라인 배너
                if viewModel.isOffline {
                    OfflineBanner()
                }

                // 공지 배너
                if viewModel.hasNotice {
                    NoticeBanner(message: viewModel.noticeMessage ?? "")
                }

                VStack(spacing: 16) {
                    // 방향 선택 (양방향 지원시에만 표시)
                    if viewModel.hasRoutes {
                        DirectionSelector(
                            selectedDirection: viewModel.selectedDirection,
                            onDirectionChange: { direction in
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    viewModel.changeDirection(to: direction)
                                }
                            }
                        )
                    }

                    // 다음 버스 실시간 카운트다운 카드
                    if viewModel.isLoading {
                        LoadingCard()
                    } else if viewModel.isServiceEnded {
                        EndOfServiceCard(firstBusTime: viewModel.firstBusTime)
                    } else if let nextTime = viewModel.nextBusTime {
                        LiveCountdownCard(
                            nextBusTime: nextTime,
                            countdownText: viewModel.countdownText,
                            direction: viewModel.currentDirectionName,
                            isNotificationScheduled: viewModel.isNotificationScheduled(for: nextTime),
                            onNotificationTap: {
                                Task {
                                    await viewModel.toggleNotification(for: nextTime)
                                }
                            }
                        )
                    }

                    // 노선 정보 (소요시간/요금)
                    if viewModel.hasRoutes && viewModel.durationMinutes > 0 {
                        RouteInfoBar(
                            durationMinutes: viewModel.durationMinutes,
                            fareText: viewModel.fareText
                        )
                    }

                    // 정류장 경로
                    if viewModel.hasRoutes && !viewModel.currentStops.isEmpty {
                        RouteStopsView(
                            stops: viewModel.currentStops,
                            durationMinutes: viewModel.durationMinutes
                        )
                    }

                    // 첫차/막차 정보
                    if !viewModel.isLoading && !viewModel.currentTimes.isEmpty {
                        FirstLastBusInfo(
                            firstBus: viewModel.firstBusTime,
                            lastBus: viewModel.lastBusTime
                        )
                    }

                    // 평일/주말 탭
                    ScheduleTypePicker(selection: $viewModel.selectedScheduleType)

                    // 시간표 그리드
                    if !viewModel.isLoading {
                        TimetableGrid(
                            times: viewModel.currentTimes,
                            nextBusTime: viewModel.nextBusTime
                        )
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MainView()
}
