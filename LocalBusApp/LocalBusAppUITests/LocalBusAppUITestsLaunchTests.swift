import XCTest

/// 앱이 실행되어 홈 화면까지 도달하는지 확인하고 스크린샷을 남긴다.
final class LocalBusAppUITestsLaunchTests: XCTestCase {

    /// 기본값(true)이면 지원하는 UI 구성마다 각 테스트를 반복 실행한다.
    /// 이 앱은 스플래시만 2.5초가 걸려 반복 비용이 커서 한 번만 돌린다.
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 콜드 스타트 후 홈 화면이 나타나는지 확인한다.
    func test_앱이_실행되어_홈까지_도달한다() throws {
        let app = UITest.launchToHome()

        attachScreenshot(of: app, named: "홈 화면")
    }

    /// 라이트 모드 선호 설정에서도 실행이 되는지 확인한다.
    ///
    /// 앱은 `@AppStorage("colorSchemePreference")` 로 자체 색상 모드를 관리하며
    /// 기본값이 다크다. 여기서는 시스템 스타일을 라이트로 주더라도 실행 경로가
    /// 깨지지 않는지만 확인한다.
    func test_라이트_모드에서도_실행된다() throws {
        let app = UITest.launchToHome { app in
            app.launchArguments += ["-UIUserInterfaceStyle", "Light"]
        }

        attachScreenshot(of: app, named: "홈 화면 (라이트 모드 실행)")
    }

    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
