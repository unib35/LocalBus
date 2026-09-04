import Foundation

/// UI 테스트가 화면 요소를 찾을 때 쓰는 식별자.
///
/// 표시 텍스트(`"평일"`, `"장유 → 사상"`)를 직접 매칭하면 디자인이나 문구가 바뀔 때마다
/// 테스트가 깨진다. 실제로 Liquid Glass 재디자인 이후 기존 UI 테스트 12개가 전부
/// 실패했다. 화면에 보이는 문구와 분리된 식별자를 두어 그 결합을 끊는다.
///
/// - Important: UI 테스트 타깃은 앱 모듈을 import할 수 없으므로
///   `LocalBusAppUITests/AccessibilityID.swift` 에 같은 값을 미러링해 둔다.
///   여기를 고치면 그쪽도 함께 고쳐야 한다.
enum AccessibilityID {

    /// 스플래시 화면. 테스트는 이 요소가 사라질 때까지 기다린 뒤 본 화면을 검증한다.
    static let splash = "splash.root"

    enum Tab {
        static let home = "tab.home"
        static let timetable = "tab.timetable"
        static let settings = "tab.settings"
    }

    enum Home {
        static let root = "home.root"
        static let header = "home.header"
        static let directionSelector = "home.directionSelector"
        static let upcomingBuses = "home.upcomingBuses"
        static let firstLastBus = "home.firstLastBus"

        /// 히어로 영역은 상태에 따라 셋 중 하나만 나타난다.
        static let heroLoading = "home.hero.loading"
        static let heroNextBus = "home.hero.nextBus"
        static let heroServiceEnded = "home.hero.serviceEnded"
        static let heroUnavailable = "home.hero.unavailable"
    }

    enum Timetable {
        static let root = "timetable.root"
        static let scheduleSegment = "timetable.scheduleSegment"
        static let list = "timetable.list"

        /// 개별 시간 행. `time` 은 `"06:20"` 형식.
        static func row(_ time: String) -> String { "timetable.row.\(time)" }
    }

    enum Settings {
        static let root = "settings.root"
    }

    /// 노선 선택(장유/율하). `line` 은 `RouteLine.rawValue`.
    static func routeLine(_ line: String) -> String { "direction.line.\(line)" }

    /// 방향 선택. `direction` 은 `RouteDirection.rawValue`.
    static func direction(_ direction: String) -> String { "direction.\(direction)" }

    /// 시간표 유형 선택. `schedule` 은 `ScheduleType.accessibilityKey`.
    static func schedule(_ schedule: String) -> String { "schedule.\(schedule)" }
}
