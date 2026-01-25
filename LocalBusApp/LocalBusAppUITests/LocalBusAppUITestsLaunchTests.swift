import XCTest

final class LocalBusAppUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 앱이 정상적으로 실행되는지 확인
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // 앱 실행 후 메인 화면이 표시되는지 확인
        let navigationBar = app.navigationBars["시외버스"]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5), "앱이 정상적으로 실행되어야 합니다")

        // 스크린샷 첨부
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 다크 모드에서 앱이 정상적으로 실행되는지 확인
    func testLaunchInDarkMode() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UIUserInterfaceStyle", "Dark"]
        app.launch()

        // 앱 실행 확인
        let navigationBar = app.navigationBars["시외버스"]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5), "다크 모드에서 앱이 정상적으로 실행되어야 합니다")

        // 스크린샷 첨부
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen (Dark Mode)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
