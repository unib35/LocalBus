---
allowed-tools: Read, Write, Edit, Bash(xcodebuild:*), Glob, Grep
argument-hint: [대상 파일/컴포넌트 (optional)]
description: Green 상태에서 리팩토링 수행
---

# TDD Refactor

## Task

테스트가 통과한 상태(Green)에서 코드를 리팩토링하세요.

## 대상

$ARGUMENTS

## 사전 확인

```bash
# 모든 테스트가 통과하는지 확인
xcodebuild test -scheme LocalBusApp -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:LocalBusAppTests
```

**테스트가 실패하면 리팩토링을 진행하지 마세요!**

## 리팩토링 원칙 (Tidy First)

### 구조적 변경만 수행
- 이름 변경 (Rename)
- 메서드 추출 (Extract Method)
- 파일 분리 (Move to File)
- 중복 제거 (Remove Duplication)

### 행위 변경 금지
- 새 기능 추가 ❌
- 로직 변경 ❌
- API 변경 ❌

## 리팩토링 절차

1. **현재 테스트 통과 확인**
2. **작은 단위로 변경**
3. **변경 후 테스트 재실행**
4. **반복**

## 일반적인 리팩토링 패턴

### Extract Method
```swift
// Before
func process() {
    // 긴 코드...
}

// After
func process() {
    step1()
    step2()
}

private func step1() { ... }
private func step2() { ... }
```

### Rename
```swift
// Before
let x = findBus()

// After
let nextBus = findNextBus()
```

## 완료 후

```bash
# 테스트 재실행
xcodebuild test -scheme LocalBusApp -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:LocalBusAppTests
```

테스트가 모두 통과하면 커밋:
```
[Refactor]: 리팩토링 내용
```
