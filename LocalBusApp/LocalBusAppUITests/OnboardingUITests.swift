import XCTest

/// 첫 실행 온보딩 3단계 흐름.
final class OnboardingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// 노선 선택 → 알림(나중에) → 시작하기 → 홈
    func testOnboardingFlowReachesHome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "NO"]
        app.launch()

        // 1단계: 노선 선택
        let next = app.buttons["다음"]
        XCTAssertTrue(next.waitForExistence(timeout: 20), "온보딩 1단계(노선 선택)가 떠야 합니다")

        let yulha = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "율하 → 사상")).firstMatch
        XCTAssertTrue(yulha.exists, "노선 선택지에 율하 → 사상이 있어야 합니다")
        yulha.tap()
        next.tap()

        // 2단계: 알림 — 권한 창 없이 건너뛴다
        let later = app.buttons["나중에"]
        XCTAssertTrue(later.waitForExistence(timeout: 5), "온보딩 2단계(알림)가 떠야 합니다")
        XCTAssertTrue(app.buttons["알림 켜기"].exists)
        later.tap()

        // 3단계: 준비 완료 — 고른 노선의 미리보기
        let start = app.buttons["시작하기"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "온보딩 3단계(준비 완료)가 떠야 합니다")
        XCTAssertTrue(app.staticTexts["알아두면 좋아요"].exists)
        start.tap()

        // 홈: 온보딩에서 고른 율하 노선이 헤더에 보여야 한다
        let swapButton = app.buttons["방향 바꾸기"]
        XCTAssertTrue(swapButton.waitForExistence(timeout: 10), "온보딩 뒤 홈이 보여야 합니다")
        let summary = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "율하")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "홈 요약이 온보딩에서 고른 율하 노선이어야 합니다")
    }

    /// 건너뛰기를 누르면 바로 홈으로 간다
    func testOnboardingSkipGoesHome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "NO"]
        app.launch()

        let skip = app.buttons["건너뛰기"]
        XCTAssertTrue(skip.waitForExistence(timeout: 20))
        skip.tap()

        XCTAssertTrue(app.buttons["방향 바꾸기"].waitForExistence(timeout: 10), "건너뛰기 뒤 홈이 보여야 합니다")
    }
}
