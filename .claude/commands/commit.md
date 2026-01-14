---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git commit:*), Bash(git log:*)
argument-hint: [message (optional)]
description: Git 컨벤션에 맞는 커밋 생성
---

# Git Commit

## Context

- Current git status: !`git status`
- Staged changes: !`git diff --cached --stat`
- Unstaged changes: !`git diff --stat`
- Recent commits (for style reference): !`git log --oneline -5`

## Task

위 변경사항을 분석하여 프로젝트 Git 컨벤션에 맞는 커밋을 생성하세요.

### 커밋 메시지 형식

```
[Type]: 제목 (50자 이내, 마침표 없이, 명령문)

- 세부 내용 (선택)

Close #이슈번호 (선택)
```

### Type 목록

- `[Feat]`: 새로운 기능
- `[Fix]`: 버그 수정
- `[Refactor]`: 리팩토링 (기능 변경 없음)
- `[Design]`: UI/뷰 관련
- `[Test]`: 테스트 코드
- `[Docs]`: 문서 작업
- `[Chore]`: 설정, 빌드, 잡무

### 규칙

1. 변경사항을 분석하여 적절한 Type 선택
2. 제목은 **명령문**으로 작성 (예: "Add", "Fix", "Update")
3. 마침표 없이 작성
4. 50자 이내로 간결하게
5. 구조적 변경(리팩토링)과 행위적 변경(기능)은 별도 커밋

### 사용자 메시지

$ARGUMENTS

사용자가 메시지를 제공했다면 참고하되, 컨벤션에 맞게 조정하세요.
