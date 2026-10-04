import Foundation

/// Xcode Canvas에서만 외부 서비스와 사용자 저장 상태를 사용하지 않습니다.
enum PreviewRuntime {
    static let defaults = UserDefaults(suiteName: "kr.co.lee.jangyusasang.preview") ?? .standard

    static var isRunning: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        #else
        false
        #endif
    }
}
