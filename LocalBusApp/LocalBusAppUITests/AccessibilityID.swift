import Foundation

/// 앱 타깃 `Utilities/AccessibilityIdentifiers.swift` 의 미러.
///
/// UI 테스트는 앱과 별도 프로세스에서 돌기 때문에 앱 모듈을 import할 수 없다.
/// 그래서 같은 문자열을 이쪽에 복제해 둔다. 한쪽을 고치면 반드시 다른 쪽도 고칠 것.
enum AccessibilityID {

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

        static let heroLoading = "home.hero.loading"
        static let heroNextBus = "home.hero.nextBus"
        static let heroServiceEnded = "home.hero.serviceEnded"
        static let heroUnavailable = "home.hero.unavailable"
    }

    enum Timetable {
        static let root = "timetable.root"
        static let scheduleSegment = "timetable.scheduleSegment"
        static let list = "timetable.list"

        static func row(_ time: String) -> String { "timetable.row.\(time)" }
    }

    enum Settings {
        static let root = "settings.root"
    }

    static func routeLine(_ line: String) -> String { "direction.line.\(line)" }
    static func direction(_ direction: String) -> String { "direction.\(direction)" }
    static func schedule(_ schedule: String) -> String { "schedule.\(schedule)" }
}

/// 앱의 `RouteLine` / `RouteDirection` / `ScheduleType` rawValue 미러.
enum AppFixture {
    enum Line {
        static let jangyu = "jangyu"
        static let yulha = "yulha"
    }

    enum Direction {
        static let jangyuToSasang = "jangyu_to_sasang"
        static let sasangToJangyu = "sasang_to_jangyu"
        static let yulhaToSasang = "yulha_to_sasang"
        static let sasangToYulha = "sasang_to_yulha"
    }

    enum Schedule {
        static let weekday = "weekday"
        static let weekend = "weekend"
    }
}
