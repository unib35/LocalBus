import XCTest

final class AccessibilityLayoutTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func test_최대글자에서도_방향변경과시간표탐색() {
        let app = UITest.launchToHome {
            $0.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-colorSchemePreference", "0"]
        }
        defer { app.terminate() }
        let reverse = app.element(id: AccessibilityID.direction(AppFixture.Direction.sasangToJangyu))
        XCTAssertTrue(reverse.isHittable)
        XCTAssertGreaterThanOrEqual(reverse.frame.height, 44)
        reverse.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: app.element(id: AccessibilityID.direction(AppFixture.Direction.sasangToJangyu)))
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
        attach(app, "최대 글자 홈")
        app.selectTab(AccessibilityID.Tab.timetable)
        XCTAssertTrue(app.element(id: AccessibilityID.Timetable.list).exists)
        let visibleTime = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[0-2][0-9]:[0-5][0-9]"))
                .allElementsBoundByIndex.contains { $0.isHittable }
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [visibleTime], timeout: 5), .completed, "최대 글자에서도 출발 시각이 화면에 보여야 합니다")
        attach(app, "최대 글자 시간표")
    }

    func test_iPad가로화면_홈과설정() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("iPad 회전 검증") }
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = UITest.launchToHome()
        defer { app.terminate() }
        XCTAssertGreaterThan(app.frame.width, app.frame.height)
        let reverse = app.element(id: AccessibilityID.direction(AppFixture.Direction.sasangToJangyu))
        XCTAssertTrue(reverse.isHittable)
        XCTAssertLessThanOrEqual(reverse.frame.maxX, app.frame.maxX)
        attach(app, "iPad 가로 홈")
        app.selectTab(AccessibilityID.Tab.settings)
        XCTAssertTrue(app.element(id: AccessibilityID.Settings.root).exists)
        attach(app, "iPad 가로 설정")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
