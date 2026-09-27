import Testing
import Foundation
@testable import JangyuBus

struct LaunchTimingTests {

    @Test func 데이터가_최소시간_전에_준비되면_남은_최소시간만큼_기다린다() {
        let delay = LaunchTiming.dismissDelay(loadedAfter: 0.2)
        #expect(abs(delay - 0.4) < 0.0001)
    }

    @Test func 데이터가_최소시간_후에_준비되면_바로_닫는다() {
        #expect(LaunchTiming.dismissDelay(loadedAfter: 0.9) == 0)
        #expect(LaunchTiming.dismissDelay(loadedAfter: LaunchTiming.minimumDuration) == 0)
    }

    @Test func 최대시간은_최소시간보다_길다() {
        #expect(LaunchTiming.maximumDuration > LaunchTiming.minimumDuration)
    }
}
