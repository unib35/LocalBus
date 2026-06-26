import SwiftUI

// MARK: - Liquid Glass Helper
//
// iOS 26.0+ Liquid Glass 디자인 언어를 점진적으로 적용하기 위한 헬퍼.
// iOS 16~25 에서는 기존 background 그대로 사용하고,
// iOS 26+ 에서만 `.glassEffect()` 또는 `.buttonStyle(.glass)` 를 덧입힌다.
//
// 빌드 호환성:
// - iOS 26 SDK (Xcode 26 / Swift 6.2+) 에서만 API 가 존재한다.
// - 그 이전 SDK 에서는 `#if compiler(>=6.2)` 로 컴파일 자체에서 분기되어 안전하게 폴백한다.
// - 따라서 현재 Xcode 16 환경에서도 컴파일이 깨지지 않는다.

extension View {

    /// 카드/배너처럼 떠 있는 컨테이너에 Liquid Glass 효과를 적용한다.
    /// iOS 26 미만 또는 구버전 SDK 빌드 시 원본 뷰를 그대로 반환한다.
    ///
    /// - Parameter shape: glass 효과의 클리핑 형태.
    @ViewBuilder
    func liquidGlass<S: Shape>(in shape: S) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(in: shape)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// 모서리 반지름을 받아 `RoundedRectangle` 형태로 glass 효과를 적용한다.
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat) -> some View {
        self.liquidGlass(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// 버튼·캡슐 칩 같은 인터랙티브 요소에 Liquid Glass 버튼 스타일을 적용한다.
    /// iOS 26 미만 또는 구버전 SDK 빌드 시 원본 뷰를 그대로 반환한다.
    @ViewBuilder
    func liquidGlassButton() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
