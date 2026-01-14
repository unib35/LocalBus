# 마이크로 브랜치 & 마이크로 커밋 전략

이 문서는 LocalBus 프로젝트의 Git 워크플로우 핵심 전략을 설명합니다.

## 핵심 원칙

> **"작은 변경, 빠른 커밋, 독립적인 브랜치"**

- 하나의 논리적 변경 = 하나의 커밋
- 하나의 기능/수정 = 하나의 브랜치 = 하나의 PR
- main 브랜치 직접 커밋/푸시 금지

---

## 마이크로 브랜치 전략

### 왜 마이크로 브랜치인가?

| 장점            | 설명                                |
| --------------- | ----------------------------------- |
| **리뷰 용이**   | 작은 PR은 리뷰어가 빠르게 검토 가능 |
| **충돌 최소화** | 짧은 생명주기로 머지 충돌 감소      |
| **빠른 피드백** | 작은 단위로 CI/CD 빠르게 통과       |
| **쉬운 롤백**   | 문제 발생 시 해당 PR만 리버트       |
| **명확한 이력** | 기능별 변경 이력 추적 용이          |

### 브랜치 생성 규칙

```bash
# 형식
{type}/{description}

# 예시
feat/next-bus-auto-scroll
fix/holiday-schedule-bug
refactor/extract-date-service
docs/update-readme
chore/update-xcode-settings
```

### 브랜치 생명주기

```
main ──┬─────────────────────────────────────────► main
       │                                          ▲
       └── feat/feature-a ──[commits]──[PR]──[merge]
```

1. `main`에서 새 브랜치 생성
2. 마이크로 커밋으로 작업
3. 원격에 푸시
4. PR 생성 및 리뷰
5. 머지 후 브랜치 삭제

### 기능별 브랜치 분리

**여러 기능을 동시에 작업할 때는 반드시 브랜치를 분리합니다.**

```bash
# ❌ Bad: 여러 기능을 하나의 브랜치에서 작업
feat/timetable-and-settings-improvements

# ✅ Good: 기능별 브랜치 분리
feat/next-bus-highlight
feat/offline-toast-message
fix/holiday-detection
```

**분리 기준:**

- 논리적으로 독립적인 변경인 경우
- 서로 다른 이슈를 해결하는 경우
- 다른 화면/컴포넌트를 수정하는 경우

---

## 마이크로 커밋 전략

### 왜 마이크로 커밋인가?

| 장점                | 설명                           |
| ------------------- | ------------------------------ |
| **원자적 변경**     | 각 커밋이 하나의 완결된 변경   |
| **bisect 용이**     | 버그 원인 이진 탐색 가능       |
| **체리픽 가능**     | 특정 변경만 다른 브랜치에 적용 |
| **리버트 용이**     | 문제 커밋만 되돌리기 가능      |
| **히스토리 가독성** | 변경 의도가 명확하게 드러남    |

### 커밋 타이밍

**즉시 커밋해야 하는 순간:**

- [ ] 파일 1-3개 변경 완료
- [ ] 하나의 함수/컴포넌트 작성 완료
- [ ] 리팩토링 한 단계 완료
- [ ] 버그 하나 수정 완료
- [ ] 테스트 통과 확인
- [ ] 빌드 에러 해결

### 커밋 메시지 형식

```bash
[Type]: 제목 (50자 이내)

# Type 종류
[Feat]     # 새로운 기능
[Fix]      # 버그 수정
[Refactor] # 리팩토링 (기능 변경 없음)
[Design]   # UI/뷰 관련
[Docs]     # 문서
[Test]     # 테스트
[Chore]    # 빌드, 설정 등
```

### 좋은 커밋 vs 나쁜 커밋

```bash
# ❌ Bad: 범위가 넓고 모호함
git commit -m "[Feat]: 여러 기능 추가 및 버그 수정"
git commit -m "[Fix]: 수정"
git commit -m "[Refactor]: 코드 정리"

# ✅ Good: 구체적이고 원자적
git commit -m "[Feat]: 다음 버스 자동 스크롤 기능 구현"
git commit -m "[Fix]: 공휴일 평일 시간표 표시 버그 수정"
git commit -m "[Refactor]: DateService에서 시간 계산 로직 분리"
```

### 커밋 분리 예시

하나의 기능을 구현할 때도 단계별로 커밋합니다:

```bash
# 다음 버스 자동 스크롤 기능 구현 시
git commit -m "[Feat]: findNextBus 메서드 구현"
git commit -m "[Test]: findNextBus 유닛 테스트 추가"
git commit -m "[Feat]: 메인 뷰에 자동 스크롤 적용"
git commit -m "[Design]: 다음 버스 셀 강조 스타일 추가"
git commit -m "[Fix]: 막차 이후 스크롤 위치 수정"
```

---

## 워크플로우 예시

### 새 기능 개발

```bash
# 1. main 최신화
git checkout main && git pull origin main

# 2. 새 브랜치 생성
git checkout -b feat/next-bus-auto-scroll

# 3. 작업 & 마이크로 커밋 (반복)
# ... 코드 작성 ...
git add LocalBusApp/Services/DateService.swift
git commit -m "[Feat]: findNextBus 메서드 구현"

# ... 추가 작업 ...
git add .
git commit -m "[Test]: findNextBus 테스트 추가"

# 4. 푸시
git push -u origin feat/next-bus-auto-scroll

# 5. PR 생성
gh pr create --title "[Feat]: 다음 버스 자동 스크롤" --body "..."
```

### 버그 수정

```bash
git checkout main && git pull
git checkout -b fix/holiday-schedule-bug

# 수정 & 커밋
git commit -m "[Fix]: 공휴일 주말 시간표 적용 로직 수정"

git push -u origin fix/holiday-schedule-bug
gh pr create --title "[Fix]: 공휴일 시간표 버그 수정" --body "..."
```

### 여러 기능 동시 작업

```bash
# 기능 A 작업
git checkout -b feat/offline-toast
# ... 작업 & 커밋 ...
git push -u origin feat/offline-toast
gh pr create ...

# 기능 B 작업 (main에서 새로 시작)
git checkout main && git pull
git checkout -b feat/notice-banner
# ... 작업 & 커밋 ...
git push -u origin feat/notice-banner
gh pr create ...
```

---

## 체크리스트

### 브랜치 생성 전

- [ ] main 브랜치가 최신 상태인가?
- [ ] 브랜치명이 작업 내용을 명확히 설명하는가?
- [ ] 하나의 기능만 다루는 브랜치인가?

### 커밋 전

- [ ] 변경이 하나의 논리적 단위인가?
- [ ] 커밋 메시지가 변경 내용을 명확히 설명하는가?
- [ ] 불필요한 파일이 포함되지 않았는가?

### PR 생성 전

- [ ] 모든 변경사항이 커밋되었는가?
- [ ] 빌드가 통과하는가?
- [ ] PR 제목과 본문이 템플릿을 따르는가?

---

## 참고

- [commit.md](./commit.md) - 커밋 메시지 컨벤션
- [branch.md](./branch.md) - 브랜치 네이밍 컨벤션
- [pull-request-template.md](./pull-request-template.md) - PR 템플릿
- [release-workflow.md](./release-workflow.md) - 릴리즈 워크플로우
