---
allowed-tools: Bash(xcodebuild:*)
argument-hint: [test-class/test-method (optional)]
description: XCTest 테스트 실행
---

# Test

## Task

LocalBusApp 테스트를 실행하세요.

## 테스트 대상

$ARGUMENTS

## 테스트 명령

### 전체 테스트 (인자 없을 때)

```bash
xcodebuild test \
  -project LocalBusApp/LocalBusApp.xcodeproj \
  -scheme LocalBusApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:JangyuBusTests \
  2>&1 | grep -E "(Test Case|passed|failed|error:)"
```

### 특정 테스트 (인자 있을 때)

```bash
xcodebuild test \
  -project LocalBusApp/LocalBusApp.xcodeproj \
  -scheme LocalBusApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:JangyuBusTests/$ARGUMENTS \
  2>&1 | grep -E "(Test Case|passed|failed|error:)"
```

## 결과 형식

```
🧪 테스트 결과
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ 통과: X개
❌ 실패: Y개

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[실패한 테스트가 있다면]
❌ testMethodName
   Expected: ...
   Actual: ...
```

## 실패 시 조치

1. 실패 원인 분석
2. 관련 코드 확인
3. 수정 방안 제시
