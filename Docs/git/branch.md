# 브랜치 전략

> 이 프로젝트는 **GitHub Flow** 전략을 사용합니다.

---

## GitHub Flow 개요

```
main ────●────●────●────●────●────●────
              \         /    \       /
feat/xxx       ●───●───●      ●─────●
                            fix/yyy
```

### 핵심 원칙

1. **`main` 브랜치는 항상 배포 가능한 상태**
2. 새 작업은 `main`에서 브랜치를 생성하여 진행
3. 작업 완료 후 `main`에 머지
4. 릴리즈는 `main`에 태그로 관리 (`v1.0.0`)

---

## 브랜치 종류

| 브랜치 | 설명 | 예시 |
|--------|------|------|
| `main` | 프로덕션 배포 브랜치 | - |
| `feat/*` | 새 기능 개발 | `feat/next-bus-scroll` |
| `fix/*` | 버그 수정 | `fix/holiday-schedule` |
| `refactor/*` | 리팩토링 | `refactor/date-service` |
| `chore/*` | 설정, 빌드 | `chore/update-xcode` |
| `docs/*` | 문서 작업 | `docs/readme-update` |

---

## 브랜치 네이밍 규칙

```
{type}/{description}
```

### Type (소문자)

| Type | 설명 |
|------|------|
| `feat` | 새로운 기능 |
| `fix` | 버그 수정 |
| `refactor` | 리팩토링 |
| `design` | UI/뷰 관련 |
| `chore` | 빌드, 설정 |
| `docs` | 문서 |
| `test` | 테스트 |
| `perf` | 성능 개선 |

### Description

- **케밥 케이스(kebab-case)** 사용
- 간결하고 명확하게 작성
- 영어 소문자 + 하이픈

### 예시

```bash
feat/next-bus-auto-scroll
fix/holiday-weekend-schedule
refactor/timetable-service-split
design/main-view-dark-mode
chore/github-actions-ci
```

---

## 워크플로우

### 1. 브랜치 생성

```bash
git checkout main
git pull origin main
git checkout -b feat/my-feature
```

### 2. 작업 및 커밋

```bash
# 마이크로 커밋으로 작업
git add .
git commit -m "[Feat]: 기능 구현"
```

### 3. 푸시

```bash
git push -u origin feat/my-feature
```

### 4. PR 생성 및 머지 (선택)

```bash
# GitHub에서 PR 생성 또는 직접 머지
gh pr create --title "[Feat]: 기능 추가" --body "..."

# 또는 로컬에서 직접 머지
git checkout main
git merge feat/my-feature
git push origin main
```

### 5. 브랜치 정리

```bash
git branch -d feat/my-feature
git push origin --delete feat/my-feature
```

---

## 릴리즈 (태그)

App Store 배포 시 태그로 버전 관리:

```bash
# 태그 생성
git tag -a v1.0.0 -m "v1.0.0 첫 릴리즈"

# 태그 푸시
git push origin v1.0.0
```

### 버전 규칙

```
v{MAJOR}.{MINOR}.{PATCH}

예시:
v1.0.0  # 첫 릴리즈
v1.1.0  # 기능 추가
v1.1.1  # 버그 수정
v2.0.0  # 대규모 변경
```

---

## 1인 개발 시 간소화

혼자 개발할 때는 PR 없이 직접 머지해도 됩니다:

```bash
# 브랜치에서 작업 완료 후
git checkout main
git merge feat/my-feature
git push origin main
git branch -d feat/my-feature
```

**단, main 직접 커밋은 피하고 브랜치를 통해 작업하는 습관 유지**

---

## 관련 문서

- [커밋 컨벤션](./commit.md)
- [마이크로 전략](./micro-strategy.md)
- [릴리즈 워크플로우](./release-workflow.md)
