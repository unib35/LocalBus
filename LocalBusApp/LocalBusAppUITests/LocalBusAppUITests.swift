import XCTest

/// 현재 UI(디자인 캔버스 개선안) 기준 UI 테스트.
/// 홈: 노선 헤더 + 히어로 + 이어지는 버스, 전체 시간표: 시간대별 그리드, 설정: 그룹 리스트.
final class LocalBusAppUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        // 온보딩은 별도 테스트에서 검사하고, 나머지는 홈부터 시작한다.
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]

        // 알림·위치 등 시스템 권한 알림은 허용하고 넘어간다.
        addUIInterruptionMonitor(withDescription: "시스템 권한") { alert in
            for title in ["허용", "Allow", "확인", "OK"] {
                let button = alert.buttons[title]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }

        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - 헬퍼

    /// 홈 히어로가 그려질 때까지 기다린다 (운행 중이면 "다음 버스", 아니면 "오늘 운행 종료").
    @discardableResult
    private func waitForHome(timeout: TimeInterval = 10) -> Bool {
        let nextBus = app.staticTexts["다음 버스"]
        let ended = app.staticTexts["오늘 운행 종료"]
        let beforeFirst = app.staticTexts["오늘 운행 시작 전"]
        let longGap = app.staticTexts["지금은 운행 간격이 길어요"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if nextBus.exists || ended.exists || beforeFirst.exists || longGap.exists { return true }
            app.tap() // 인터럽션 모니터 트리거
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        return false
    }

    private func openTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "탭 '\(name)'이 있어야 합니다")
        tab.tap()
    }

    // MARK: - 홈

    /// 홈에 노선 헤더(방향 바꾸기 버튼)와 히어로가 표시된다
    func testHomeShowsRouteHeaderAndHero() throws {
        XCTAssertTrue(waitForHome(), "홈 히어로(다음 버스 / 오늘 운행 종료)가 표시되어야 합니다")

        let swapButton = app.buttons["방향 바꾸기"]
        XCTAssertTrue(swapButton.waitForExistence(timeout: 3), "방향 바꾸기 버튼이 있어야 합니다")

        let lineMenu = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "노선 선택")).firstMatch
        XCTAssertTrue(lineMenu.exists, "노선 선택 칩이 있어야 합니다")
    }

    /// 홈에 시간표 컨텍스트 라벨("M월 d일 요일 · … 시간표")이 표시된다
    func testHomeShowsScheduleContext() throws {
        XCTAssertTrue(waitForHome())

        let context = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "^\\d{1,2}월 \\d{1,2}일 .+시간표$")
        ).firstMatch
        XCTAssertTrue(context.waitForExistence(timeout: 3), "날짜·시간표 컨텍스트 라벨이 표시되어야 합니다")
    }

    /// 방향 바꾸기를 누르면 출발지 요약이 반대 방향으로 바뀐다
    func testSwapDirectionUpdatesRouteSummary() throws {
        XCTAssertTrue(waitForHome())

        let swapButton = app.buttons["방향 바꾸기"]
        XCTAssertTrue(swapButton.waitForExistence(timeout: 3))

        let summaryBefore = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "출발 ·")
        ).firstMatch
        XCTAssertTrue(summaryBefore.waitForExistence(timeout: 3), "노선 요약 한 줄이 있어야 합니다")
        let before = summaryBefore.label

        swapButton.tap()

        let changed = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@ AND label != %@", "출발 ·", before)
        ).firstMatch
        XCTAssertTrue(changed.waitForExistence(timeout: 3), "방향을 바꾸면 출발지 요약이 달라져야 합니다")
    }

    /// 이어지는 버스 목록에 HH:mm 형식 시각이 표시된다
    func testHomeShowsUpcomingBuses() throws {
        XCTAssertTrue(waitForHome())

        let listTitle = app.staticTexts["이어지는 버스"]
        let tomorrowTitle = app.staticTexts["내일 아침 버스"]
        XCTAssertTrue(listTitle.waitForExistence(timeout: 3) || tomorrowTitle.exists, "이어지는 버스(또는 내일 아침 버스) 섹션이 있어야 합니다")

        let timeRow = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "^\\d{2}:\\d{2}$")
        ).firstMatch
        XCTAssertTrue(timeRow.exists, "HH:mm 형식의 출발 시각이 표시되어야 합니다")
    }

    // MARK: - 전체 시간표

    /// 전체 시간표 탭에 평일/주말 세그먼트와 시간대 그리드가 표시된다
    func testTimetableTabShowsHourGrid() throws {
        XCTAssertTrue(waitForHome())
        openTab("전체 시간표")

        let weekday = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "평일")).firstMatch
        let weekend = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "주말")).firstMatch
        XCTAssertTrue(weekday.waitForExistence(timeout: 5), "평일 세그먼트가 있어야 합니다")
        XCTAssertTrue(weekend.exists, "주말 세그먼트가 있어야 합니다")

        let hourLabel = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^\\d{2}시$")).firstMatch
        XCTAssertTrue(hourLabel.waitForExistence(timeout: 5), "시간대 라벨(예: 07시)이 표시되어야 합니다")

        let cell = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^\\d{2}:\\d{2} 출발.*")).firstMatch
        XCTAssertTrue(cell.exists, "시각 셀이 표시되어야 합니다")
    }

    /// 주말 세그먼트를 누르면 선택 상태가 바뀐다
    func testScheduleSegmentSwitches() throws {
        XCTAssertTrue(waitForHome())
        openTab("전체 시간표")

        let weekday = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "평일")).firstMatch
        let weekend = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "주말")).firstMatch
        XCTAssertTrue(weekday.waitForExistence(timeout: 5))

        let total = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "총 ")).firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 3), "총 운행 횟수 범례가 있어야 합니다")
        let totalBefore = total.label

        if weekend.isSelected {
            weekday.tap()
        } else {
            weekend.tap()
        }

        let totalAfter = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "총 ")).firstMatch
        XCTAssertTrue(totalAfter.waitForExistence(timeout: 3))
        XCTAssertNotEqual(totalAfter.label, totalBefore, "평일/주말을 바꾸면 총 운행 횟수가 달라져야 합니다")
    }

    /// 시각 셀을 누르면 상세 시트(알림 버튼·요금)가 열린다
    func testTimetableCellOpensDetailSheet() throws {
        XCTAssertTrue(waitForHome())
        openTab("전체 시간표")

        let cell = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^\\d{2}:\\d{2} 출발.*")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()

        let alarmOff = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "알림 받기")).firstMatch
        let alarmOn = app.buttons["알림 끄기"]
        let fare = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", "요금")).firstMatch

        XCTAssertTrue(alarmOff.waitForExistence(timeout: 5) || alarmOn.exists, "상세 시트에 알림 버튼이 있어야 합니다")
        // 통합안: 시점·반복 옵션은 '알림' 제목 옆 요약을 눌러야 펼쳐진다
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "알림 옵션")).firstMatch.tap()
        XCTAssertTrue(app.buttons["10분 전"].waitForExistence(timeout: 3), "알림 시점 칩이 있어야 합니다")
        XCTAssertTrue(app.switches["평일마다 반복"].exists, "평일 반복 토글이 있어야 합니다")
        XCTAssertTrue(fare.exists, "상세 시트에 요금 섹션이 있어야 합니다")
    }

    // MARK: - 설정

    /// 설정 탭에 시간표 데이터 행과 알림·디스플레이·정보 그룹이 표시된다
    func testSettingsTabShowsGroups() throws {
        XCTAssertTrue(waitForHome())
        openTab("설정")

        XCTAssertTrue(app.staticTexts["설정"].waitForExistence(timeout: 5), "설정 제목이 있어야 합니다")
        XCTAssertTrue(app.staticTexts["최신 시간표예요"].exists || app.buttons["시간표 새로고침"].exists, "시간표 데이터 행이 있어야 합니다")
        XCTAssertTrue(app.staticTexts["알림"].exists, "알림 그룹이 있어야 합니다")
        XCTAssertTrue(app.staticTexts["디스플레이"].exists, "디스플레이 그룹이 있어야 합니다")
        XCTAssertTrue(app.staticTexts["정보"].exists, "정보 그룹이 있어야 합니다")
        XCTAssertGreaterThanOrEqual(app.switches.count, 3, "알림 토글이 3개 이상 있어야 합니다")
    }

    /// 설정 → 버스 이용 안내로 이동한다
    func testSettingsNavigatesToTips() throws {
        XCTAssertTrue(waitForHome())
        openTab("설정")

        let tips = app.buttons["버스 이용 안내"]
        XCTAssertTrue(tips.waitForExistence(timeout: 5))
        tips.tap()

        XCTAssertTrue(app.staticTexts["처음 타신다면"].waitForExistence(timeout: 5), "이용 안내 강조 그룹이 표시되어야 합니다")
    }

    // MARK: - Pull to Refresh

    /// 홈에서 당겨서 새로고침 후에도 히어로가 유지된다
    func testPullToRefreshKeepsHome() throws {
        XCTAssertTrue(waitForHome())

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3), "스크롤 뷰가 존재해야 합니다")

        let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        start.press(forDuration: 0.1, thenDragTo: end)

        XCTAssertTrue(waitForHome(), "새로고침 후에도 홈 히어로가 표시되어야 합니다")
    }
}
