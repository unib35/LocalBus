import XCTest

/// 홈·시간표·설정 화면의 주요 흐름을 검증한다.
///
/// 주요 요소는 AccessibilityID로 찾고, 시스템 탭은 식별자 또는 접근성 이름으로 찾는다.
final class LocalBusAppUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = UITest.launchToHome()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func test_정류장탭_노선변경과_홈복귀() throws {
        let stopsTab = app.tabBars.buttons["정류장 위치"]
        XCTAssertTrue(stopsTab.waitForExistence(timeout: UITest.contentTimeout))
        stopsTab.tap()
        XCTAssertTrue(app.navigationBars["정류장"].waitForExistence(timeout: UITest.contentTimeout))
        let yulha = app.element(id: AccessibilityID.routeLine(AppFixture.Line.yulha))
        XCTAssertTrue(yulha.waitForExistence(timeout: UITest.contentTimeout))
        yulha.tap()
        XCTAssertTrue(app.element(id: AccessibilityID.direction(AppFixture.Direction.yulhaToSasang)).waitForSelected(timeout: 5))
        app.selectTab(AccessibilityID.Tab.home)
        XCTAssertTrue(app.element(id: AccessibilityID.Home.root).waitForExistence(timeout: 5))
    }

    // MARK: - 홈 화면

    /// 홈의 핵심 섹션이 렌더링되는지 확인한다.
    func test_홈_주요_섹션이_표시된다() throws {
        XCTAssertTrue(
            app.element(id: AccessibilityID.Home.header).waitForExistence(timeout: UITest.contentTimeout),
            "대시보드 헤더가 표시되어야 합니다"
        )
        XCTAssertTrue(
            app.element(id: AccessibilityID.Home.upcomingBuses).waitForExistence(timeout: UITest.contentTimeout),
            "예정된 버스 섹션이 표시되어야 합니다"
        )
    }

    /// 히어로 영역은 시각·데이터 상태에 따라 네 형태 중 하나로 나타난다.
    /// 어느 것이든 하나는 반드시 있어야 한다.
    func test_홈_히어로가_네_상태중_하나를_표시한다() throws {
        let candidates = [
            AccessibilityID.Home.heroNextBus,
            AccessibilityID.Home.heroServiceEnded,
            AccessibilityID.Home.heroLoading,
            AccessibilityID.Home.heroUnavailable,
        ]

        let predicate = NSPredicate(format: "exists == true")
        let expectations = candidates.map { id in
            expectation(for: predicate, evaluatedWith: app.element(id: id))
        }

        // 넷 중 하나만 충족되면 통과.
        let result = XCTWaiter().wait(for: expectations, timeout: UITest.contentTimeout)
        XCTAssertTrue(
            result == .completed || candidates.contains { app.element(id: $0).exists },
            "히어로 카드(다음 버스/운행 종료/로딩/정보 없음) 중 하나가 표시되어야 합니다"
        )
    }

    /// 방향 선택기로 반대 방향을 선택할 수 있는지 확인한다.
    func test_홈_방향_전환이_동작한다() throws {
        let outbound = app.element(id: AccessibilityID.direction(AppFixture.Direction.jangyuToSasang))
        let inbound = app.element(id: AccessibilityID.direction(AppFixture.Direction.sasangToJangyu))

        // routes 데이터가 없으면 선택기 자체가 표시되지 않으므로 검증 대상이 아니다.
        guard outbound.waitForExistence(timeout: UITest.contentTimeout) else {
            throw XCTSkip("노선 데이터가 없어 방향 선택기가 표시되지 않습니다")
        }
        XCTAssertTrue(inbound.exists, "'사상 → 장유' 방향 버튼이 있어야 합니다")

        inbound.tap()
        XCTAssertTrue(
            inbound.waitForSelected(timeout: 5),
            "탭한 방향이 선택 상태가 되어야 합니다"
        )

        outbound.tap()
        XCTAssertTrue(
            outbound.waitForSelected(timeout: 5),
            "원래 방향으로 되돌릴 수 있어야 합니다"
        )
    }

    /// 글자와 버튼 여백도 전환을 실행해야 합니다.
    func test_홈_방향글자와_변경버튼여백으로_왕복전환() throws {
        let outboundID = AccessibilityID.direction(AppFixture.Direction.jangyuToSasang)
        let inboundID = AccessibilityID.direction(AppFixture.Direction.sasangToJangyu)
        let outbound = app.element(id: outboundID)
        XCTAssertTrue(outbound.waitForExistence(timeout: UITest.contentTimeout))
        outbound.tap()
        XCTAssertTrue(app.element(id: inboundID).waitForSelected(timeout: 5))

        // 아이콘/글자가 아닌 버튼 안쪽 여백을 눌러 터치 영역을 검증합니다.
        app.element(id: outboundID).coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertTrue(app.element(id: outboundID).waitForSelected(timeout: 5))
    }

    /// 노선(장유/율하) 전환 시 방향 버튼이 해당 노선 것으로 교체되는지 확인한다.
    func test_홈_노선_전환시_방향_버튼이_교체된다() throws {
        let yulha = app.element(id: AccessibilityID.routeLine(AppFixture.Line.yulha))
        guard yulha.waitForExistence(timeout: UITest.contentTimeout) else {
            throw XCTSkip("율하 노선이 제공되지 않습니다")
        }

        yulha.tap()

        let yulhaDirection = app.element(id: AccessibilityID.direction(AppFixture.Direction.yulhaToSasang))
        XCTAssertTrue(
            yulhaDirection.waitForExistence(timeout: 10),
            "율하 노선 선택 후 '율하 → 사상' 방향 버튼이 나타나야 합니다"
        )

        let jangyuDirection = app.element(id: AccessibilityID.direction(AppFixture.Direction.jangyuToSasang))
        XCTAssertFalse(
            jangyuDirection.exists,
            "다른 노선의 방향 버튼은 사라져야 합니다"
        )
    }

    // MARK: - 탭 이동

    /// 세 탭을 오갈 수 있고 각 화면 루트가 나타나는지 확인한다.
    func test_탭_전환이_동작한다() throws {
        app.selectTab(AccessibilityID.Tab.timetable)
        XCTAssertTrue(
            app.element(id: AccessibilityID.Timetable.list).waitForExistence(timeout: UITest.contentTimeout),
            "전체 시간표 화면이 표시되어야 합니다"
        )

        app.selectTab(AccessibilityID.Tab.settings)
        XCTAssertTrue(
            app.element(id: AccessibilityID.Settings.root).waitForExistence(timeout: UITest.contentTimeout),
            "설정 화면이 표시되어야 합니다"
        )

        app.selectTab(AccessibilityID.Tab.home)
        XCTAssertTrue(
            app.element(id: AccessibilityID.Home.root).waitForExistence(timeout: UITest.contentTimeout),
            "홈으로 돌아올 수 있어야 합니다"
        )
    }

    // MARK: - 전체 시간표

    /// 시간표 목록에 실제 시간 행이 렌더링되는지 확인한다.
    func test_시간표_목록에_시간_행이_표시된다() throws {
        app.selectTab(AccessibilityID.Tab.timetable)

        let list = app.element(id: AccessibilityID.Timetable.list)
        XCTAssertTrue(
            list.waitForExistence(timeout: UITest.contentTimeout),
            "시간표 목록이 표시되어야 합니다"
        )

        let rows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "timetable.row.")
        )
        XCTAssertGreaterThan(rows.count, 0, "시간표에 최소 한 개 이상의 시간 행이 있어야 합니다")
    }

    /// 평일/주말 시간표 유형을 전환할 수 있는지 확인한다.
    func test_시간표_유형_전환이_동작한다() throws {
        app.selectTab(AccessibilityID.Tab.timetable)

        let weekday = app.element(id: AccessibilityID.schedule(AppFixture.Schedule.weekday))
        let weekend = app.element(id: AccessibilityID.schedule(AppFixture.Schedule.weekend))

        XCTAssertTrue(weekday.waitForExistence(timeout: UITest.contentTimeout), "평일 선택 버튼이 있어야 합니다")
        XCTAssertTrue(weekend.exists, "주말 선택 버튼이 있어야 합니다")

        weekend.tap()
        XCTAssertTrue(weekend.waitForSelected(timeout: 5), "주말이 선택 상태가 되어야 합니다")

        weekday.tap()
        XCTAssertTrue(weekday.waitForSelected(timeout: 5), "평일로 되돌릴 수 있어야 합니다")
    }
}

private extension XCUIElement {

    /// 선택 상태(`.isSelected` 트레이트)가 될 때까지 기다린다.
    /// SwiftUI는 상태 변경에 애니메이션을 걸기 때문에 즉시 반영되지 않는다.
    func waitForSelected(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isSelected == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
