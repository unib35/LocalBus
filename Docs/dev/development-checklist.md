# LocalBus 개발 체크리스트

> 이 문서는 LocalBus MVP 개발에 필요한 모든 기능, 화면, 컴포넌트를 체계적으로 정리한 체크리스트입니다.
>
> **범례**: ✅ 완료 | 🚧 진행중 | ⬜ 미착수

---

## 목차

1. [프로젝트 설정](#1-프로젝트-설정)
2. [데이터 모델](#2-데이터-모델)
3. [핵심 서비스](#3-핵심-서비스)
4. [화면 (Views)](#4-화면-views)
5. [컴포넌트](#5-컴포넌트)
6. [테스트](#6-테스트)
7. [배포 준비](#7-배포-준비)

---

## 1. 프로젝트 설정

### 1.1 Xcode 프로젝트

| 항목                       | 상태 | 비고                          |
| -------------------------- | ---- | ----------------------------- |
| Xcode 프로젝트 생성        | ✅   | LocalBusApp                   |
| SwiftUI App 구조 설정      | ✅   | @main App                     |
| 최소 iOS 버전 설정         | ✅   | iOS 17.0+                     |
| Bundle Identifier 설정     | ⬜   | com.localbus.app              |
| App Icon 설정              | ⬜   | Assets.xcassets               |
| Launch Screen 설정         | ✅   | LaunchScreenView.swift        |

### 1.2 프로젝트 구조

| 항목                    | 상태 | 비고                                 |
| ----------------------- | ---- | ------------------------------------ |
| Models 폴더             | ✅   | TimetableData.swift                  |
| Views 폴더              | ✅   | MainView, InfoView, LaunchScreen     |
| ViewModels 폴더         | ✅   | MainViewModel.swift                  |
| Services 폴더           | ✅   | Timetable, Date, Network, Notification |
| Utilities 폴더          | ✅   | 헬퍼 함수, 확장                      |
| Resources 폴더          | ✅   | timetable.json                       |

### 1.3 의존성

| 항목                    | 상태 | 비고                                 |
| ----------------------- | ---- | ------------------------------------ |
| Swift Package Manager   | ✅   | 의존성 관리                          |
| (선택) Alamofire        | ✅   | URLSession 사용으로 대체             |

---

## 2. 데이터 모델

### 2.1 핵심 모델 (Models)

| 모델                    | 상태 | 비고                                 |
| ----------------------- | ---- | ------------------------------------ |
| `TimetableData`         | ✅   | 전체 JSON 구조                       |
| `Meta`                  | ✅   | 버전, 업데이트 날짜, 공지, 연락처    |
| `Timetable`             | ✅   | 평일/주말 시간표 배열                |
| `RouteData`             | ✅   | 노선별 시간표 (양방향 지원)          |
| `RouteDirection`        | ✅   | 노선 방향 Enum                       |
| `BusStop`               | ✅   | 정류장 정보                          |

### 2.2 JSON 스키마 (PRD 기준)

```json
{
  "meta": {
    "version": 1,
    "updated_at": "2026-01-10",
    "notice_message": "도로 공사로 인해 5분 정도 지연될 수 있습니다.",
    "contact_email": "help@localbus.com"
  },
  "holidays": ["2026-02-09", "2026-02-10"],
  "timetable": {
    "weekday": ["06:00", "06:20", "06:40"],
    "weekend": ["06:30", "07:00", "07:30"]
  }
}
```

---

## 3. 핵심 서비스

### 3.1 데이터 서비스

| 서비스                     | 상태 | 비고                                 |
| -------------------------- | ---- | ------------------------------------ |
| `TimetableService`         | ✅   | 시간표 데이터 관리 총괄              |
| ├─ `fetchRemoteData()`     | ✅   | MainViewModel에서 NetworkService 사용 |
| ├─ `loadLocalData()`       | ✅   | 번들 내 기본 JSON 로드               |
| ├─ `loadCachedData()`      | ✅   | UserDefaults 캐시 로드               |
| └─ `saveToCache()`         | ✅   | 성공 데이터 로컬 저장                |

### 3.2 날짜/시간 서비스

| 서비스                         | 상태 | 비고                             |
| ------------------------------ | ---- | -------------------------------- |
| `DateService`                  | ✅   | 날짜/시간 판단 로직              |
| ├─ `isWeekday()`               | ✅   | 평일 여부 (월~금)                |
| ├─ `isHoliday(date:holidays:)` | ✅   | 공휴일 목록과 비교               |
| ├─ `shouldUseWeekdaySchedule()`| ✅   | 평일 && !공휴일 → true           |
| ├─ `findNextBus(times:from:)`  | ✅   | 현재 시간 이후 가장 가까운 버스  |
| ├─ `minutesUntil()`            | ✅   | 특정 시간까지 남은 분            |
| └─ `secondsUntil()`            | ✅   | 특정 시간까지 남은 초            |

### 3.3 네트워크 서비스

| 서비스                     | 상태 | 비고                                 |
| -------------------------- | ---- | ------------------------------------ |
| `NetworkService`           | ✅   | HTTP 요청 처리                       |
| └─ `fetch<T>(url:)`        | ✅   | Generic JSON 디코딩                  |

### 3.4 알림 서비스

| 서비스                     | 상태 | 비고                                 |
| -------------------------- | ---- | ------------------------------------ |
| `NotificationService`      | ✅   | 로컬 푸시 알림 관리                  |
| ├─ `requestAuthorization()`| ✅   | 알림 권한 요청                       |
| ├─ `scheduleBusNotification()` | ✅ | 버스 출발 전 알림 예약             |
| └─ `cancelNotification()`  | ✅   | 알림 취소                            |

---

## 4. 화면 (Views)

### 4.1 메인 화면

| 컴포넌트                   | 상태 | 비고                                 |
| -------------------------- | ---- | ------------------------------------ |
| `MainView`                 | ✅   | 앱 메인 컨테이너                     |
| ├─ 공지 배너               | ✅   | NoticeBanner 컴포넌트                |
| ├─ 방향 선택               | ✅   | DirectionSelector (양방향 지원)      |
| ├─ 실시간 카운트다운       | ✅   | LiveCountdownCard 컴포넌트           |
| ├─ 노선 정보               | ✅   | RouteInfoBar (소요시간/요금)         |
| ├─ 정류장 경로             | ✅   | RouteStopsView 컴포넌트              |
| ├─ 첫차/막차 정보          | ✅   | FirstLastBusInfo 컴포넌트            |
| ├─ 평일/주말 탭            | ✅   | ScheduleTypePicker                   |
| ├─ 시간표 리스트           | ✅   | TimetableGrid (세로 리스트)          |
| ├─ 다음 버스 강조          | ✅   | TimeRow에서 시각적 강조              |
| ├─ 운행 종료 안내          | ✅   | EndOfServiceCard                     |
| └─ 5분 전 알림             | ✅   | NotificationService 연동             |

### 4.2 보조 화면

| 컴포넌트                   | 상태 | 비고                                 |
| -------------------------- | ---- | ------------------------------------ |
| `LaunchScreenView`         | ✅   | 로고 + 데이터 로딩                   |
| `InfoView`                 | ✅   | 앱 정보, 제보하기 링크               |

### 4.3 위젯

| 컴포넌트                   | 상태 | 비고                                 |
| -------------------------- | ---- | ------------------------------------ |
| `LocalBusWidget`           | ✅   | 홈 화면 위젯                         |
| `LocalBusWidgetBundle`     | ✅   | 위젯 번들                            |

---

## 5. 컴포넌트

### 5.1 UI 컴포넌트

| 컴포넌트                   | 상태 | 비고                                 |
| -------------------------- | ---- | ------------------------------------ |
| `NoticeBanner`             | ✅   | 상단 공지 띠 배너                    |
| `TimeRow`                  | ✅   | 개별 버스 시간 셀 (다음 버스 강조)   |
| `TimetableGrid`            | ✅   | 시간표 그리드                        |
| `ScheduleTypePicker`       | ✅   | 평일/주말 선택 UI                    |
| `OfflineBanner`            | ✅   | 오프라인 모드 안내                   |
| `EndOfServiceCard`         | ✅   | 운행 종료 안내                       |
| `LiveCountdownCard`        | ✅   | 실시간 카운트다운 + 알림 버튼        |
| `DirectionSelector`        | ✅   | 방향 선택 버튼                       |
| `RouteInfoBar`             | ✅   | 소요시간/요금 정보                   |
| `RouteStopsView`           | ✅   | 정류장 경로 타임라인                 |
| `FirstLastBusInfo`         | ✅   | 첫차/막차 정보 칩                    |
| `InfoChip`                 | ✅   | 정보 표시용 칩 컴포넌트              |

### 5.2 상태 표시

| 컴포넌트                   | 상태 | 비고                                 |
| -------------------------- | ---- | ------------------------------------ |
| `LoadingCard`              | ✅   | 데이터 로딩 중                       |
| `ErrorView`                | ✅   | 에러 발생 시 재시도 버튼             |

---

## 6. 테스트

### 6.1 Unit Tests (Swift Testing)

| 테스트                          | 상태 | 비고                            |
| ------------------------------- | ---- | ------------------------------- |
| **DateService Tests**           |      |                                 |
| `월요일은_평일이다`             | ✅   | 월~금 → true                    |
| `금요일은_평일이다`             | ✅   | 금요일 → true                   |
| `토요일은_평일이_아니다`        | ✅   | 토요일 → false                  |
| `일요일은_평일이_아니다`        | ✅   | 일요일 → false                  |
| `공휴일_목록에_있으면_true`     | ✅   | 공휴일 목록에 있음 → true       |
| `공휴일_목록에_없으면_false`    | ✅   | 공휴일 목록에 없음 → false      |
| `평일이고_공휴일이_아니면_평일시간표_사용` | ✅ | 평일 + 공휴일 아님 → true   |
| `평일이지만_공휴일이면_주말시간표_사용`   | ✅ | 평일이지만 공휴일 → false   |
| `주말이면_주말시간표_사용`      | ✅   | 주말 → false                    |
| **FindNextBus Tests**           |      |                                 |
| `다음_버스_시간_반환`           | ✅   | 현재 시간 직후 버스 반환        |
| `정각에_해당_버스_반환`         | ✅   | 정각 → 해당 버스 반환           |
| `막차_이후_nil_반환`            | ✅   | 막차 이후 → nil                 |
| `첫차_전_첫차_반환`             | ✅   | 첫차 전 → 첫차 반환             |
| **TimetableService Tests**      |      |                                 |
| `번들_JSON_로드_성공`           | ✅   | 유효한 JSON 파싱                |
| `번들_JSON이_없으면_nil_반환`   | ✅   | 파일 없음 처리                  |
| `캐시_저장_후_로드_성공`        | ✅   | 캐시 저장/로드 검증             |
| `캐시가_없으면_nil_반환`        | ✅   | 캐시 없음 처리                  |
| `평일_공휴일아님_평일시간표_반환` | ✅ | 평일 시간표 선택               |
| `평일_공휴일_주말시간표_반환`   | ✅   | 공휴일 시 주말 시간표           |
| `토요일_주말시간표_반환`        | ✅   | 토요일 → 주말 시간표            |
| `일요일_주말시간표_반환`        | ✅   | 일요일 → 주말 시간표            |
| **TimetableData Tests**         | ✅   | JSON 파싱 테스트                |
| **NetworkService Tests**        | ✅   | 네트워크 요청 테스트            |
| **MainViewModel Tests**         | ✅   | ViewModel 로직 테스트           |

### 6.2 UI Tests (XCUITest)

| 테스트                          | 상태 | 비고                            |
| ------------------------------- | ---- | ------------------------------- |
| `testMainViewDisplaysTimetable` | ✅   | 시간표 리스트 표시              |
| `testNavigationTitleDisplays`   | ✅   | 네비게이션 타이틀 확인          |
| `testTabSwitchingWorks`         | ✅   | 평일/주말 탭 전환               |
| `testNextBusIsHighlighted`      | ✅   | 다음 버스 강조 확인             |
| `testCountdownCardDisplays`     | ✅   | 카운트다운 카드 표시            |
| `testFirstLastBusInfoDisplays`  | ✅   | 첫차/막차 정보 표시             |
| `testDirectionSelectorWorks`    | ✅   | 방향 선택 버튼 동작             |
| `testInfoButtonOpensInfoView`   | ✅   | 정보 버튼 → InfoView            |
| `testPullToRefreshWorks`        | ✅   | Pull to Refresh 동작            |
| `testLaunch`                    | ✅   | 앱 실행 + 스크린샷              |
| `testLaunchInDarkMode`          | ✅   | 다크모드 실행 + 스크린샷        |

---

## 7. 배포 준비

### 7.1 App Store 준비

| 항목                       | 상태 | 비고                          |
| -------------------------- | ---- | ----------------------------- |
| 앱 이름 및 부제            | ⬜   | LocalBus - 장유 버스 시간표   |
| 앱 설명                    | ⬜   | 한국어/영어                   |
| 스크린샷 (6.7", 6.5", 5.5")| ⬜   | 필수 사이즈                   |
| 앱 아이콘                  | ⬜   | 1024x1024                     |
| 개인정보 처리방침          | ⬜   | URL 필요                      |
| 카테고리                   | ⬜   | 여행 또는 내비게이션          |
| 연령 등급                  | ⬜   | 4+                            |

### 7.2 데이터 인프라

| 항목                       | 상태 | 비고                                       |
| -------------------------- | ---- | ------------------------------------------ |
| GitHub Raw JSON 호스팅     | ✅   | JongMini/LocalBus-Data 저장소              |
| 번들 기본 JSON             | ✅   | timetable.json (양방향 포함)               |
| 공휴일 목록 2026년         | ✅   | holidays 배열에 포함                       |

### 7.3 품질 검증

| 항목                       | 상태 | 비고                          |
| -------------------------- | ---- | ----------------------------- |
| 오프라인 모드 테스트       | ⬜   | 비행기 모드에서 동작          |
| 네트워크 전환 테스트       | ⬜   | WiFi ↔ LTE 전환              |
| 다양한 시간대 테스트       | ⬜   | 첫차/막차/중간 시간           |
| 공휴일 로직 테스트         | ✅   | Unit Test로 검증 완료         |
| 메모리 누수 검사           | ⬜   | Instruments                   |

---

## 버전 히스토리

| 버전  | 날짜       | 변경 내용                                    |
| ----- | ---------- | -------------------------------------------- |
| 0.1.0 | 2026-01-10 | 초기 체크리스트 작성                         |
| 0.2.0 | 2026-01-20 | MVP 핵심 기능 완료, 체크리스트 상태 갱신     |
