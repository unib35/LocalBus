# LocalBus → 장유사상버스 리브랜딩 / 출시 작업 추적

> 마지막 업데이트: 2026-06-26
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
- [ ] 🟡 Firebase App Check 활성화 (DeviceCheck/App Attest)
- [ ] 🟡 Firestore/Storage 보안 규칙 점검 (무인증 read/write 차단 여부)

---

## 🔴 할 일 — 우선순위 1 (안 하면 실기기/배포 빌드 불가)

### Apple Developer Portal (developer.apple.com → Identifiers)
- [ ] App Group 식별자 등록: `group.kr.co.lee.jangyusasang`
- [ ] 앱 App ID 등록: `kr.co.lee.jangyusasang` (Push Notifications + App Groups 체크)
- [ ] 위젯 App ID 등록: `kr.co.lee.jangyusasang.widget` (App Groups 체크)
- [ ] Xcode 각 타깃 Signing & Capabilities 에러 해소 확인

### Firebase Console
- [ ] iOS 앱 추가 (Bundle ID: `kr.co.lee.jangyusasang`)
- [ ] 새 `GoogleService-Info.plist` 다운로드 → 기존 파일 교체
- [ ] (FCM 사용 시) APNs 인증 키 등록 확인

---

## 🟡 할 일 — 우선순위 2 (출시 준비)

### App Store Connect
- [ ] 기존 `kr.co.lee.LocalBusApp` 앱 레코드 삭제 (미출시 상태일 때)
- [ ] 새 Bundle ID로 앱 생성
- [ ] 앱 이름 `장유사상버스` 입력 (중복 시 `장유-사상 시외버스` 등으로 변형)
- [ ] 개인정보처리방침 URL·문의 이메일 등 메타데이터 입력

### 원격 데이터 (GitHub: unib35/LocalBus)
- [ ] 원격 `timetable.json`의 `contact_email`도 `jangyubus.app@gmail.com`으로 수정
  - ⚠️ 앱은 원격 JSON 우선 사용 → 안 바꾸면 앱에 옛 이메일 계속 노출
- [ ] GitHub Pages 개인정보처리방침/이용약관 재배포

---

## 🟢 할 일 — 우선순위 3 (검증)

- [ ] `build/` 캐시 삭제 후 Clean Build 성공 (실기기)
- [ ] 위젯 추가 → 데이터 정상 표시 (App Group 공유 확인)
- [ ] 위젯 탭 → 앱 열리고 해당 방향 이동 (URL Scheme `jangyusasang://`)
- [ ] 문의/신고 화면 수신 이메일 확인
- [ ] 푸시 알림 수신 테스트

---

## 🎨 Liquid Glass 디자인 개선 (iOS 26)

> 배경: `liquidGlass` 헬퍼가 45곳에 적용돼 있으나, 불투명 배경 위에 글래스를 얹는 구조라
> iOS 26 기기에서도 글래스가 가려져 보이지 않음. 아래 순서대로 진행.

- [ ] 1. **글래스 레이어링 수정** — `glassCard(cornerRadius:fallback:)` 헬퍼 도입.
  iOS 26+는 글래스만, 이하 버전은 불투명 배경 폴백.
  기존 `.background + .clipShape + .liquidGlass` 3줄 패턴 전면 교체
  (히어로 카드는 콘텐츠 앵커로 불투명 유지)
- [ ] 2. **시스템 크롬 복원** — iOS 26에서 `toolbarBackground` 강제 지정 제거,
  `tabBarMinimizeBehavior(.onScrollDown)`, `scrollEdgeEffectStyle(.soft)` 적용
- [ ] 3. **인터랙티브 글래스** — 탭 요소 `.interactive()`, CTA `.glassProminent`,
  미사용 `liquidGlassButton()` 실제 적용, 상태 배지 tint 글래스
- [ ] 4. **`GlassEffectContainer` 도입** — 방향 선택 칩·버스 카드 리스트 등
  인접 글래스 요소 블렌딩/모핑
- [ ] 5. **배경 레이어** — 플랫 단색 배경 위 은은한 그라데이션 추가 (글래스 굴절 대상 확보)
- [ ] 6. (선택) **iOS 16~25 폴백 개선** — 불투명 색 대신 Material로 유사 질감

---

## 📌 진행 중 / 별도 트랙 (참고)

> 리브랜딩과 무관하게 작업 트리에 함께 있던 미커밋 작업. 이번에 함께 커밋됨.

- [ ] 인앱 결제 / Paywall (`StoreService`, `PaywallView`, `EntitlementStore`, `Products.storekit`) — 상태 점검 필요
- [ ] 전반 UI 디자인 개선 (Views/Components 다수)
- [ ] 앱 아이콘 적용
