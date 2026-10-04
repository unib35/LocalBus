import SwiftUI

/// 밝은 화면에서는 카드의 바탕과 테두리를 유지해 콘텐츠 영역을 구분합니다.
private struct ReadableGlassCard<S: Shape, F: ShapeStyle>: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let shape: S
    let fallback: F
    let interactive: Bool
    var tint: Color? = nil

    @ViewBuilder
    func body(content: Content) -> some View {
        if colorScheme == .light {
            content
                .background(fallback, in: shape)
                .overlay(shape.stroke(AppTheme.Color.border, lineWidth: 1).allowsHitTesting(false))
        } else if #available(iOS 26.0, *) {
            if let tint {
                content.glassEffect(interactive ? .regular.tint(tint).interactive() : .regular.tint(tint), in: shape)
            } else {
                content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
            }
        } else {
            content.background(fallback, in: shape)
        }
    }
}

// MARK: - Liquid Glass Helper
//
// iOS 26.0+ Liquid Glass 디자인 언어를 점진적으로 적용하기 위한 헬퍼.
//
// 다크 모드 iOS 26+에서는 글래스를 사용합니다.
// 라이트 모드에서는 밝은 배경에 카드가 묻히지 않도록 바탕과 테두리를 유지합니다.

/// iOS 26+에서 자식 글래스 요소들을 하나의 `GlassEffectContainer`로 묶는다.
/// 인접한 글래스끼리 자연스럽게 블렌딩되고 렌더링 비용도 줄어든다.
/// iOS 26 미만에서는 콘텐츠를 그대로 렌더링한다.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat?
    @ViewBuilder var content: () -> Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing, content: content)
        } else {
            content()
        }
    }
}

extension View {

    /// 카드·배너처럼 떠 있는 컨테이너에 Liquid Glass를 적용한다.
    /// - 라이트 모드: 배경 스타일과 테두리를 유지해 주변 화면과 구분.
    /// - 다크 모드 iOS 26+: `glassEffect(in:)`.
    /// - iOS 16~25: `fallback` 스타일을 같은 shape로 배경 적용.
    ///
    /// - Parameters:
    ///   - shape: 글래스/배경의 클리핑 형태.
    ///   - fallback: iOS 26 미만에서 사용할 배경 스타일 (기존 불투명 카드 색 등).
    ///   - interactive: 탭 가능한 요소면 true — 글래스가 터치에 반응한다.
    @ViewBuilder
    func glassCard<S: Shape, F: ShapeStyle>(
        in shape: S,
        fallback: F,
        interactive: Bool = false
    ) -> some View {
        modifier(ReadableGlassCard(shape: shape, fallback: fallback, interactive: interactive))
    }

    /// 모서리 반지름을 받아 `RoundedRectangle(continuous)` 형태로 glassCard를 적용한다.
    @ViewBuilder
    func glassCard<F: ShapeStyle>(
        cornerRadius: CGFloat,
        fallback: F,
        interactive: Bool = false
    ) -> some View {
        self.glassCard(
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            fallback: fallback,
            interactive: interactive
        )
    }

    /// 상태 배지 등 색이 필요한 요소용 — 틴트를 입힌 Liquid Glass.
    /// iOS 26 미만에서는 `fallback` 배경으로 대체한다.
    @ViewBuilder
    func tintedGlass<S: Shape, F: ShapeStyle>(
        _ tint: Color,
        in shape: S,
        fallback: F,
        interactive: Bool = false
    ) -> some View {
        modifier(ReadableGlassCard(shape: shape, fallback: fallback, interactive: interactive, tint: tint))
    }

    /// 버튼·캡슐 칩 같은 인터랙티브 요소에 Liquid Glass 버튼 스타일을 적용한다.
    /// iOS 26 미만에서는 원본 뷰를 그대로 반환한다.
    @ViewBuilder
    func liquidGlassButton(prominent: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            self
        }
    }

    /// iOS 26 미만에서만 내비게이션 바 배경을 강제한다.
    /// 26+에서는 시스템 Liquid Glass 바를 가리지 않도록 아무것도 적용하지 않는다.
    @ViewBuilder
    func legacyToolbarBackground<S: ShapeStyle>(_ style: S) -> some View {
        if #available(iOS 26.0, *) {
            self
        } else {
            self
                .toolbarBackground(style, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    /// iOS 26+에서 스크롤 시 탭 바를 축소하는 동작을 적용한다.
    @ViewBuilder
    func glassTabBarMinimize() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }

    /// iOS 26+에서 스크롤 상단 엣지에 soft 페이드 효과를 적용한다.
    /// 내비게이션 바를 숨긴 화면에서 콘텐츠가 상태 바 아래로 자연스럽게 사라진다.
    @ViewBuilder
    func softScrollEdge(_ edges: Edge.Set = .top) -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: edges)
        } else {
            self
        }
    }

    /// iOS 26 미만에서만 적용되는 카드 테두리.
    /// 글래스에는 자체 하이라이트 림이 있어 26+에서 별도 테두리는 이중선으로 보인다.
    /// 세그먼트 컨트롤의 트랙 — 불투명 배경 + 테두리.
    ///
    /// 글래스를 쓰지 않는다. iOS 26의 `glassEffect` 는 fallback 색을 무시하므로
    /// 밝은 배경 위에서는 트랙이 배경과 구분되지 않고, 선택되지 않은 칸이
    /// 페이지에 묻혀 컨트롤로 읽히지 않는다. iOS 기본 세그먼트도 글래스가 아니다.
    func segmentTrack(cornerRadius: CGFloat, lineWidth: CGFloat = 1) -> some View {
        background(
            AppTheme.Color.segmentBackground,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(AppTheme.Color.segmentBorder, lineWidth: lineWidth)
        )
    }

    @ViewBuilder
    func fallbackCardBorder(cornerRadius: CGFloat, color: Color, lineWidth: CGFloat = 1) -> some View {
        if #available(iOS 26.0, *) {
            self
        } else {
            self.overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(color, lineWidth: lineWidth)
            )
        }
    }
}
