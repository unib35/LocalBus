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
| 최소 iOS 버전 설정         | ⬜   | iOS 16.0+                     |
| Bundle Identifier 설정     | ⬜   | com.localbus.app              |
| App Icon 설정              | ⬜   | Assets.xcassets               |
| Launch Screen 설정         | ⬜   | 로고 + 브랜드 컬러            |

### 1.2 프로젝트 구조

| 항목                    | 상태 | 비고                                 |
| ----------------------- | ---- | ------------------------------------ |
| Models 폴더             | ⬜   | 데이터 모델                          |
| Views 폴더              | ⬜   | SwiftUI Views                        |
| ViewModels 폴더         | ⬜   | MVVM ViewModel                       |
| Services 폴더           | ⬜   | 비즈니스 로직                        |
| Utilities 폴더          | ⬜   | 헬퍼 함수, 확장                      |
| Resources 폴더          | ⬜   | 로컬 JSON, 에셋                      |

### 1.3 의존성

| 항목                    | 상태 | 비고                                 |
| ----------------------- | ---- | ------------------------------------ |
| Swift Package Manager   | ⬜   | 의존성 관리                          |
| (선택) Alamofire        | ⬜   | 네트워크 (또는 URLSession 사용)      |

---

## 2. 데이터 모델

### 2.1 핵심 모델 (Models)

| 모델                    | 상태 | 비고                                 |
| ----------------------- | ---- | ------------------------------------ |
| `TimetableData`         | ⬜   | 전체 JSON 구조                       |
| `Meta`                  | ⬜   | 버전, 업데이트 날짜, 공지, 연락처    |
| `Timetable`             | ⬜   | 평일/주말 시간표 배열                |
| `BusTime`               | ⬜   | 개별 버스 시간 (HH:mm)               |

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
| `TimetableService`         | ⬜   | 시간표 데이터 관리 총괄              |
| ├─ `fetchRemoteData()`     | ⬜   | GitHub Raw JSON 비동기 요청          |
| ├─ `loadLocalData()`       | ⬜   | 번들 내 기본 JSON 로드               |
| ├─ `loadCachedData()`      | ⬜   | UserDefaults/파일 캐시 로드          |
| └─ `saveToCache()`         | ⬜   | 성공 데이터 로컬 저장                |

### 3.2 날짜/시간 서비스

| 서비스                         | 상태 | 비고                             |
| ------------------------------ | ---- | -------------------------------- |
| `DateService`                  | ⬜   | 날짜/시간 판단 로직              |
| ├─ `isWeekday()`               | ⬜   | 평일 여부 (월~금)                |
| ├─ `isHoliday(date:holidays:)` | ⬜   | 공휴일 목록과 비교               |
| ├─ `shouldUseWeekdaySchedule()`| ⬜   | 평일 && !공휴일 → true           |
| └─ `findNextBus(times:from:)`  | ⬜   | 현재 시간 이후 가장 가까운 버스  |

### 3.3 네트워크 서비스

| 서비스                     | 상태 | 비고                                 |
| -------------------------- | ---- | ------------------------------------ |
| `NetworkService`           | ⬜   | HTTP 요청 처리                       |
| ├─ `fetch<T>(url:)`        | ⬜   | Generic JSON 디코딩                  |
| └─ `isConnected`           | ⬜   | 네트워크 상태 확인 (NWPathMonitor)   |

---

## 4. 화면 (Views)

### 4.1 메인 화면

| 컴포넌트                   | 상태 | 비고                                 |
| -------------------------- | ---- | ------------------------------------ |
| `MainView`                 | ⬜   | 앱 메인 컨테이너                     |
| ├─ 공지 배너               | ⬜   | notice_message 있을 때만 표시        |
| ├─ 평일/주말 탭            | ⬜   | Segmented Control 또는 Picker        |
| ├─ 시간표 리스트           | ⬜   | ScrollView + LazyVStack              |
| ├─ 다음 버스 강조          | ⬜   | 자동 스크롤 + 시각적 강조            |
| └─ 운행 종료 안내          | ⬜   | 막차 이후 메시지 표시                |

### 4.2 보조 화면

| 컴포넌트                   | 상태 | 비고                                 |
| -------------------------- | ---- | ------------------------------------ |
| `SplashView`               | ⬜   | 로고 + 데이터 로딩                   |
| `InfoView`                 | ⬜   | 앱 정보, 제보하기 링크               |

---

## 5. 컴포넌트

### 5.1 UI 컴포넌트

| 컴포넌트                   | 상태 | 비고                                 |
| -------------------------- | ---- | ------------------------------------ |
| `NoticeBanner`             | ⬜   | 상단 공지 띠 배너                    |
| `BusTimeCell`              | ⬜   | 개별 버스 시간 셀                    |
| `NextBusCell`              | ⬜   | 다음 버스 강조 셀 (Bold/Color)       |
| `ScheduleTabPicker`        | ⬜   | 평일/주말 선택 UI                    |
| `OfflineToast`             | ⬜   | 오프라인 모드 안내                   |
| `EndOfServiceView`         | ⬜   | 운행 종료 안내                       |
| `FeedbackButton`           | ⬜   | 제보하기 메일 연동                   |

### 5.2 상태 표시

| 컴포넌트                   | 상태 | 비고                                 |
| -------------------------- | ---- | ------------------------------------ |
| `LoadingView`              | ⬜   | 데이터 로딩 중                       |
| `ErrorView`                | ⬜   | 에러 발생 시 재시도 버튼             |

---

## 6. 테스트

### 6.1 Unit Tests (XCTest)

| 테스트                          | 상태 | 비고                            |
| ------------------------------- | ---- | ------------------------------- |
| **DateService Tests**           |      |                                 |
| `testIsWeekdayReturnsTrue`      | ⬜   | 월~금 → true                    |
| `testIsWeekdayReturnsFalse`     | ⬜   | 토, 일 → false                  |
| `testIsHolidayReturnsTrue`      | ⬜   | 공휴일 목록에 있음 → true       |
| `testShouldUseWeekdaySchedule`  | ⬜   | 평일 + 공휴일 아님 → true       |
| `testHolidayUsesWeekendSchedule`| ⬜   | 평일이지만 공휴일 → false       |
| **FindNextBus Tests**           |      |                                 |
| `testFindNextBusReturnsCorrect` | ⬜   | 현재 시간 직후 버스 반환        |
| `testFindNextBusReturnsNil`     | ⬜   | 막차 이후 → nil                 |
| `testFindNextBusAtExactTime`    | ⬜   | 정각 → 해당 버스 반환           |
| **TimetableService Tests**      |      |                                 |
| `testDecodeValidJSON`           | ⬜   | 유효한 JSON 파싱                |
| `testDecodeInvalidJSON`         | ⬜   | 잘못된 JSON 에러 처리           |
| `testCacheDataPersists`         | ⬜   | 캐시 저장/로드 검증             |

### 6.2 UI Tests (XCUITest)

| 테스트                          | 상태 | 비고                            |
| ------------------------------- | ---- | ------------------------------- |
| `testMainViewDisplaysTimetable` | ⬜   | 시간표 리스트 표시              |
| `testTabSwitchingWorks`         | ⬜   | 평일/주말 탭 전환               |
| `testNextBusIsHighlighted`      | ⬜   | 다음 버스 강조 확인             |
| `testNoticeBannerAppears`       | ⬜   | 공지 배너 표시                  |

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

| 항목                       | 상태 | 비고                          |
| -------------------------- | ---- | ----------------------------- |
| GitHub Raw JSON 호스팅     | ⬜   | 시간표 데이터 URL             |
| 번들 기본 JSON             | ⬜   | 앱 내 기본 데이터             |
| 공휴일 목록 2026년         | ⬜   | holidays 배열                 |

### 7.3 품질 검증

| 항목                       | 상태 | 비고                          |
| -------------------------- | ---- | ----------------------------- |
| 오프라인 모드 테스트       | ⬜   | 비행기 모드에서 동작          |
| 네트워크 전환 테스트       | ⬜   | WiFi ↔ LTE 전환              |
| 다양한 시간대 테스트       | ⬜   | 첫차/막차/중간 시간           |
| 공휴일 로직 테스트         | ⬜   | 실제 공휴일 날짜              |
| 메모리 누수 검사           | ⬜   | Instruments                   |

---

## 버전 히스토리

| 버전  | 날짜       | 변경 내용          |
| ----- | ---------- | ------------------ |
| 0.1.0 | 2026-01-10 | 초기 체크리스트 작성 |
