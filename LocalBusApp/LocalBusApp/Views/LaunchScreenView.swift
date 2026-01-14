import SwiftUI

/// 런치 스크린 (스플래시 화면)
struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            // 배경색
            Color.blue
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // 아이콘
                Image(systemName: "bus.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)

                // 앱 이름
                Text("LocalBus")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                // 부제
                Text("장유 ↔ 사상")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
