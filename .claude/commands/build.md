---
allowed-tools: Bash(xcodebuild:*)
description: Xcode 프로젝트 빌드
---

# Build

## Task

LocalBusApp Xcode 프로젝트를 빌드하세요.

## 빌드 명령

```bash
xcodebuild build \
  -project LocalBusApp/LocalBusApp.xcodeproj \
  -scheme LocalBusApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -quiet
```

## 결과 처리

### 성공 시
```
✅ 빌드 성공
```

### 실패 시
1. 에러 메시지 분석
2. 문제 원인 파악
3. 수정 방안 제시

## 일반적인 빌드 에러

| 에러 | 원인 | 해결 |
|------|------|------|
| `Cannot find type` | 타입 정의 누락 | import 확인 또는 타입 정의 |
| `Use of undeclared` | 변수/함수 미선언 | 선언 추가 |
| `Expected '}'` | 문법 에러 | 괄호 매칭 확인 |
