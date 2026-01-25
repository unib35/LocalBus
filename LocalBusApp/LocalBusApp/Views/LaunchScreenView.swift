import SwiftUI

/// 런치 스크린 (스플래시 화면)
struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            // 배경색
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // 아이콘
                Image(systemName: "bus.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.primary)

                // 앱 이름
                Text("LocalBus")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                // 부제
                Text("장유 ↔ 사상")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
