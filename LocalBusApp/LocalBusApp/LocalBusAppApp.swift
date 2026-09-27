//
//  LocalBusAppApp.swift
//  LocalBusApp
//
//  Created by 이종민 on 1/10/26.
//

import SwiftUI
import FirebaseMessaging

@main
struct LocalBusAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var storeService = StoreService()
    @StateObject private var viewModel = MainViewModel()

    /// 첫 실행 온보딩을 마쳤는지. UI 테스트는 실행 인자 `-hasCompletedOnboarding YES`로 건너뛴다.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var showLaunchScreen = true
    @State private var showOnboarding = false
    @State private var launchStartedAt = Date()

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainView(viewModel: viewModel)
                    .environmentObject(storeService)

                if showOnboarding {
                    OnboardingView(viewModel: viewModel) {
                        hasCompletedOnboarding = true
                        withAnimation(.easeOut(duration: 0.3)) {
                            showOnboarding = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }

                if showLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(2)
                }
            }
            .task {
                await storeService.loadProducts()
            }
            .onAppear {
                launchStartedAt = Date()
                // 시간표가 늦어도 최대 시간 뒤에는 홈으로 넘어간다.
                DispatchQueue.main.asyncAfter(deadline: .now() + LaunchTiming.maximumDuration) {
                    dismissLaunchScreen()
                }
            }
            .onChange(of: viewModel.isLoading) { isLoading in
                // 시간표가 준비되면 최소 노출 시간만 채우고 바로 닫는다.
                guard !isLoading else { return }
                let elapsed = Date().timeIntervalSince(launchStartedAt)
                let delay = LaunchTiming.dismissDelay(loadedAfter: elapsed)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    dismissLaunchScreen()
                }
            }
        }
    }

    private func dismissLaunchScreen() {
        guard showLaunchScreen else { return }
        if !hasCompletedOnboarding {
            showOnboarding = true
        }
        withAnimation(.easeOut(duration: 0.3)) {
            showLaunchScreen = false
        }
    }
}
