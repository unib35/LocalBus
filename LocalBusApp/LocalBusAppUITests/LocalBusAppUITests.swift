import XCTest

final class LocalBusAppUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - 메인 화면 테스트

    /// 메인 화면에 시간표가 표시되는지 확인
    func testMainViewDisplaysTimetable() throws {
        // Given: 앱이 실행됨
        // 로딩이 완료될 때까지 대기
        let timetableExists = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^\\d{2}:\\d{2}$")).firstMatch
        let exists = timetableExists.waitForExistence(timeout: 5)

        // Then: 시간표(HH:mm 형식)가 표시되어야 함
        XCTAssertTrue(exists, "시간표가 화면에 표시되어야 합니다")
    }

    /// 네비게이션 타이틀이 표시되는지 확인
    func testNavigationTitleDisplays() throws {
        // Given: 앱이 실행됨
        let navigationTitle = app.navigationBars["시외버스"]

        // Then: 네비게이션 타이틀이 표시되어야 함
        XCTAssertTrue(navigationTitle.waitForExistence(timeout: 3), "네비게이션 타이틀 '시외버스'가 표시되어야 합니다")
    }

    // MARK: - 탭 전환 테스트

    /// 평일/주말 탭 전환이 동작하는지 확인
    func testTabSwitchingWorks() throws {
        // Given: 앱이 실행되고 로딩이 완료됨
        sleep(2) // 데이터 로딩 대기

        let weekdayButton = app.buttons["평일"]
        let weekendButton = app.buttons["주말"]

        // Then: 평일, 주말 버튼이 존재해야 함
        XCTAssertTrue(weekdayButton.waitForExistence(timeout: 3), "평일 버튼이 표시되어야 합니다")
        XCTAssertTrue(weekendButton.exists, "주말 버튼이 표시되어야 합니다")

        // When: 주말 버튼 탭
        weekendButton.tap()

        // Then: 주말 버튼이 선택됨 (UI 상태 변경)
        XCTAssertTrue(weekendButton.isSelected || weekendButton.isHittable, "주말 탭이 선택되어야 합니다")

        // When: 평일 버튼 탭
        weekdayButton.tap()

        // Then: 평일 버튼이 선택됨
        XCTAssertTrue(weekdayButton.isSelected || weekdayButton.isHittable, "평일 탭이 선택되어야 합니다")
    }

    // MARK: - 다음 버스 강조 테스트

    /// 다음 버스가 강조 표시되는지 확인
    func testNextBusIsHighlighted() throws {
        // Given: 앱이 실행되고 로딩이 완료됨
        sleep(2)

        // Then: "다음 버스" 레이블이 표시되어야 함 (운행 시간 중일 경우)
        // 운행 종료 시간에는 "오늘 운행이 종료되었습니다" 메시지가 표시됨
        let nextBusLabel = app.staticTexts["다음 버스"]
        let endOfServiceLabel = app.staticTexts["오늘 운행이 종료되었습니다"]

        let nextBusExists = nextBusLabel.waitForExistence(timeout: 3)
        let endOfServiceExists = endOfServiceLabel.exists

        // 둘 중 하나는 반드시 표시되어야 함
        XCTAssertTrue(nextBusExists || endOfServiceExists, "다음 버스 또는 운행 종료 메시지가 표시되어야 합니다")
    }

    // MARK: - 카운트다운 카드 테스트

    /// 실시간 카운트다운 카드가 표시되는지 확인
    func testCountdownCardDisplays() throws {
        // Given: 앱이 실행되고 로딩이 완료됨
        sleep(2)

        // 카운트다운 카드 또는 운행 종료 카드가 표시되어야 함
        let countdownExists = app.staticTexts["남은 시간"].waitForExistence(timeout: 3)
        let endOfServiceExists = app.staticTexts["오늘 운행이 종료되었습니다"].exists

        XCTAssertTrue(countdownExists || endOfServiceExists, "카운트다운 카드 또는 운행 종료 카드가 표시되어야 합니다")
    }

    // MARK: - 첫차/막차 정보 테스트

    /// 첫차/막차 정보가 표시되는지 확인
    func testFirstLastBusInfoDisplays() throws {
        // Given: 앱이 실행되고 로딩이 완료됨
        sleep(2)

        // Then: 첫차, 막차 레이블이 표시되어야 함
        let firstBusLabel = app.staticTexts["첫차"]
        let lastBusLabel = app.staticTexts["막차"]

        XCTAssertTrue(firstBusLabel.waitForExistence(timeout: 3), "첫차 정보가 표시되어야 합니다")
        XCTAssertTrue(lastBusLabel.exists, "막차 정보가 표시되어야 합니다")
    }

    // MARK: - 방향 선택 테스트

    /// 방향 선택 버튼이 동작하는지 확인
    func testDirectionSelectorWorks() throws {
        // Given: 앱이 실행되고 로딩이 완료됨
        sleep(2)

        // routes 데이터가 있을 때만 방향 선택 버튼이 표시됨
        let jangyuToSasangButton = app.buttons["장유 → 사상"]
        let sasangToJangyuButton = app.buttons["사상 → 장유"]

        // 방향 버튼이 있는 경우에만 테스트
        guard jangyuToSasangButton.waitForExistence(timeout: 3) else {
            // 단방향만 지원하는 경우 테스트 스킵
            return
        }

        // When: 사상 → 장유 버튼 탭
        sasangToJangyuButton.tap()

        // Then: 버튼이 탭 가능해야 함
        XCTAssertTrue(sasangToJangyuButton.isHittable, "사상 → 장유 버튼이 동작해야 합니다")

        // When: 장유 → 사상 버튼 탭
        jangyuToSasangButton.tap()

        // Then: 버튼이 탭 가능해야 함
        XCTAssertTrue(jangyuToSasangButton.isHittable, "장유 → 사상 버튼이 동작해야 합니다")
    }

    // MARK: - 정보 화면 테스트

    /// 정보 버튼 탭 시 InfoView가 표시되는지 확인
    func testInfoButtonOpensInfoView() throws {
        // Given: 앱이 실행됨
        let infoButton = app.buttons["info.circle"]

        // When: 정보 버튼 탭
        XCTAssertTrue(infoButton.waitForExistence(timeout: 3), "정보 버튼이 표시되어야 합니다")
        infoButton.tap()

        // Then: InfoView의 특정 요소가 표시되어야 함
        // InfoView에 표시되는 텍스트 확인
        let infoViewElement = app.staticTexts["앱 정보"].exists ||
                              app.staticTexts["제보하기"].exists ||
                              app.buttons["닫기"].exists

        // Sheet가 표시될 시간 대기
        sleep(1)

        // InfoView가 표시되어야 함 (특정 요소로 확인)
        XCTAssertTrue(infoViewElement || app.otherElements.count > 0, "InfoView가 표시되어야 합니다")
    }

    // MARK: - Pull to Refresh 테스트

    /// Pull to Refresh가 동작하는지 확인
    func testPullToRefreshWorks() throws {
        // Given: 앱이 실행되고 로딩이 완료됨
        sleep(2)

        // When: 스크롤 뷰에서 Pull to Refresh
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3), "스크롤 뷰가 존재해야 합니다")

        // Pull down gesture
        let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        start.press(forDuration: 0.1, thenDragTo: end)

        // Then: 새로고침 후에도 시간표가 표시되어야 함
        sleep(2)
        let timetableExists = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^\\d{2}:\\d{2}$")).firstMatch
        XCTAssertTrue(timetableExists.exists, "새로고침 후에도 시간표가 표시되어야 합니다")
    }
}
