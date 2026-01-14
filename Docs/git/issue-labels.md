# GitHub 이슈 라벨 가이드

이 문서는 LocalBus 프로젝트에서 사용하는 GitHub 이슈 라벨을 정의합니다.

---

## 라벨 카테고리

### 1. 타입 (Type) - 8개

이슈의 종류를 나타냅니다. **필수**로 하나 이상 선택합니다.

| 라벨            | 색상       | 설명                           | 예시                           |
| --------------- | ---------- | ------------------------------ | ------------------------------ |
| `bug`           | #d73a4a    | 버그, 오류 수정                | 시간표 미표시, 크래시          |
| `enhancement`   | #a2eeef    | 새 기능 추가 또는 기능 개선    | 새 화면 구현, 기능 추가        |
| `documentation` | #0075ca    | 문서 작성 또는 수정            | README 업데이트                |
| `refactor`      | #9c27b0    | 코드 리팩토링 (기능 변경 없음) | 서비스 분리, 코드 정리         |
| `performance`   | #ff9800    | 성능 최적화                    | 로딩 속도 개선, 메모리 최적화  |
| `chore`         | #ededed    | 빌드, 설정, 인프라 작업        | Xcode 설정, 의존성 업데이트    |
| `test`          | #0e8a16    | 테스트 작성 또는 수정          | 유닛 테스트, UI 테스트         |
| `hotfix`        | #ff0000    | 프로덕션 긴급 수정             | 크리티컬 버그 즉시 수정        |

### 2. 우선순위 (Priority) - 4개

작업의 긴급도를 나타냅니다. 가능하면 설정합니다.

| 라벨                 | 색상       | 설명           |
| -------------------- | ---------- | -------------- |
| `priority: critical` | #b60205    | 즉시 수정 필요 |
| `priority: high`     | #d93f0b    | 높은 우선순위  |
| `priority: medium`   | #fbca04    | 중간 우선순위  |
| `priority: low`      | #c2e0c6    | 낮은 우선순위  |

### 3. 상태 (Status) - 4개

이슈의 진행 상태를 나타냅니다.

| 라벨                      | 색상       | 설명                           |
| ------------------------- | ---------- | ------------------------------ |
| `status: in progress`     | #1d76db    | 작업 진행 중                   |
| `status: blocked`         | #e11d21    | 다른 이슈/외부 요인으로 블로킹 |
| `status: on hold`         | #bfd4f2    | 일시적으로 보류                |
| `status: ready for merge` | #0e8a16    | 승인 완료, 머지 대기           |

### 4. 영역 (Area) - 7개

앱의 특정 기능 영역을 나타냅니다.

| 라벨              | 색상       | 설명                    |
| ----------------- | ---------- | ----------------------- |
| `area: timetable` | #bfdadc    | 시간표 표시/로직        |
| `area: schedule`  | #c5def5    | 평일/주말/공휴일 판단   |
| `area: data`      | #fef2c0    | JSON 데이터, 캐싱       |
| `area: network`   | #f7c6c7    | 네트워크, 오프라인 처리 |
| `area: ui`        | #ff99cc    | UI/UX, 디자인           |
| `area: settings`  | #e2e3e5    | 설정, 앱 정보           |
| `area: notice`    | #c2f0c2    | 공지 배너               |

### 5. 플랫폼 (Platform) - 3개

iOS 관련 세부 기술을 나타냅니다.

| 라벨              | 색상       | 설명                |
| ----------------- | ---------- | ------------------- |
| `ios: swiftui`    | #007aff    | SwiftUI 관련        |
| `ios: swift`      | #f05138    | Swift 언어 관련     |
| `ios: xcode`      | #147efb    | Xcode 설정, 빌드    |

### 6. 품질 (Quality) - 3개

코드 품질 관련 라벨입니다.

| 라벨              | 색상       | 설명                     |
| ----------------- | ---------- | ------------------------ |
| `tech debt`       | #607d8b    | 기술 부채 해결 필요      |
| `accessibility`   | #4caf50    | 접근성 (a11y) 개선       |
| `localization`    | #9c27b0    | 다국어 지원              |

### 7. 릴리즈 (Release) - 2개

릴리즈 관련 라벨입니다.

| 라벨             | 색상       | 설명                |
| ---------------- | ---------- | ------------------- |
| `release`        | #00bcd4    | 릴리즈 관련         |
| `app-store`      | #0d96f6    | App Store 제출 관련 |

### 8. 기타 (Miscellaneous) - 4개

| 라벨               | 색상       | 설명                 |
| ------------------ | ---------- | -------------------- |
| `good first issue` | #7057ff    | 첫 기여에 적합       |
| `question`         | #d876e3    | 추가 정보 요청       |
| `duplicate`        | #cfd3d7    | 중복 이슈            |
| `wontfix`          | #ffffff    | 수정하지 않을 이슈   |

---

## 라벨 사용 가이드

### 이슈 생성 시

1. **타입 라벨 필수**: 최소 1개의 타입 라벨 선택
2. **영역 라벨 권장**: 관련 기능 영역이 명확하면 선택
3. **우선순위**: 긴급도가 있으면 설정

```
예시: 공휴일 시간표 버그 이슈
라벨: bug, priority: high, area: schedule
```

### 작업 진행 시

1. 작업 시작 → `status: in progress` 추가
2. 블로킹 발생 → `status: blocked` 추가 (코멘트로 사유 명시)
3. 승인 완료 → `status: ready for merge` 추가

### 라벨 조합 예시

| 상황                  | 라벨 조합                                     |
| --------------------- | --------------------------------------------- |
| 새 기능 개발          | `enhancement` + `area: timetable`             |
| 긴급 버그 수정        | `bug` + `priority: critical` + `hotfix`       |
| UI 개선               | `enhancement` + `area: ui`                    |
| 문서 업데이트         | `documentation`                               |
| 리팩토링              | `refactor` + `tech debt`                      |
| 테스트 추가           | `test` + `area: schedule`                     |
| 오프라인 처리 개선    | `enhancement` + `area: network`               |
| App Store 릴리즈 준비 | `release` + `app-store`                       |

---

## 라벨 관리

### 새 라벨 추가

```bash
gh label create "area: widget" --description "위젯 관련" --color "d4c5f9"
```

### 라벨 수정

```bash
gh label edit "bug" --description "새로운 설명" --color "ff0000"
```

### 전체 라벨 조회

```bash
gh label list --limit 50
```

---

## 관련 문서

- [이슈 템플릿](./issue-template.md)
- [브랜치 컨벤션](./branch.md)
- [커밋 컨벤션](./commit.md)
