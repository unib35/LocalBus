# 출시 전 검토 및 수정 기록


## 2026-09-18 코드 수정

R1–R8의 코드·문서 수정은 아래와 같습니다. 최초 검토와 재현 자료는 이 문서 아래에 이력으로 보존합니다. 공개 배포와 실기기 검증은 별도이며, 로컬 수정만으로 출시 승인을 의미하지 않습니다.

| 항목 | 수정 |
|---|---|
| R1–R3 개별 알림 | 출발 Date·방향·선행 분을 예약 ID에 포함. 한국 시간대의 연월일 트리거 사용. 지난 예약 시각과 다른 요일 조회 차단. OS 예약 완료 뒤에만 상태 변경. 권한 거부·실패·취소 안내 구분. 상세 시트의 낙관적 토글 제거. 재진입 시 pending 요청 재조회. 날짜 없는 구버전 개별 예약 제거 |
| R4 Live Activity | 문자열→오늘 날짜 조립과 앱 타이머 제거. 실제 출발 Date 사용. 잠금화면과 Dynamic Island에 날짜가 포함된 출발 예정·도착 예상 시각 표시. 도착 예상 시각에 staleDate 지정. 재실행 시 만료 활동 정리, 시작 시 시스템 활동 목록으로 중복 제거. 해당 편을 취소할 때만 대응 활동 종료 |
| R5 UI·접근성 | 큰 글자에서 방향·시간표 행·홈 정보 세로 배치. 공통 폰트의 Dynamic Type 적용, 주요 카운트다운 ScaledMetric 적용. 다크 보조 글자 대비 강화. 지난 행 전체 투명도 제거. 알림 접근성 이름에 시각·목적지 포함. 홈 카드 장식의 hit testing 제거 |
| R6 개인정보 | 한국어·영어 문서의 토큰·설치 식별자·서버 처리와 앱 구독 해제/OS 표시 차단 구분. 제보·문의 메일 수신 설명 정정. 비활성 기능 표시. 개발 로그에서 FCM 토큰 원문 제거 |
| R7 데이터 | 필수 4방향, 비어 있거나 중복·잘못 정렬된 시간표, 자정 꼬리편, 날짜, 요금·소요시간, 정류장·경로 좌표 검증. 앱/위젯 캐시 읽기와 쓰기 전 검증. 잘못된 캐시는 번들 복구. 원격 응답 2 MB/30초 제한. 게시 전 동일 Swift 검증기 추가 |
| R8 재현성 | Package.resolved 무시 규칙 제거 및 잠금 파일 포함. 비밀 설정 주입과 Release archive 절차 README 작성. 설정 검사 스크립트 추가 |
| 보류 결제 코드 | 상품 조회 실패에도 기존 구매 권한 조회. 구매 복원 오류를 삼키지 않고 표시. 개인정보 링크 수정. Pro 진입점은 계속 비활성 |

Live Activity는 **시간표 기반 예약 정보**를 표시합니다. 실시간 위치/출발 여부를 추정하거나 앱 종료 중 자동 단계 전환을 보장하지 않습니다. `staleDate`는 오래된 정보 표시 시점이며 시스템에서 활동을 즉시 삭제한다는 의미가 아닙니다. 설정 설명도 이에 맞췄습니다. [Apple ActivityContent](https://developer.apple.com/documentation/activitykit/activitycontent/staledate), [Firebase 데이터 처리](https://firebase.google.com/docs/ios/app-store-data-collection).

### 수정 후 검증

| 검증 | 결과 |
|---|---|
| 최종 iOS 단위 테스트 | 103개 / 14 suites 통과, `/tmp/localbus-fixes-verified-tests.log` |
| 기존 전체 UI 회귀 | 12개 모두 통과, `/tmp/localbus-fixes-all-tests.log` |
| 큰 글자 iPhone UI | 방향 변경 및 실제 출발 시각 화면 표시 통과, `/tmp/localbus-fixes-iphone-accessibility.log` |
| iPad 추가 UI | 가로 홈·설정 및 최대 글자 탐색 2개 통과. 가로 화면 최종 재검증도 통과(`/tmp/localbus-fixes-ipad-landscape-final.log`) |
| Foundation 핵심 회귀 | 31개 / 4 suites 통과, `/tmp/localbus-fixes-core.log` (iOS 테스트와 일부 중복) |
| 게시 전 시간표 검증기 | v5, 4방향, 공휴일 46개 통과 |
| 출시 설정 검사 | 통과. 설정 값 출력 없음, 의존성 14개 잠금 |
| 새 디렉터리 Release archive | 성공, `/tmp/localbus-fixed-release.xcarchive`. 최종 제품 소스 대조 일치, iPad 4방향 포함. 서명 비활성 |
| 최종 Release 로그 | `/tmp/localbus-fixes-final-archive.log`, 컴파일/방향 설정 경고 없음 |

증거: [수정 후 최대 글자 홈](../../artifacts/release-audit/2026-09-18/home-accessibility-xxxl.png), [최대 글자 iPad 시간표](../../artifacts/release-audit/2026-09-18/ipad-timetable-accessibility-xxxl.png). [iPad 가로 홈](../../artifacts/release-audit/2026-09-18/ipad-landscape-home.png), [iPad 가로 설정](../../artifacts/release-audit/2026-09-18/ipad-landscape-settings.png). 구버전의 날짜 없는 개별 출발 알림은 재설정해야 하며, 막차 반복 알림은 유지됩니다.

### 남은 배포·현장 확인

- 원격 시간표 v5 및 `docs/privacy-policy.html` 공개 게시와 게시 후 GET 확인. 현재 작업은 로컬이며 main/Pages에 게시하지 않았습니다.
- 운수사 기준 실제 운행 시각·요금·탑승홈 및 공휴일 운행 정책 확인. 검증기는 데이터 형식을 보장하며 실제 운행 변경 사실을 만들어내지 않습니다.
- 추가로 공식 터미널의 2026-09-14 공지를 확인했습니다. **2026-10-01부터 시외/고속 전 노선 요금 약 9% 인상 예정**입니다. 노선별 확정 금액은 공지에 없으므로 현재 요금에 임의로 9%를 곱해 적용하지 않았습니다. 10월 이후 출시/운영 시 정확한 장유·율하 요금 확인이 필요합니다. [부산서부버스터미널 공식 공지](https://www.busantr.com/waybbs/way_bbs.php?bo_table=way_notice&wr_id=407).
- 배포용 서명/프로비저닝, TestFlight 설치·업데이트, production APNs, 실기기 잠금/강제 종료·알림·Live Activity, iOS 16/26, 위젯 자정 갱신.
- App Store Connect 개인정보 답변을 실제 사용 SDK·메일 수신과 대조. 설정 파일과 코드만으로 콘솔 값을 변경하지 않았습니다.

## 2026-09-17 최초 검토 기록 — 수정 전 출시 보류

기준: 현재 미커밋 작업 트리, Xcode 26.5, iOS 18.6 전용 시뮬레이터, 실제 Release 기기 빌드. 제품 코드는 이번 검토에서 수정하지 않았습니다. P1은 출시 전에 고쳐야 할 기능 결함, P2는 사용자 영향이 있는 개선/운영 결함입니다. ‘실기기 재현 필요’는 확인된 코드 문제와 별도로 표시합니다.

## P1 — 출시 전에 수정

### R1. 출발 직전에 설정한 알림이 다음 날 울림

- 위치: [NotificationService.swift:37](/Users/lee/Developer/personal/LocalBus/LocalBusApp/LocalBusApp/Services/NotificationService.swift:37), [TimetableViews.swift:46](/Users/lee/Developer/personal/LocalBus/LocalBusApp/LocalBusApp/Views/Components/TimetableViews.swift:46).
- 날짜 없이 시·분만 지정한 단발 `UNCalendarNotificationTrigger`를 사용합니다. 06:18에 06:20 버스의 5분 전 알림을 켜면 이미 지난 06:15의 **다음 일치 시각**, 즉 다음 날에 예약됩니다. 지난 시간표 행과 다른 요일 시간표에서도 예약을 막지 않습니다.
- 재현: 실제 Apple `UNCalendarNotificationTrigger.nextTriggerDate()`를 사용하는 호스트 진단에서 ‘2분 뒤 출발, 5분 전 알림’이 **1436분 뒤**로 계산됐습니다. 알림을 실제 예약하거나 발송하지 않았습니다.
- 기기 시간대도 지정하지 않아 한국 외 시간대에서 한국 버스 시각과 다른 현지 시각에 예약될 수 있습니다.
- 수정: 공통 `TimetableTimeline.Departure.date`와 운행일을 예약에 전달하고, 예약 시각이 지났으면 즉시 안내하거나 설정을 거절합니다. 다른 요일 조회는 날짜를 선택해야 예약할 수 있도록 합니다.
- 완료 조건: 출발 2분 전/정각/직후, 23:50→00:10, 평일에 주말 시간표 조회, 기기 시간대 변경 테스트.

### R2. 같은 시각의 다른 노선 알림이 충돌함

- 위치: [NotificationService.swift:144](/Users/lee/Developer/personal/LocalBus/LocalBusApp/LocalBusApp/Services/NotificationService.swift:144), [MainViewModel.swift:489](/Users/lee/Developer/personal/LocalBus/LocalBusApp/LocalBusApp/ViewModels/MainViewModel.swift:489).
- 예약 ID와 화면의 예약 상태 키가 `bus_07:00_5` / `07:00_5`처럼 시간·선행 분만 포함합니다. 방향과 출발 날짜가 없습니다.
- 재현 절차: 장유→사상 07:00 알림을 켜고 사상→장유 07:00을 확인하면 후자도 켜진 상태로 취급합니다. 후자를 누르면 첫 노선의 알림이 취소됩니다.
- 수정: `노선 방향 + 실제 출발 날짜/시각 + 선행 분`을 예약·조회·취소에 동일하게 사용하고 기존 예약을 정리/이관합니다.
- 완료 조건: 같은 시각의 두 방향을 독립 예약·취소, 오늘/내일의 같은 시각을 독립 관리.

### R3. OS 예약 실패를 성공으로 표시함

- 위치: [NotificationService.swift:59](/Users/lee/Developer/personal/LocalBus/LocalBusApp/LocalBusApp/Services/NotificationService.swift:59), [MainViewModel.swift:500](/Users/lee/Developer/personal/LocalBus/LocalBusApp/LocalBusApp/ViewModels/MainViewModel.swift:500).
- 개별 버스 알림은 `add(request)` 완료/오류를 받지 않습니다. 호출 직후 화면 상태에 키를 삽입해 ‘알림이 켜졌습니다’를 표시합니다. 설정 페이지의 막차 알림은 `try await add`를 쓰지만 개별 알림에는 적용되지 않았습니다.
- 영향: OS가 예약을 거절하거나 잘못된 시각이 전달돼도 성공 안내가 나옵니다. 최초 권한 요청을 거부한 경우에도 호출부가 상태만 읽어 ‘알림이 꺼졌습니다’로 표시하는 경로가 있습니다.
- 수정: 예약 API를 `async throws`로 만들고 성공 뒤에만 화면 상태와 Live Activity를 갱신합니다. 권한 거부·예약 실패·사용자 취소를 다른 결과로 반환합니다.
- 완료 조건: 예약 서비스 오류 주입, 최초 권한 거부, 재진입 시 실제 pending request와 화면 상태 일치.

### R4. 잠금화면 카운트다운의 출발·도착 전환이 앱 실행에 의존함

- 위치: [LiveActivityService.swift:87](/Users/lee/Developer/personal/LocalBus/LocalBusApp/LocalBusApp/Services/LiveActivityService.swift:87), [BusLiveActivityView.swift:27](/Users/lee/Developer/personal/LocalBus/LocalBusApp/LocalBusWidget/BusLiveActivityView.swift:27).
- 출발 시 `phase` 갱신과 도착 시 종료를 `Timer.scheduledTimer`가 담당합니다. 앱이 정지/종료되면 이를 실행할 보장이 없습니다. `pushType: nil`, `staleDate: nil`이며 표시도 저장된 `phase`에 의존합니다.
- 예상 증상: 화면을 잠그고 기다리면 출발 후에도 ‘출발까지’와 0 카운트다운이 남거나 도착 후 종료되지 않을 수 있습니다. 코드로 확인된 설계 결함이며 잠금/강제 종료 시나리오의 실기기 검증은 남아 있습니다.
- 별도 경계 오류: 23:55에 00:10 버스 알림을 켜도 `DateService.minutesUntil`이 음수를 반환해 Live Activity가 시작되지 않습니다. 시작 서비스 역시 문자열을 ‘오늘’ 날짜로 조립합니다.
- 수정: 실제 출발·도착 Date를 공유하고, 앱 실행 없이도 오해하지 않는 표시/만료 정책을 정합니다. 단계 전환이 필요하면 지원되는 백그라운드 실행 또는 ActivityKit 푸시 설계가 필요합니다. 재실행 시 기존 활동도 복구/정리해야 합니다.
- 완료 조건: 출발 전 잠금, 앱 강제 종료, 출발/도착 경과, 자정 편, 앱 재시작과 중복 활동 확인.
- 근거: [Apple Live Activities 문서](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities), [ActivityKit 푸시 갱신](https://developer.apple.com/documentation/ActivityKit/starting-and-updating-live-activities-with-activitykit-push-notifications).

## P2 — UI·데이터·운영 개선

### R5. 큰 글자 설정에서 방향 선택 레이아웃이 무너지고 핵심 정보는 확대되지 않음

- 위치: [DirectionSelector.swift:23](/Users/lee/Developer/personal/LocalBus/LocalBusApp/LocalBusApp/Views/Components/DirectionSelector.swift:23), [DesignSystem.swift:177](/Users/lee/Developer/personal/LocalBus/LocalBusApp/LocalBusApp/Utilities/DesignSystem.swift:177).
- iPhone 16 / iOS 18.6에서 `accessibility-extra-extra-extra-large`로 직접 재현했습니다. ‘방향 변경’이 글자 단위로 세로로 쌓이고 헤더가 화면의 큰 부분을 차지합니다. 반면 고정 크기 폰트를 사용하는 출발·도착 시간과 보조 설명은 확대되지 않습니다.
- 증거: [최대 글자 크기 홈 화면](../../artifacts/release-audit/2026-09-17/home-accessibility-xxxl.png). 검증 후 시뮬레이터 글자 크기는 원래 `large`로 복구했습니다.
- 추가 대비 문제: [TimetableViews.swift:298](/Users/lee/Developer/personal/LocalBus/LocalBusApp/LocalBusApp/Views/Components/TimetableViews.swift:298)의 과거 행 전체 `opacity(0.4)`가 여전히 작동하는 알림 버튼까지 흐리게 만듭니다. 기본 다크 보조색 `#555555`도 작은 글자/아이콘에는 낮은 대비입니다.
- 수정: 큰 글자에서 방향 영역을 세로 배치하고 semantic font 또는 `@ScaledMetric`을 사용합니다. 지난 시각 표시와 활성 버튼의 대비를 분리합니다. 반복되는 알림 버튼 접근성 이름에 출발 시각·방향을 포함합니다.
- 완료 조건: 일반/최대 글자, 밝게/어둡게, 대비 증가, 작은 iPhone/iPad, VoiceOver로 시간표 탐색.
- 근거: [Apple Typography 지침](https://developer.apple.com/design/human-interface-guidelines/typography).

### R6. 공개 개인정보 설명이 실제 처리와 모순됨

- 위치: [privacy-policy.html:293](/Users/lee/Developer/personal/LocalBus/docs/privacy-policy.html:293), [privacy-policy.html:324](/Users/lee/Developer/personal/LocalBus/docs/privacy-policy.html:324), [AppDelegate.swift:16](/Users/lee/Developer/personal/LocalBus/LocalBusApp/LocalBusApp/Services/AppDelegate.swift:16).
- 공개 페이지는 토큰을 ‘기기에만 저장’한다고 설명하면서 다른 항목에서는 Google 서버 처리를 설명합니다. iOS 알림을 끄면 토픽 구독도 해제된다고 쓰지만, 코드에서 OS 권한 철회 시 구독 해제를 수행하지 않습니다. OS 알림 차단과 FCM 구독 해제는 다른 상태입니다.
- Firebase는 앱 시작 시 구성되고, 알림 토글과 별개로 기본 자동 초기화 경로가 있습니다. Firebase 공식 문서도 APNs 토큰·설치 식별자 처리를 안내합니다.
- 수정: 실제 SDK 처리, 앱 구독 해제와 OS 표시 차단의 차이, 이메일 제보/문의로 수신하는 정보와 처리 방식을 일관되게 설명합니다. ‘익명’ 또는 ‘개인정보가 아님’을 단정하기보다 항목·목적·처리 주체를 명시합니다.
- 앱의 수집 목록이 빈 PrivacyInfo만 보고 ‘수집 없음’ 오류라고 단정하지 않았습니다. Release 번들에는 Firebase 등 SDK별 privacy manifest도 포함돼 있습니다. App Store Connect의 실제 개인정보 답변은 접근하지 않아 별도 확인이 필요합니다.
- 근거: [Firebase 데이터 공개 안내](https://firebase.google.com/docs/ios/app-store-data-collection), [FCM 자동 초기화 안내](https://firebase.google.com/docs/cloud-messaging/ios/get-started), [현재 공개 방침](https://unib35.github.io/LocalBus/privacy-policy.html). 문구·구현 정합성 검토이며 법적 적합성에 대한 확정 판정은 아닙니다.

### R7. 디코딩 가능한 잘못된 원격 시간표가 정상 캐시를 대체할 수 있음

- 위치: [TimetableData.swift:176](/Users/lee/Developer/personal/LocalBus/LocalBusApp/LocalBusApp/Models/TimetableData.swift:176), [MainViewModel.swift:709](/Users/lee/Developer/personal/LocalBus/LocalBusApp/LocalBusApp/ViewModels/MainViewModel.swift:709).
- 업데이트 검사는 버전·날짜·내용 차이만 비교합니다. 필수 노선 존재, 빈 시간표, 중복 시각, 반복 자정 넘김, 음수 요금/소요시간, 경로 좌표 범위를 적용 전에 검증하지 않습니다.
- 예: 상위 버전에 `routes: {}`를 게시하면 JSON 디코딩과 업데이트 비교를 통과해 정상 캐시를 대체할 수 있습니다. 상위 캐시는 다음 실행에서도 번들보다 우선합니다.
- 수정: 도메인 검증을 통과한 데이터만 적용하고 마지막 정상본을 유지합니다. 버전별 스키마와 배포 전 검증을 추가합니다. 원격 운영 실수에 대한 회복력 문제이며 현재 공개 데이터가 악성이라는 의미는 아닙니다.
- 완료 조건: 빈/누락 노선·비정상 시각·좌표·과대 응답·네트워크 실패를 주입해 정상 데이터가 유지되는지 확인.

### R8. 새 환경에서 동일한 출시 빌드를 재현하기 어려움

- 위치: [.gitignore:17](/Users/lee/Developer/personal/LocalBus/.gitignore:17), [project.pbxproj:606](/Users/lee/Developer/personal/LocalBus/LocalBusApp/LocalBusApp.xcodeproj/project.pbxproj:606), [README.md](/Users/lee/Developer/personal/LocalBus/README.md).
- `Package.resolved`가 무시되고 Firebase/Kingfisher는 버전 범위를 사용합니다. 오늘 검증한 의존성과 다음 배포에서 선택되는 의존성이 달라질 수 있습니다.
- 프로젝트가 참조하는 `Secrets.xcconfig`와 시작 시 필요한 Firebase 설정은 로컬 전용인데 README에는 환경 구성 절차가 없습니다. 현재 기기 빌드 성공이 새 머신/CI에서의 성공을 보장하지 않습니다.
- 수정: 앱 프로젝트의 의존성 잠금 파일을 관리하고, 비밀값을 저장소에 넣지 않는 CI 주입 절차와 필수 설정 존재 검사, Release 빌드 절차를 문서화합니다.
- 완료 조건: 새 체크아웃에 승인된 설정만 주입해 같은 의존성으로 Release archive 생성.

## 별도 출시 게이트

1. **방향 변경 여백 터치 미해결**: 2026-09-17 현재 빌드에서도 `test_홈_방향글자와_변경버튼여백으로_왕복전환`의 마지막 선택 상태 검증이 실패했습니다(18.289초). 글자 탭 후 반대 방향 선택까지는 통과하고 오른쪽 95%/세로 50% 좌표 탭 후 복귀하지 않습니다. 버튼 영역 문제인지 좌표 입력/테스트 문제인지 원인을 확정해야 합니다. 실패를 통과 처리하거나 테스트를 삭제하면 안 됩니다.
2. **원격 데이터 배포 불일치**: 실제 URL GET 결과는 v3 / 2026-03-08 / 공휴일 14개입니다. Release 앱과 위젯 번들은 v5 / 46개입니다. 신버전은 버전 비교로 강등을 방지하지만 기존 설치본에는 수정 데이터가 전달되지 않습니다. 원격 게시와 게시 후 검증이 필요하며 이번 검토에서는 게시하지 않았습니다.
3. **운수사 기준 실데이터**: 4개 방향·19개 정류장 데이터 구조/좌표 범위/시각 중복은 검사했습니다. 실제 최신 운행 시각·요금·탑승홈·공휴일 운행 규칙이 운수사 자료와 일치하는지는 별도 확인해야 합니다. 공휴일 날짜 계산 통과가 운수사 운행 정책 검증을 대신하지 않습니다.
4. **실기기·스토어**: 서명된 archive, TestFlight 설치/업데이트, APNs production 수신, 잠금/종료 상태 알림과 Live Activity, iOS 16 최소 지원·iOS 26 최신 UI, 실제 위젯 설치/자정 갱신, 위치 거부/철회, 메일·공유 완료를 확인해야 합니다. 현재 테스트 타깃 최소 버전은 18.5이므로 16.x 검증 공백이 있습니다.
5. **보류 기능 범위**: Pro 진입점은 숨김, 위젯은 무료, 교통 API 키는 실제 Release에 없음. 미검증 결제/실시간 교통을 출시 설명에 포함하면 안 됩니다. 유료화 활성화 전에는 상품 조회 실패와 구매 권한 복구, 복원 오류 표시도 다시 검토해야 합니다.

## 이번 검증 결과

| 항목 | 결과 | 범위/한계 |
|---|---|---|
| Release / generic iOS 빌드 | 성공 | 서명 비활성. archive 배포 적합성/프로비저닝은 미검증 |
| iOS 단위 테스트 | 92개 / 12 suites 통과 | 현재 코드로 재실행. 알림 예약·백그라운드 생명주기 실검증은 포함하지 않음 |
| Foundation 핵심 회귀 테스트 | 31개 / 4 suites 통과 | 날짜·시간표·공휴일·버전 비교. iOS 테스트와 일부 중복됨 |
| 출발 직전 알림 트리거 | 오류 재현 | 출발 2분 전 예약 → 약 24시간 뒤 실행 시각. 실제 알림 발송 없음 |
| 최대 글자 크기 UI | 문제 재현 | iPhone 16 / iOS 18.6 / 라이트. 스크린샷 첨부 |
| 선택 UI 회귀 테스트 | 2개 중 1개 통과·1개 실패 | 설정 및 하위 4개 페이지 통과, 방향 변경 여백 왕복 전환 실패. 전체 UI suite 통과를 의미하지 않음 |
| 번들 데이터 | 구조 검사 통과 | 4개 방향, 19개 정류장, 앱·위젯 v5 일치 |
| 공개 약관·개인정보 URL | 모두 HTTP 200 | 문서 내용의 정합성 문제는 R6 |
| 원격 JSON | HTTP 200, v3 | 번들과 배포 버전 불일치 |
| Release 비밀값 점검 | 로컬 Kakao 키 원문 미포함 | Info.plist 키도 없음. 값 자체는 출력/문서화하지 않음 |
| 추적 소스 비밀 패턴 검사 | 일치 없음 | private key/GitHub token/AWS access key/service-account key 패턴. 전체 Git 이력·모든 비밀 유형을 보증하지 않음 |
| 네트워크·딥링크 | 기본 방어 확인 | 확인한 운영 URL은 HTTPS, ATS 완화 없음, 딥링크는 스킴/호스트/방향 enum 검증. 침투 테스트를 수행했다는 의미는 아님 |
| 개인정보 manifest | 앱·위젯·의존 SDK 포함 확인 | App Store Connect 답변/최종 집계 리포트는 별도 확인 |

로그: `/tmp/localbus-release-audit-build.log`, `/tmp/localbus-release-audit-unit.log`, `/tmp/localbus-release-audit-core.log`, `/tmp/localbus-release-audit-ui.log`. 로그에는 개발용 SDK 출력이 있을 수 있으므로 원문을 외부 공유하기 전에 토큰을 제거해야 합니다.

## 권장 수정 순서

1. 개별 알림을 `실제 출발 Date + 방향` 기준으로 통일하고 성공/실패를 UI에 반영(R1–R3).
2. Live Activity 수명주기·자정 경계를 바로잡고 실기기 잠금/종료 검증(R4).
3. 방향 변경 터치 원인을 확정하고 큰 글자·대비·VoiceOver를 개선(R5 및 터치 게이트).
4. 원격 데이터 검증/게시, 개인정보 설명, 의존성 고정과 새 환경 빌드를 정리(R6–R8).
5. 서명 archive→TestFlight에서 위젯·푸시·위치·오프라인·업데이트 경로를 확인한 뒤 출시 승인.
