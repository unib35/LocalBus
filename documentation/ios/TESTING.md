# 테스트 실행

## 시뮬레이터 없는 핵심 회귀 테스트

```sh
python3 scripts/run_core_tests.py
```

설치된 Xcode의 Swift/Swift Testing을 사용합니다. 외부 패키지는 다운로드하지 않습니다.
실제 DateService, TimetableTimeline, TimetableData, TimetableRevision 소스와 기존 테스트를 임시 Swift Package에 그대로 복사해 실행하고 종료 시 임시 파일을 정리합니다.

대상: 날짜 계산, JSON 해석, 자정/운행일 경계, 배포 공휴일 데이터(2026~2027년).
MainViewModel·알림·캐시·UIKit·UI 테스트는 iOS 테스트에서 검증합니다.

## iOS 테스트

테스트 시작 전에 기기를 부팅하고 완료를 확인합니다. 첫 부팅 마이그레이션에 수 분이 걸릴 수 있으므로 전체 테스트를 3분 제한으로 중단하지 않습니다.

```sh
xcrun simctl list devices available
# 목록에서 사용할 전용 기기 ID를 지정
LOCALBUS_TEST_DEVICE="기기-UUID"
xcrun simctl boot "$LOCALBUS_TEST_DEVICE"
xcrun simctl bootstatus "$LOCALBUS_TEST_DEVICE" -b
xcodebuild test -project LocalBusApp/LocalBusApp.xcodeproj -scheme LocalBusApp \
  -destination "platform=iOS Simulator,id=$LOCALBUS_TEST_DEVICE" \
  -parallel-testing-enabled NO -only-testing:JangyuBusTests CODE_SIGNING_ALLOWED=NO
```

이미 부팅된 기기에는 boot 명령을 생략합니다. UI 검증은 only-testing 대상을 JangyuBusUITests로 바꿉니다.
시뮬레이터에 Simulator 앱 창을 열어 화면 초기화를 확인할 수 있습니다. 다른 프로젝트의 기기/서비스를 일괄 종료하거나 삭제하지 않습니다.

## 2026-09-16 점검

- CoreSimulator 전체 재시작 없이 새 iOS 18.6 기기가 부팅됨(4분 32초).
- iOS 26.5 기기는 BackBoard 단계에서 지연됐고, 새 18.6 기기도 데이터 마이그레이션·System App 초기화를 거침.
- 기존 180초 제한은 첫 부팅을 완료하기에 부족했음. Mach -308 오류를 앱 코드 오류로 단정할 수 없음.
- 핵심 회귀 테스트: 31개 / 4개 suite 통과.
- iOS 18.6 전용 시뮬레이터: 단위 테스트 92개 / 12개 suite 통과.
  설정 업데이트 상태, 캐시 버전 우선순위, MainViewModel 운행일 경계를 포함합니다.
  첫 실행은 빌드·설치 준비를 포함해 약 5분 걸렸으며, 실제 테스트 실행은 0.784초였습니다.
- UI 테스트 첫 전체 실행: 12개 중 10개 통과, 2개 실패.
  - 탭 전환: 실패 시 접근성 계층에는 탭 이름이 있었지만 식별자가 누락되어 있었음.
    공통 탐색 헬퍼가 탭 바 안에서 식별자 또는 이름을 찾도록 수정한 뒤 통과.
  - 방향 글자 탭은 통과하지만 변경 버튼 오른쪽 여백(`x = 95%, y = 50%`)의 좌표 탭 후 왕복 전환 검증은 반복 실패. 원인 미확정이며 완료로 처리하지 않음.
  - 일반 방향 전환, 노선 전환, 정류장 탭/홈 복귀, 시간표 목록/요일 전환, 앱 실행, 설정 및 하위 4개 페이지 진입은 통과.
- UI 재검증에서 탭 전환·일반 방향 전환·설정 하위 페이지는 통과. 여백 터치 실패는 남아 있으며, 전체 UI suite 통과 결과는 아직 없음.

## 2026-09-18 출시 결함 수정 검증

- 알림 Date/한국 시간대/지난 예약/방향·날짜별 ID/권한 거부·예약 실패·양방향 독립 취소, 원격 도메인 검증·정상 캐시 보존·과대 응답 거절을 회귀 테스트에 추가했습니다.
- 기존 전체 UI 12개가 통과했습니다. 오른쪽 95% 여백 터치 테스트를 삭제하거나 좌표를 중앙으로 바꾸지 않았습니다.
- 최대 Dynamic Type에서는 메뉴도 스크롤되도록 하며, 실제 출발 시각의 화면 내 표시를 추가 검증합니다.
- iPadOS 18 상단 탭은 tabBar 외부 버튼 또는 레이블로 노출되어 테스트 헬퍼가 해당 접근성 구조도 탐색합니다. 가로 회전 홈/설정 검증을 추가했습니다.
- 단위 테스트의 최신 결과와 추가 UI 실행 결과는 [출시 검토](../releases/RELEASE_REVIEW.md)의 2026-09-18 결과를 기준으로 합니다.
- 새 빌드 디렉터리에서 잠금된 의존성으로 서명 없는 Release archive를 생성했습니다. 배포 서명 및 실기기 APNs 검증은 별도입니다.
