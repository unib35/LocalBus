import Foundation
@testable import JangyuBus

/// 유닛 테스트를 앱의 영속 상태로부터 격리한다.
///
/// `MainViewModel.init()` 은 `UserDefaults` 에서 `selectedDirection` 을 복원한다.
/// 유닛 테스트는 앱 프로세스·앱 컨테이너 안에서 실행되므로, 앞서 그 시뮬레이터에서
/// 앱을 쓴 흔적(특히 노선을 바꾸는 UI 테스트)이 그대로 흘러들어온다.
///
/// 실제로 UI 테스트가 율하 노선을 탭해 `"yulha_to_sasang"` 을 저장한 뒤부터,
/// `routes` 에 `jangyu_to_sasang` 만 넣는 픽스처가 매칭에 실패해
/// `currentTimes` 가 비고 심야 관련 테스트 5개가 무너졌다.
enum TestEnvironment {

    /// `MainViewModel` 이 복원 대상으로 삼는 UserDefaults 키.
    private static let persistedKeys = ["selectedDirection"]

    /// 앱이 남긴 영속 상태를 지운다. ViewModel 을 만들기 전에 호출할 것.
    static func reset() {
        let defaults = UserDefaults.standard
        for key in persistedKeys {
            defaults.removeObject(forKey: key)
        }
    }
}
