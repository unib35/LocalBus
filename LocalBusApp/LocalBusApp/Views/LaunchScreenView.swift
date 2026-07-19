import SwiftUI

/// 런치 스크린 (스플래시 화면)
///
/// 다크 고정 배경 위에 버스 캐릭터와 장유→사상 경로 그래픽을 보여준다.
/// 시스템 런치 스크린(Info.plist UILaunchScreen)과 같은 배경색을 사용해
/// 시스템 → SwiftUI 스플래시 전환이 끊김 없이 이어진다.
struct LaunchScreenView: View {

    private static let background = Color("LaunchBackground")

    var body: some View {
        ZStack {
            Self.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                artwork
                    .frame(width: 340, height: 380)

                VStack(spacing: 14) {
                    HStack(spacing: 16) {
                        Text("장유")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(.top, 6)
                        Text("사상")
                    }
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                    Text("시외버스 시간표 앱")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.top, 8)

                Spacer()
                Spacer()
            }
        }
    }

    // MARK: - 아트워크 (버스 + 핀 + 점선 경로)

    private var artwork: some View {
        ZStack {
            // 좌상 → 버스 왼쪽으로 이어지는 점선 경로
            SplashRouteCurve(
                start: CGPoint(x: 62, y: 96),
                control1: CGPoint(x: 108, y: 128),
                control2: CGPoint(x: 34, y: 196),
                end: CGPoint(x: 92, y: 226)
            )
            .stroke(style: dashStyle)
            .foregroundStyle(.white.opacity(0.55))

            // 버스 오른쪽 → 우하 핀으로 이어지는 점선 경로
            SplashRouteCurve(
                start: CGPoint(x: 246, y: 258),
                control1: CGPoint(x: 300, y: 246),
                control2: CGPoint(x: 246, y: 312),
                end: CGPoint(x: 292, y: 306)
            )
            .stroke(style: dashStyle)
            .foregroundStyle(.white.opacity(0.55))

            // 출발 핀 (장유) — 좌상단
            pin(label: "장유")
                .position(x: 58, y: 70)

            // 도착 핀 (사상) — 우하단
            pin(label: "사상")
                .position(x: 300, y: 330)

            // 버스 캐릭터
            Image("SplashMark")
                .resizable()
                .scaledToFit()
                .frame(width: 216)
                .position(x: 172, y: 196)
        }
    }

    private var dashStyle: StrokeStyle {
        StrokeStyle(lineWidth: 5, lineCap: .round, dash: [9, 11])
    }

    private func pin(label: String) -> some View {
        VStack(spacing: 8) {
            MapPin(size: 42)
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

// MARK: - 지도 핀

/// 물방울 형태의 지도 핀 (원 + 꼬리 + 가운데 홀)
private struct MapPin: View {
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            PinTail()
                .fill(.white)
                .frame(width: size * 0.64, height: size * 0.72)
                .offset(y: size * 0.5)

            Circle()
                .fill(.white)
                .frame(width: size, height: size)

            Circle()
                .fill(Color("LaunchBackground"))
                .frame(width: size * 0.36, height: size * 0.36)
                .offset(y: size * 0.32)
        }
        .frame(width: size, height: size * 1.24, alignment: .top)
    }
}

/// 핀 아래쪽 꼬리 (아래로 뾰족한 삼각형)
private struct PinTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 점선 경로 곡선

/// 고정 좌표계(340x380) 안에서 그리는 베지어 경로
private struct SplashRouteCurve: Shape {
    let start: CGPoint
    let control1: CGPoint
    let control2: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addCurve(to: end, control1: control1, control2: control2)
        return path
    }
}

#Preview {
    LaunchScreenView()
}
