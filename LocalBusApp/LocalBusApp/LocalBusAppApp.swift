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
                // 1.5초 후 런치 스크린 숨김
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showLaunchScreen = false
                    }
                }
            }
        }
    }
}
