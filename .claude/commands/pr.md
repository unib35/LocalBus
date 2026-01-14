---
allowed-tools: Bash(git:*), Bash(gh:*)
argument-hint: [target-branch (default: main)]
description: Pull Request 생성
---

# Create Pull Request

## Context

- Current branch: !`git branch --show-current`
- Git status: !`git status --short`
- Commits on this branch: !`git log main..HEAD --oneline`
- Changes summary: !`git diff main --stat`

## Task

현재 브랜치의 변경사항을 기반으로 Pull Request를 생성하세요.

## 대상 브랜치

$ARGUMENTS (기본값: main)

## PR 생성 절차

### 1. 사전 검증

```bash
# 빌드 확인
xcodebuild build -scheme LocalBusApp -destination 'platform=iOS Simulator,name=iPhone 15' -quiet

# 테스트 확인
xcodebuild test -scheme LocalBusApp -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:LocalBusAppTests
```

### 2. 푸시 (필요 시)

```bash
git push -u origin $(git branch --show-current)
```

### 3. PR 생성

```bash
gh pr create \
  --base main \
  --title "[Type]: 제목" \
  --body "$(cat <<'EOF'
## 작업 요약

[변경사항 요약]

## 상세 작업 내용

- [x] 작업 1
- [x] 작업 2

## 테스트

- [x] 빌드 성공
- [x] 테스트 통과

## 관련 이슈

Close #
EOF
)"
```

## PR 제목 형식

커밋 컨벤션과 동일:
- `[Feat]`: 새로운 기능
- `[Fix]`: 버그 수정
- `[Refactor]`: 리팩토링
- `[Design]`: UI/뷰 관련
- `[Test]`: 테스트 코드
- `[Docs]`: 문서 작업
- `[Chore]`: 설정, 빌드

## 출력

PR 생성 후 URL을 출력하세요.
