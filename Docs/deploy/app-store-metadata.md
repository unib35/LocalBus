# LocalBus App Store 메타데이터

> App Store Connect 제출을 위한 메타데이터 정리

---

## 기본 정보

| 항목 | 내용 |
|------|------|
| **앱 이름** | LocalBus |
| **부제** | 장유-사상 버스 시간표 |
| **카테고리** | 여행 (Travel) |
| **보조 카테고리** | 내비게이션 (Navigation) |
| **연령 등급** | 4+ |

---

## 앱 설명 (한국어)

### 프로모션 텍스트 (170자 이내)
```
장유-사상 시외버스 시간표를 한눈에! 다음 버스까지 남은 시간을 실시간으로 확인하세요.
```

### 설명 (4000자 이내)
```
장유와 사상을 오가는 시외버스 이용자를 위한 시간표 앱입니다.

[ 주요 기능 ]

• 실시간 카운트다운
  - 다음 버스까지 남은 시간을 초 단위로 표시
  - 앱 실행 즉시 확인 가능

• 평일/주말/공휴일 자동 판단
  - 현재 날짜에 맞는 시간표 자동 표시
  - 공휴일에는 주말 시간표 적용

• 출발 알림
  - 버스 출발 5분 전 알림 설정
  - 버스를 놓치지 않도록 도와줍니다

• 홈 화면 위젯
  - 앱을 열지 않고도 다음 버스 확인
  - 소형/중형 위젯 지원

• 오프라인 지원
  - 인터넷 연결 없이도 시간표 확인 가능
  - 캐시된 데이터 활용

[ 노선 정보 ]
• 장유 ↔ 사상 시외버스
• 소요시간: 약 30분
• 요금: 2,600원

※ 본 앱의 시간표는 참고용입니다. 실제 운행은 기상, 교통 상황에 따라 달라질 수 있습니다.
```

### 키워드 (100자 이내, 쉼표로 구분)
```
버스,시간표,장유,사상,시외버스,김해,부산,통근,출퇴근,대중교통
```

---

## 앱 설명 (영어)

### Promotional Text
```
Check Jangyu-Sasang intercity bus schedules at a glance! See real-time countdown to the next bus.
```

### Description
```
A timetable app for intercity bus commuters traveling between Jangyu and Sasang.

[ Key Features ]

• Real-time Countdown
  - Shows time remaining until the next bus in seconds
  - Instant access when you open the app

• Automatic Weekday/Weekend/Holiday Detection
  - Displays the appropriate schedule for the current date
  - Holiday schedules automatically applied

• Departure Alerts
  - Set notifications 5 minutes before bus departure
  - Never miss your bus again

• Home Screen Widget
  - Check the next bus without opening the app
  - Small and medium widget sizes available

• Offline Support
  - Access schedules without internet connection
  - Uses cached data

[ Route Information ]
• Jangyu ↔ Sasang Intercity Bus
• Travel time: Approximately 30 minutes
• Fare: 2,600 KRW

※ Schedules are for reference only. Actual departure times may vary due to weather and traffic conditions.
```

### Keywords
```
bus,timetable,jangyu,sasang,intercity,gimhae,busan,commute,transit,korea
```

---

## 스크린샷 요구사항

### 필수 사이즈

| 기기 | 해상도 | 비고 |
|------|--------|------|
| iPhone 6.7" | 1290 x 2796 | iPhone 15 Pro Max |
| iPhone 6.5" | 1284 x 2778 | iPhone 14 Plus |
| iPhone 5.5" | 1242 x 2208 | iPhone 8 Plus |

### 권장 스크린샷 구성

1. **메인 화면** - 실시간 카운트다운 표시
2. **시간표 목록** - 평일 시간표 전체
3. **위젯** - 홈 화면 위젯 예시
4. **알림 설정** - 출발 알림 기능
5. **다크 모드** - 다크 모드 지원

---

## 지원 URL

| 항목 | URL |
|------|-----|
| 지원 URL | https://github.com/unib35/LocalBus |
| 개인정보 처리방침 | (준비 필요) |
| 마케팅 URL | (선택) |

---

## 검토 정보

### 앱 검토 노트
```
이 앱은 장유-사상 구간 시외버스 시간표를 제공합니다.
- 시간표 데이터는 GitHub Raw에서 JSON 형식으로 제공됩니다.
- 오프라인 시에는 번들에 포함된 기본 시간표를 사용합니다.
- 로그인 없이 모든 기능을 사용할 수 있습니다.
- 개인정보를 수집하지 않습니다.
```

---

## 버전 정보

| 버전 | 변경 내용 |
|------|----------|
| 1.0.0 | 초기 출시 - 기본 시간표, 위젯, 알림 기능 |

---

## 체크리스트

- [ ] 앱 이름 확정
- [ ] 앱 설명 검토
- [ ] 스크린샷 촬영
- [ ] 앱 아이콘 제작
- [ ] 개인정보 처리방침 URL 준비
- [ ] App Store Connect 계정 설정
