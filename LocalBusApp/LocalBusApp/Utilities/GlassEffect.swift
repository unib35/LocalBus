import SwiftUI

// MARK: - Liquid Glass Helper
//
// iOS 26.0+ Liquid Glass 디자인 언어를 점진적으로 적용하기 위한 헬퍼.
//
// 핵심 원칙: 글래스는 뷰 "뒤"에 깔리므로, 뷰에 불투명 배경이 있으면 가려진다.
// 따라서 iOS 26+ 에서는 글래스만 적용하고, 그 이하 버전에서만 폴백 배경을 칠한다.
// (기존처럼 불투명 배경 위에 glassEffect를 얹으면 글래스가 전혀 보이지 않는다.)

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
    /// - iOS 26+: `glassEffect(in:)` — 배경 없이 글래스만.
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
        if #available(iOS 26.0, *) {
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            self.background(fallback, in: shape)
        }
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
        if #available(iOS 26.0, *) {
            self.glassEffect(
                interactive ? .regular.tint(tint).interactive() : .regular.tint(tint),
                in: shape
            )
        } else {
            self.background(fallback, in: shape)
        }
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
