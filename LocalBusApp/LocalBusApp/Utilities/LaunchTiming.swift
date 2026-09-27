import Foundation

/// 스플래시 종료 타이밍 규칙.
/// 시간표가 준비되면 바로 닫되 최소 노출 시간은 지키고, 준비가 늦어도 최대 시간을 넘기지 않는다.
enum LaunchTiming {
    /// 스플래시 최소 노출 시간 (초). 이보다 빨리 닫히면 깜빡임처럼 보인다.
    static let minimumDuration: TimeInterval = 0.6
    /// 스플래시 최대 노출 시간 (초). 이 뒤에는 데이터와 무관하게 홈으로 넘어간다.
    static let maximumDuration: TimeInterval = 1.5

    /// 시간표가 `elapsed`초 시점에 준비됐을 때, 지금부터 얼마나 더 기다렸다가 닫을지.
    static func dismissDelay(loadedAfter elapsed: TimeInterval) -> TimeInterval {
        max(0, minimumDuration - elapsed)
    }
}
