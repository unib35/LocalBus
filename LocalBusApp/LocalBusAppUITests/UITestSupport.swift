import XCTest

/// UI 테스트 공통 준비 절차.
///
/// 앱은 실행 직후 2.2초 동안 스플래시를 띄우고 0.3초에 걸쳐 페이드아웃한다.
/// 그동안 본 화면은 이미 계층에 존재하지만 스플래시에 가려져 있어, 곧바로 요소를
/// 검증하면 타이밍에 따라 결과가 흔들린다. 그래서 모든 테스트는 스플래시가
/// 사라진 것을 확인한 뒤 시작한다.
enum UITest {

    /// 스플래시 노출(2.2s) + 페이드(0.3s) + 콜드 스타트 여유.
    static let splashTimeout: TimeInterval = 20

    /// 원격 시간표를 받아오는 경로가 있어 첫 렌더까지 네트워크를 기다릴 수 있다.
    static let contentTimeout: TimeInterval = 20

    /// 앱을 실행하고 홈 화면이 나타날 때까지 기다린다.
    @discardableResult
    static func launchToHome(
        _ configure: ((XCUIApplication) -> Void)? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIApplication {
        let app = XCUIApplication()
        configure?(app)
        app.launch()

        let splash = app.descendants(matching: .any)[AccessibilityID.splash]
        if splash.exists {
            XCTAssertTrue(
                splash.waitForNonExistence(timeout: splashTimeout),
                "스플래시가 \(Int(splashTimeout))초 안에 사라져야 합니다",
                file: file, line: line
            )
        }

        let home = app.descendants(matching: .any)[AccessibilityID.Home.root]
        XCTAssertTrue(
            home.waitForExistence(timeout: contentTimeout),
            "홈 화면이 표시되어야 합니다",
            file: file, line: line
        )

        return app
    }
}

extension XCUIApplication {

    /// 식별자로 요소를 찾는다.
    ///
    /// SwiftUI의 `.buttonStyle(.plain)` 버튼은 XCUITest에서 `.button` 타입으로
    /// 노출되지 않는다(실제로 `app.buttons[...]` 로는 찾지 못했다). 그래서
    /// 타입을 특정하지 않고 전체 계층에서 식별자로만 찾는다.
    func element(id: String) -> XCUIElement {
        descendants(matching: .any)[id]
    }

    /// 탭 바 항목을 식별자로 선택한다.
    func selectTab(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let tab = tabBars.buttons[identifier]
        XCTAssertTrue(
            tab.waitForExistence(timeout: 10),
            "탭 '\(identifier)' 이 존재해야 합니다",
            file: file, line: line
        )
        tab.tap()
    }
}

extension XCUIElement {

    /// 존재하면서 화면에 실제로 보이는지. SwiftUI에서 요소가 계층에는 있지만
    /// 스크롤 밖에 있는 경우를 걸러낸다.
    var isVisible: Bool {
        exists && !frame.isEmpty
    }
}
