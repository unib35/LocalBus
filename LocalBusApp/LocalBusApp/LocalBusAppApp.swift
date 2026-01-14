//
//  LocalBusAppApp.swift
//  LocalBusApp
//
//  Created by 이종민 on 1/10/26.
//

import SwiftUI

@main
struct LocalBusAppApp: App {
    @State private var showLaunchScreen = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainView()

                if showLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
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
