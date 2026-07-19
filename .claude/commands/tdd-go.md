---
allowed-tools: Read, Write, Edit, Bash(xcodebuild:*), Glob, Grep
description: plan.md의 다음 테스트 구현 (Red → Green)
---

# TDD Go

## Context

- Current plan: @plan.md

## Task

`plan.md`에서 아직 완료되지 않은(`- [ ]`) 첫 번째 테스트를 찾아 TDD 사이클을 수행하세요.

## TDD 사이클

### 1. Red (실패하는 테스트 작성)

```swift
// LocalBusAppTests/[적절한 파일].swift
func testMethodName() {
    // Given

    // When

    // Then
    XCTAssertEqual(...)
}
```

### 2. Green (최소한의 코드로 통과)

- 테스트를 통과시키는 **최소한의** 코드만 작성
- 하드코딩도 OK (나중에 리팩토링)
- 과도한 일반화 금지

### 3. 테스트 실행

```bash
xcodebuild test -scheme LocalBusApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:JangyuBusTests/[TestClass]/[testMethod]
```

### 4. plan.md 업데이트

완료된 테스트를 체크:
```markdown
- [x] `testMethodName` - 설명
```

## 규칙

1. **한 번에 하나의 테스트만** 구현
2. 테스트가 먼저 **실패**하는지 확인 (Red)
3. **최소한의 코드**로 통과시킴 (Green)
4. 리팩토링은 `/tdd-refactor`로 별도 수행
5. 완료 후 반드시 plan.md 업데이트

## 출력 형식

```
📍 현재 테스트: testMethodName
📝 설명: [테스트 설명]

🔴 Red: 테스트 작성 완료
🟢 Green: 구현 완료, 테스트 통과

✅ plan.md 업데이트 완료
📊 진행률: X/Y (Z%)
```
