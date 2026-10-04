import XCTest

final class AccessibilityLayoutTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    /// 최대 글자 크기 + 라이트 모드에서도 홈과 전체 시간표가 깨지지 않고 탐색된다.
    func test_최대글자에서도_홈과시간표탐색() {
        let app = UITest.launchToHome {
            $0.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-colorSchemePreference", "0"]
        }
        defer { app.terminate() }
        attach(app, "최대 글자 홈")

        app.selectTab(AccessibilityID.Tab.timetable)
        let visibleTime = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[0-2][0-9]:[0-5][0-9]"))
                .allElementsBoundByIndex.contains { $0.isHittable }
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [visibleTime], timeout: 5), .completed, "최대 글자에서도 출발 시각이 화면에 보여야 합니다")
        attach(app, "최대 글자 시간표")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
