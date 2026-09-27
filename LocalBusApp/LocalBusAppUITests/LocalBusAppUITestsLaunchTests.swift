import XCTest

final class LocalBusAppUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// 앱이 정상적으로 실행되어 탭 바가 나타나는지 확인
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        let homeTab = app.tabBars.buttons["홈"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10), "앱이 정상적으로 실행되어야 합니다")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 다크 모드 설정으로 앱이 정상적으로 실행되는지 확인
    func testLaunchInDarkMode() throws {
        let app = XCUIApplication()
        // AppStorage("colorSchemePreference")를 실행 인자로 덮어쓴다 (1 = 다크)
        app.launchArguments = ["-colorSchemePreference", "1", "-hasCompletedOnboarding", "YES"]
        app.launch()

        let homeTab = app.tabBars.buttons["홈"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10), "다크 모드에서 앱이 정상적으로 실행되어야 합니다")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen (Dark Mode)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
