import SwiftUI

/// 런치 스크린 (스플래시 화면) — 디자인 캔버스 개선안
///
/// 앱 아이콘과 같은 시계 버스 마크 + 워드마크 + 한 줄 부제. 시스템 런치 스크린(Info.plist UILaunchScreen)과
/// 같은 배경색을 써서 시스템 → SwiftUI 스플래시 전환이 끊김 없이 이어진다.
/// 종료 시점은 `LaunchTiming`(시간표 준비 시 최소 0.6초 뒤, 늦어도 1.5초)에서 정한다.
struct LaunchScreenView: View {

    private static let background = Color("LaunchBackground")
    private static let accent = Color(red: 74/255, green: 222/255, blue: 128/255)

    @State private var progressOffset: CGFloat = -1

    var body: some View {
        ZStack {
            Self.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Image("SplashMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 132)
                    .accessibilityHidden(true)

                Text("장유사상버스")
                    .font(.system(size: 32, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundStyle(.white)
                    .padding(.top, 22)

                Text("장유 · 율하 ↔ 사상 시외버스 시간표")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(white: 0.64))
                    .padding(.top, 8)
            }
            .padding(.bottom, 60)
            // 캔버스는 안전 영역이 아니라 화면 전체를 기준으로 가운데와 바닥을 잡는다
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("장유사상버스, 장유 율하 사상 시외버스 시간표")

            VStack(spacing: 10) {
                Spacer()

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(white: 0.15))
                        Capsule()
                            .fill(Self.accent)
                            .frame(width: geo.size.width * 0.45)
                            .offset(x: progressOffset * geo.size.width)
                    }
                }
                .frame(width: 120, height: 3)
                .clipShape(Capsule())
                .accessibilityHidden(true)

                Text("저장된 시간표를 불러오는 중")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(white: 0.478))
            }
            .padding(.bottom, 64)
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: false)) {
                progressOffset = 1
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
