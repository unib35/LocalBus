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
    @State private var showLaunchScreen = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainView()
                    .environmentObject(storeService)

                if showLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                await storeService.loadProducts()
            }
            .onAppear {
                // 타이머는 첫 프레임 렌더 전(앱 초기화 시점)부터 돌기 시작하므로,
                // 콜드 스타트에서도 스플래시가 실제로 보이도록 여유를 둔다.
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showLaunchScreen = false
                    }
                }
            }
        }
    }
}
