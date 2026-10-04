# LocalBus

장유·율하 ↔ 부산 사상 시외버스 iOS 앱. 현재 구성은 무료 위젯을 포함하며 Pro 구매와 실시간 교통 API는 제공하지 않습니다.

## 저장소 구조

작업 기준 폴더는 `/Users/lee/Developer/personal/LocalBus`입니다.

| 경로 | 역할 |
|---|---|
| `LocalBusApp/` | iOS 앱·위젯·Xcode 프로젝트·iOS 테스트 |
| `server/` | 도착예상 데이터 수집기·계약·설정·테스트 |
| `admin/` | 향후 관리자 웹 작업 공간 (현재 문서만 있음) |
| `documentation/` | 개발·출시 문서와 폴더 정리 기록 |
| `docs/` | GitHub Pages 공개 홈페이지·약관 |
| `scripts/`, `CoreTests/` | 저장소 검증 스크립트·독립 Swift 회귀 테스트 |
| `artifacts/release-audit/` | 출시 검증 이미지·재현 자료 |
| `internal-docs/` | 기존 로컬 내부 문서 (Git 제외) |
| `archives/` | 기존 앱 ZIP·충돌한 Orca 앱 변경의 복원 자료 (Git 제외) |

서버 작업은 [서버 실행 안내](server/README.md)와 [도착예상 구현 계획](server/implementation-plan.md)에서 시작합니다.
설계는 차량 실시간 추적이 아닌 주간 수집 기반 예상값입니다. 현재 앱에는 서버 연동을 적용하지 않았습니다.
정리 내역과 앱 변경 복원 위치는 [작업 기록](documentation/repository-organization.md)을 참고하세요.

## 개발 환경

검증 환경은 Xcode 26.5, iOS 18.6 Simulator입니다. 앱은 iOS 16.0, 위젯은 iOS 17.0 이상을 지원합니다. 저장소의 `LocalBusApp/LocalBusApp.xcodeproj`를 열고 `LocalBusApp` scheme을 선택합니다.

1. `LocalBusApp/Configurations/Secrets.xcconfig`를 만듭니다. 현재 출시 구성에서는 `KAKAO_REST_API_KEY =`처럼 빈 값으로 둡니다. 실제 키를 앱 번들에 주입하지 않습니다.
2. 승인된 Firebase 프로젝트에서 iOS 앱 `kr.co.lee.jangyusasang`의 `GoogleService-Info.plist`를 받아 `LocalBusApp/LocalBusApp/GoogleService-Info.plist`에 둡니다. CI에서는 접근 제한된 파일 secret을 이 경로에 주입하고 값을 로그에 출력하지 않습니다. 이 두 파일은 Git에서 제외됩니다.
3. `python3 scripts/check_release_config.py`로 설정을 검사합니다.
4. 프로젝트의 `project.xcworkspace/xcshareddata/swiftpm/Package.resolved`를 사용해 패키지를 복원합니다. 잠금 파일은 버전 관리 대상입니다. 의존성 갱신 시 변경된 버전과 테스트 결과를 함께 검토합니다.

```sh
xcodebuild -resolvePackageDependencies -project LocalBusApp/LocalBusApp.xcodeproj -scheme LocalBusApp -onlyUsePackageVersionsFromResolvedFile
xcodebuild build -project LocalBusApp/LocalBusApp.xcodeproj -scheme LocalBusApp -configuration Release -destination 'generic/platform=iOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO
```

서명 없는 빌드는 컴파일 검증입니다. 배포 담당자는 승인된 Team/프로비저닝을 구성한 뒤 아래 archive를 생성하고 Organizer에서 검증·배포합니다. 자동 서명 자격 증명이나 인증서를 저장소에 추가하지 않습니다.

```sh
xcodebuild archive -project LocalBusApp/LocalBusApp.xcodeproj -scheme LocalBusApp -configuration Release -destination 'generic/platform=iOS' -archivePath /tmp/LocalBus.xcarchive -disableAutomaticPackageResolution
```

## 테스트와 배포

[테스트](documentation/ios/TESTING.md), [미리보기](documentation/ios/PREVIEWS.md), [출시 검토](documentation/releases/RELEASE_REVIEW.md)를 참고합니다. 새 체크아웃에서도 승인된 설정을 주입하고 Release archive를 검증해야 합니다. 최소 지원 OS, 실기기 APNs/Live Activity, TestFlight 설치 확인은 시뮬레이터 테스트와 별도입니다.

원격 시간표는 `main` 브랜치의 `LocalBusApp/LocalBusApp/Resources/timetable.json`을 읽습니다. 번들·원격 자료를 같은 변경으로 검토하고 버전과 날짜를 올립니다. 필수 4방향, 시각·공휴일·요금·좌표 검증을 통과해야 앱과 위젯이 적용합니다. 응답 상한은 2 MB입니다. 실제 운행 정보는 운수사 자료로 확인한 뒤 게시합니다.

개인정보 문서 원본은 `docs/privacy-policy.html`입니다. 로컬 수정만으로 공개 GitHub Pages나 원격 시간표가 바뀌지 않습니다. 공개 배포 후 실제 URL의 문서와 JSON 버전을 다시 확인합니다.

게시 전 앱과 동일한 Swift 검증기를 실행합니다.

```sh
swiftc LocalBusApp/LocalBusApp/Models/TimetableRevision.swift LocalBusApp/LocalBusApp/Models/TimetableData.swift scripts/validate_timetable.swift -o /tmp/localbus-validate-timetable
/tmp/localbus-validate-timetable LocalBusApp/LocalBusApp/Resources/timetable.json
```

## 이번 업데이트의 알림 이관

구버전의 개별 출발 알림은 날짜·방향이 예약 ID에 없어 안전하게 이관할 수 없습니다. 앱이 해당 구버전 예약을 제거하므로 사용자는 출발 알림을 다시 설정해야 합니다. 막차 반복 알림은 별도로 유지됩니다. 배포 시 업데이트 안내에 재설정 필요를 포함하세요.
