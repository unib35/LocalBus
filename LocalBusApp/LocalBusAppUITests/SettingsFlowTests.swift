import XCTest

final class SettingsFlowTests: XCTestCase {
    func test_라이트모드_설정과_하위페이지_진입() throws {
        continueAfterFailure = false
        let app = UITest.launchToHome { app in
            app.launchArguments += ["-colorSchemePreference", "0"]
        }
        app.selectTab(AccessibilityID.Tab.settings)
        XCTAssertTrue(app.switches["막차 30분 전 알림"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.switches["공지사항 알림"].exists)
        attach(app, name: "설정 라이트 모드")

        for (row, title) in [
            ("버스 이용 안내", "버스 이용 안내"),
            ("시간표 제보", "시간표 제보"),
            ("문의하기", "문의하기"),
            ("이용약관 및 개인정보 처리방침", "이용약관 및 개인정보")
        ] {
            let link = app.staticTexts[row].firstMatch
            for _ in 0..<6 {
                if link.exists && link.isHittable { break }
                app.swipeUp()
            }
            XCTAssertTrue(link.isHittable, "설정 항목: \(row)")
            link.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10))
            if row == "시간표 제보" || row == "문의하기" {
                let buttonTitle = row == "시간표 제보" ? "제보 내용 공유" : "작성 내용 공유"
                let fallback = app.buttons[buttonTitle]
                let mail = app.buttons["메일 작성으로 이동"]
                let submit = fallback.exists ? fallback : mail
                XCTAssertTrue(submit.exists)
                XCTAssertFalse(submit.isEnabled, "빈 내용을 보낼 수 없어야 합니다")
            }
            attach(app, name: title)
            app.navigationBars[title].buttons.element(boundBy: 0).tap()
        }
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
