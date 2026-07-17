import SwiftUI

/// 화면 배경 + 은은한 앰비언트 라이트.
///
/// Liquid Glass는 뒤에 놓인 콘텐츠를 굴절시켜야 질감이 살아난다.
/// 완전한 플랫 단색 위에서는 글래스가 흐린 회색 카드처럼 보이므로,
/// 모노크롬 톤을 유지한 채 미세한 명도 변화(블러 처리된 광원)를 깔아준다.
/// iOS 26 미만에서도 동일하게 렌더링되며, 기존 배경 대비 시각적 차이는 미미하다.
struct AmbientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AppTheme.Color.screenBackground

            // 상단 하이라이트 — 화면 위쪽이 살짝 밝다.
            Circle()
                .fill(highlight)
                .frame(width: 420, height: 420)
                .blur(radius: 80)
                .offset(x: -120, y: -280)

            // 우측 중단 보조광
            Circle()
                .fill(highlight.opacity(0.6))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: 170, y: 20)

            // 하단 딤 — 아래로 갈수록 미세하게 가라앉는다.
            Circle()
                .fill(dim)
                .frame(width: 480, height: 480)
                .blur(radius: 100)
                .offset(x: -60, y: 420)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var highlight: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.07)
            : Color.white.opacity(0.9)
    }

    private var dim: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.03)
            : Color.black.opacity(0.03)
    }
}

#Preview("Light") {
    AmbientBackground()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    AmbientBackground()
        .preferredColorScheme(.dark)
}
