# LocalBus → 장유사상버스 리브랜딩 / 출시 작업 추적

> 마지막 업데이트: 2026-08-31
> 상세 체크리스트(로컬 전용): `internal-docs/deploy/bundle-id-rebrand-checklist.md`

식별자 변경 요약:

| 항목 | 기존 | 변경 |
|------|------|------|
| 앱 Bundle ID | `kr.co.lee.LocalBusApp` | `kr.co.lee.jangyusasang` |
| 위젯 Bundle ID | `...LocalBusApp.LocalBusWidget` | `kr.co.lee.jangyusasang.widget` |
| 테스트 / UI테스트 | `...Tests` / `...UITests` | `kr.co.lee.jangyusasang.tests` / `.uitests` |
| App Group | `group.kr.co.lee.LocalBusApp` | `group.kr.co.lee.jangyusasang` |
| URL Scheme | `localbus` | `jangyusasang` |
| 문의/신고/정책 이메일 | `jm.jongminlee@gmail.com` | `jangyubus.app@gmail.com` |
| 데이터 contact_email | `help@localbus.com` | `jangyubus.app@gmail.com` |

---

## ✅ 한 일 (Done)

### 코드/설정 (커밋 완료)
- [x] 앱·위젯·테스트·UI테스트 Bundle ID 변경 (`project.pbxproj`)
- [x] App Group 변경 (`LocalBusApp.entitlements`, `LocalBusWidget.entitlements`, `EntitlementStore.swift`)
- [x] URL Scheme 변경 (`Info.plist`, `MainView.swift`, `LocalBusWidget.swift`)
- [x] `Info.plist` CFBundleURLName 변경
- [x] 문의/신고 수신 이메일 변경 (`ContactView.swift`, `ReportView.swift`)
- [x] 번들 `timetable.json` contact_email 변경
- [x] 정책 문서 이메일 변경 (`docs/privacy-policy.html`, `docs/terms.html`, `internal-docs/...`)
- [x] 시뮬레이터 빌드 검증 (`** BUILD SUCCEEDED **`, 코드 서명 없이)

---

## 🔒 보안 — GoogleService-Info.plist 노출 대응

> `GoogleService-Info.plist`가 `e98719c` 커밋부터 public 레포에 노출됨.
> Firebase iOS API 키는 앱 번들에 포함되는 값이라 서버 시크릿은 아니지만, 키 제한 필수.
> 히스토리는 유지하기로 결정(키 제한으로 충분).

- [x] git 추적 제외 + `.gitignore` 추가 (커밋 `8390f99`)
- [ ] **🔴 API 키 제한** (Google Cloud Console → API/서비스 → 사용자 인증 정보)
  - 애플리케이션 제한 → iOS 앱 → 번들 ID `kr.co.lee.jangyusasang` 추가
  - API 제한 → Firebase 사용 API만 허용
- [x] ~~🟡 Firebase App Check 활성화~~ — **해당 없음**. App Check는 Firestore·Storage·
  Functions·RTDB를 보호하는 기능으로 FCM 전달에는 관여하지 않음. 이 앱은 FCM만 사용
- [x] ~~🟡 Firestore/Storage 보안 규칙 점검~~ — **해당 없음**. 두 서비스 모두 미사용
  (SPM 의존성은 `FirebaseMessaging` 하나뿐)

> 2026-08-31 확인: 새 앱에도 **동일한 API 키가 재사용**됨(해시 대조 완료).
> 노출됐던 키가 그대로 살아 있으므로 위 키 제한은 반드시 적용할 것.

---

## 🔴 할 일 — 우선순위 1 (안 하면 실기기/배포 빌드 불가)

### Apple Developer Portal (developer.apple.com → Identifiers)

> ⛔ 2026-08-31 현재 developer.apple.com 점검 중이라 이 섹션 전체가 진행 불가.
> 점검 종료 후 재개할 것. 아래 항목이 막혀 있어 실기기 푸시 수신 검증까지 연쇄로 대기 중.

- [ ] App Group 식별자 등록: `group.kr.co.lee.jangyusasang`
- [ ] 앱 App ID 등록: `kr.co.lee.jangyusasang` (Push Notifications + App Groups 체크)
- [ ] 위젯 App ID 등록: `kr.co.lee.jangyusasang.widget` (App Groups 체크)
- [ ] Xcode 각 타깃 Signing & Capabilities 에러 해소 확인

### Firebase Console
- [x] iOS 앱 추가 (Bundle ID: `kr.co.lee.jangyusasang`) — 2026-08-31 완료.
  기존 프로젝트 `localbus-1bb75` 재사용, GOOGLE_APP_ID `1:440631868395:ios:76959c1c…`
- [x] 새 `GoogleService-Info.plist` 다운로드 → 기존 파일 교체 — 2026-08-31 완료.
  BUNDLE_ID·Xcode 타깃 일치, 번들 포함 위치, gitignore 처리 모두 검증
- [x] **APNs 인증 키 등록** — 2026-08-31 완료.
  키 파일 `~/Documents/프로젝트/LocalBus/AuthKey_4BA3D656ZX.p8`,
  Key ID `4BA3D656ZX`, Team ID `AMNS6W2AA9`
  - ⚠️ `.p8`은 재다운로드 불가. 해당 폴더 밖에 백업 사본을 둘 것
- [ ] 옛 앱(`kr.co.lee.LocalBusApp`) 삭제 — **푸시 수신 확인 후에** 진행

---

## 🟡 할 일 — 우선순위 2 (출시 준비)

### App Store Connect
- [ ] 기존 `kr.co.lee.LocalBusApp` 앱 레코드 삭제 (미출시 상태일 때)
- [ ] 새 Bundle ID로 앱 생성
- [ ] 앱 이름 `장유사상버스` 입력 (중복 시 `장유-사상 시외버스` 등으로 변형)
- [ ] 개인정보처리방침 URL·문의 이메일 등 메타데이터 입력

### 원격 데이터 (GitHub: unib35/LocalBus)
- [x] 원격 `timetable.json`의 `contact_email`도 `jangyubus.app@gmail.com`으로 수정
  (2026-07-19 확인: 원격 v3에 반영 완료, 로컬 번들과 동일)
- [x] GitHub Pages 개인정보처리방침/이용약관 재배포 (2026-07-19 확인: 3개 URL 모두 200)

---

## 🔍 출시 전 점검 결과 (2026-07-19)

### 고친 것 (커밋 완료)
- [x] 테스트 스킴에 Testables 누락 → `xcodebuild test` 자체가 불가능했던 문제 수정
- [x] 제품명 리네임(JangyuBus) 미반영: TEST_HOST·TEST_TARGET_NAME·`@testable import` 수정
- [x] 깨져 있던 테스트(RouteData `path` 필드 누락) 수정 → **74개 테스트 전부 통과**
- [x] 앱·위젯 `PrivacyInfo.xcprivacy` 추가 (UserDefaults required-reason API 신고, 번들 포함 확인)

### 새로 발견 — 출시 전 결정/조치 필요
- [x] ~~🔴 `GoogleService-Info.plist`의 BUNDLE_ID가 옛 `kr.co.lee.LocalBusApp`~~
  → 2026-08-31 새 앱 등록 및 plist 교체 완료. 실제 푸시 수신은 APNs 키 등록 후 검증
- [x] ~~🟡 위젯 배포 타깃이 18.5 (앱은 16.0)~~ → 2026-08-31 **17.0으로 하향** (`476c967`).
  위젯이 요구하는 최신 API가 `AppIntentConfiguration`·`containerBackground(for:)`로
  둘 다 iOS 17.0 기준이라 16.0까지는 못 내림(내리려면 위젯 구성을 폴백 구조로 재작성해야 함).
  Live Activity 코드는 이미 `@available(iOS 16.2)` 가드됨. 빌드 검증 완료(경고 0)
- [x] ~~🟡 미커밋 WIP: `Secrets.xcconfig`를 Resources 빌드 단계에서 제외한 변경(pbxproj)~~
  → 2026-08-31 커밋 완료 (`72f351d`)
- [x] ~~🔴 카카오 REST API 키가 앱에 임베드됨~~ — **오판이었음. 실제로는 임베드되지 않는다.**
  `INFOPLIST_KEY_KakaoRestAPIKey`는 빌드 설정으로는 정상 해석되지만, Xcode의
  `GENERATE_INFOPLIST_FILE`은 알려진 Info.plist 키만 주입하고 커스텀 키는 조용히 버린다.
  - 2026-08-31 시뮬레이터 빌드로 검증: 생성된 Info.plist 40개 키에 `KakaoRestAPIKey` 없음,
    앱 바이너리·번들 어느 파일에서도 키 문자열 미검출
  - 키가 번들에 들어가던 유일한 경로는 `Secrets.xcconfig` 원본 복사였고 `72f351d`로 해소됨
  - `Secrets.xcconfig`는 git 히스토리에 커밋된 적 없음 → **유출 없음, 보안 이슈 종결**
- [ ] 🟡 **[보류] 실시간 교통 기능이 동작한 적 없음** — 위와 같은 이유로
  `TrafficService.swift:45`의 `Bundle.main.object(forInfoDictionaryKey: "KakaoRestAPIKey")`가
  항상 `nil` → `apiKey`가 빈 문자열 → `Authorization: KakaoAK ` 로 요청 → 401.
  실패 시 `nil`만 반환하는 구조라 표면화되지 않았다.
  - 2026-08-31 **보류 결정.** 출시에 필수가 아니므로 이번 트랙에서 다루지 않는다
  - 되살릴 경우: `LocalBusApp/Info.plist`에 `KakaoRestAPIKey = $(KAKAO_REST_API_KEY)`를 직접 넣고
    pbxproj의 `INFOPLIST_KEY_KakaoRestAPIKey` 2줄(Debug/Release) 제거.
    단 그 순간 키가 실제로 앱에 임베드되므로 프록시/쿼터 제한 등 대책을 함께 결정할 것
- [ ] 🟡 카카오 REST API 키 재발급 — 2026-08-31 작업 중 터미널 출력에 키 값이 노출됨.
  현재 어디서도 동작하지 않는 키라 교체 비용 없음
- [x] ~~🟡 빈 에셋 폴더 정리: `SplashMark.imageset`, `LaunchBackground.colorset`~~
  → **정리할 것 없음.** 2026-08-31 재확인 결과 둘 다 정상 상태다.
  `SplashMark.imageset`은 `splash-mark.png`를 담고 있고,
  `LaunchBackground.colorset`은 Contents.json에 색상값(srgb 0.067)이 인라인으로 정의돼 있다.
  실제로 값이 비어 있는 건 `AccentColor.colorset`(앱·위젯)과 `WidgetBackground.colorset`인데,
  셋 다 Xcode가 생성하는 기본 템플릿이고 비어 있는 게 정상 동작(시스템 기본값 사용)이라 유지.
- [ ] 🟢 App Store Connect 개인정보 설문: 수집 데이터 "없음" 기준으로 작성
  (FCM 토큰은 Firebase SDK 매니페스트가 커버, 앱 자체 수집 없음)

---

## 🟢 할 일 — 우선순위 3 (검증)

- [x] ~~시뮬레이터 Clean Build~~ — 2026-08-31 `** BUILD SUCCEEDED **` (경고 0).
  새 `GoogleService-Info.plist` 번들 포함·Bundle ID 일치·`Secrets.xcconfig` 미포함·
  위젯 embed 모두 확인
- [ ] `build/` 캐시 삭제 후 Clean Build 성공 (실기기)
  - ⚠️ `LocalBusApp/build/Release-iphoneos/LocalBusApp.app/Secrets.xcconfig`에 4월 6일자
    빌드 잔재로 키가 평문 잔존 → `build/` 삭제 시 함께 정리됨
- [ ] 위젯 추가 → 데이터 정상 표시 (App Group 공유 확인)
- [ ] 위젯 탭 → 앱 열리고 해당 방향 이동 (URL Scheme `jangyusasang://`)
- [ ] 문의/신고 화면 수신 이메일 확인
- [ ] 푸시 알림 수신 테스트

---

## 🎨 Liquid Glass 디자인 개선 (iOS 26)

> 배경: `liquidGlass` 헬퍼가 45곳에 적용돼 있으나, 불투명 배경 위에 글래스를 얹는 구조라
> iOS 26 기기에서도 글래스가 가려져 보이지 않음. 아래 순서대로 진행.

- [x] 1. **글래스 레이어링 수정** — `glassCard(cornerRadius:fallback:)` 헬퍼 도입.
  iOS 26+는 글래스만, 이하 버전은 불투명 배경 폴백.
  기존 `.background + .clipShape + .liquidGlass` 3줄 패턴 전면 교체
  (히어로/운행종료 카드는 흰 텍스트 전제의 어두운 앵커라 불투명 유지)
- [x] 2. **시스템 크롬 복원** — `legacyToolbarBackground` 헬퍼로 iOS 26에서는
  시스템 글래스 바 노출, `tabBarMinimizeBehavior(.onScrollDown)`,
  `scrollEdgeEffectStyle(.soft)` 적용
- [x] 3. **인터랙티브 글래스** — 지도 컨트롤·결제 CTA·알림 벨 버튼 `.interactive()`,
  NEXT 배지·탑승홈 배너·재시도 버튼 tint 글래스
- [x] 4. **`GlassEffectContainer` 도입** — `GlassGroup` 래퍼로 홈 화면 글래스 요소 블렌딩
- [x] 5. **배경 레이어** — `AmbientBackground` (모노크롬 명도 블롭) 전 화면 적용
- [ ] 6. (선택) **iOS 16~25 폴백 개선** — 불투명 색 대신 Material로 유사 질감.
  `glassCard(fallback:)` 인자만 바꾸면 되도록 구조는 준비됨. 구형 기기 시각 QA 후 결정
- [ ] 7. (정리) 미사용 레거시 컴포넌트 삭제 검토 — `LiveCountdownCard`,
  `LoadingCard`, `EndOfServiceCard`, `OfflineBanner`, `NoticeBanner` (사용처 없음)

---

## 📌 진행 중 / 별도 트랙 (참고)

> 리브랜딩과 무관하게 작업 트리에 함께 있던 미커밋 작업. 이번에 함께 커밋됨.

- [ ] 인앱 결제 / Paywall (`StoreService`, `PaywallView`, `EntitlementStore`, `Products.storekit`) — 상태 점검 필요
- [ ] 전반 UI 디자인 개선 (Views/Components 다수)
- [ ] 앱 아이콘 적용
