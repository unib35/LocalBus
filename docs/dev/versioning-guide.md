# 버전 관리 가이드 (iOS App)

이 문서는 LocalBus iOS 앱의 버전 관리 방법을 설명합니다.

## 개요

iOS 앱은 두 가지 버전 번호를 관리합니다:

| 키                            | 설명                      | 예시     |
| ----------------------------- | ------------------------- | -------- |
| `CFBundleShortVersionString`  | 버전 (사용자에게 표시)    | `1.0.0`  |
| `CFBundleVersion`             | 빌드 번호 (내부 관리용)   | `1`, `2` |

### 위치

Xcode 프로젝트 설정:
- **TARGETS** → LocalBusApp → **General** → **Identity**
  - Version: `1.0.0`
  - Build: `1`

또는 `Info.plist` 직접 수정:
```xml
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>
<key>CFBundleVersion</key>
<string>1</string>
```

---

## Semantic Versioning

[SemVer](https://semver.org/lang/ko/) 규칙을 따릅니다: `MAJOR.MINOR.PATCH`

### 버전 범프 기준

| 타입    | 언제 사용?                          | 예시                  | 버전 변화     |
| ------- | ----------------------------------- | --------------------- | ------------- |
| `PATCH` | 버그 수정, UI 미세 조정             | 다음 버스 표시 버그 수정 | 1.0.0 → 1.0.1 |
| `MINOR` | 새로운 기능 추가 (하위 호환)        | 알림 기능 추가        | 1.0.0 → 1.1.0 |
| `MAJOR` | Breaking changes, 대규모 리디자인   | 앱 전면 개편          | 1.0.0 → 2.0.0 |

### LocalBus 버전 예시

| 변경 내용                              | 버전 변화     |
| -------------------------------------- | ------------- |
| 공휴일 판단 버그 수정                  | 1.0.0 → 1.0.1 |
| 운행 종료 안내 문구 개선               | 1.0.1 → 1.0.2 |
| 푸시 알림 기능 추가                    | 1.0.2 → 1.1.0 |
| 다크모드 지원                          | 1.1.0 → 1.2.0 |
| 다중 노선 지원 (앱 구조 변경)          | 1.2.0 → 2.0.0 |

---

## 빌드 번호 관리

### 기본 규칙

- **빌드 번호는 항상 증가**해야 합니다 (App Store 요구사항)
- 같은 버전이라도 빌드 번호는 다를 수 있습니다
- TestFlight 배포마다 빌드 번호 증가

### 빌드 번호 전략

#### 방법 1: 단순 증가 (권장)

```
Version 1.0.0, Build 1  → 첫 출시
Version 1.0.0, Build 2  → 버그 핫픽스 (심사 반려 후 재제출)
Version 1.0.1, Build 3  → 다음 업데이트
Version 1.1.0, Build 4  → 기능 추가
```

#### 방법 2: 버전별 리셋 + 날짜 기반

```
Version 1.0.0, Build 20260110  → 2026년 1월 10일
Version 1.0.1, Build 20260115  → 2026년 1월 15일
```

---

## 릴리즈 워크플로우

### 1. 개발 완료

```bash
# 모든 테스트 통과 확인
xcodebuild test -scheme LocalBusApp -destination 'platform=iOS Simulator,name=iPhone 15'
```

### 2. 버전 업데이트

Xcode에서:
1. **TARGETS** → LocalBusApp → **General**
2. **Version** 업데이트 (예: 1.0.0 → 1.0.1)
3. **Build** 증가 (예: 1 → 2)

### 3. 커밋 & 태그

```bash
# 버전 변경 커밋
git add .
git commit -m "[Release]: v1.0.1 (Build 2)"

# Git 태그 생성
git tag -a v1.0.1 -m "Version 1.0.1 - 공휴일 버그 수정"
git push origin main --tags
```

### 4. Archive & Upload

1. Xcode → **Product** → **Archive**
2. **Distribute App** → **App Store Connect**
3. TestFlight 또는 App Store 제출

---

## 버전 체크 (앱 내부)

앱에서 현재 버전을 표시하거나 확인할 때:

```swift
// 버전 정보 가져오기
let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

// 표시 예: "v1.0.0 (1)"
let versionString = "v\(version) (\(build))"
```

---

## 데이터 버전 관리

LocalBus는 앱 버전과 별도로 **시간표 데이터 버전**도 관리합니다.

### JSON 데이터 버전

```json
{
  "meta": {
    "version": 1,
    "updated_at": "2026-01-10"
  }
}
```

| 필드         | 설명                                |
| ------------ | ----------------------------------- |
| `version`    | 데이터 스키마 버전 (구조 변경 시 증가) |
| `updated_at` | 시간표 최종 업데이트 날짜           |

### 데이터 버전 호환성

```swift
// 앱이 지원하는 데이터 버전
let supportedDataVersions = [1, 2]

// 데이터 로드 시 버전 체크
if !supportedDataVersions.contains(data.meta.version) {
    // 앱 업데이트 안내
}
```

---

## 체크리스트

### 릴리즈 전 확인사항

- [ ] 모든 테스트 통과
- [ ] Version 번호 업데이트
- [ ] Build 번호 증가
- [ ] 변경사항 커밋
- [ ] Git 태그 생성
- [ ] Archive 성공
- [ ] TestFlight 테스트 완료

### App Store 제출 시

- [ ] 스크린샷 최신화
- [ ] 앱 설명 업데이트 (변경사항 반영)
- [ ] "이 버전의 새로운 기능" 작성
- [ ] 빌드 제출 및 심사 요청

---

## 참고 자료

- [Semantic Versioning](https://semver.org/lang/ko/)
- [Apple: Version numbers and build numbers](https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleshortversionstring)
- [App Store Connect 가이드](https://developer.apple.com/app-store-connect/)
