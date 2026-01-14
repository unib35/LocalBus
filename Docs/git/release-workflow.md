# 릴리즈 워크플로우 (iOS App)

이 문서는 LocalBus iOS 앱의 릴리즈 워크플로우를 설명합니다.

## 브랜치 구조

```
main     ─────●─────────────●─────────────●────► (배포용, 안정 버전)
              ▲             ▲             ▲
              │ v1.0.0      │ v1.1.0      │ v1.2.0
              │             │             │
         ────●──●──●───────●──●──●───────●──●──●────►
              ▲  ▲  ▲       ▲  ▲  ▲       ▲  ▲  ▲
              │  │  │       │  │  │       │  │  │
              feature/      fix/          refactor/
              branches      branches      branches
```

## 릴리즈 시점

다음 조건을 만족할 때 릴리즈를 진행합니다:

- [ ] 배포할 기능들이 main에 모두 머지됨
- [ ] Xcode 빌드 성공
- [ ] 모든 테스트 통과
- [ ] 시뮬레이터/실기기 테스트 완료
- [ ] 릴리즈 노트 작성 준비 완료

---

## 릴리즈 워크플로우

### 1. 릴리즈 준비

```bash
# main 브랜치 최신화
git checkout main
git pull origin main

# 변경 내용 확인
git log --oneline v1.0.0..HEAD
```

### 2. 버전 업데이트

Xcode에서:
1. **TARGETS** → LocalBusApp → **General**
2. **Version** 업데이트 (예: 1.0.0 → 1.1.0)
3. **Build** 증가 (예: 1 → 2)

```bash
# 버전 변경 커밋
git add .
git commit -m "[Chore]: v1.1.0 릴리즈 준비"
git push origin main
```

### 3. 태그 생성

```bash
# 버전 태그 생성
git tag -a v1.1.0 -m "Release v1.1.0 - 다음 버스 자동 스크롤 기능"

# 태그 푸시
git push origin v1.1.0
```

### 4. Archive & Upload

1. Xcode → **Product** → **Archive**
2. Archive 완료 후 **Distribute App** 클릭
3. **App Store Connect** 선택
4. 업로드 완료 대기

### 5. GitHub 릴리즈 생성

```bash
gh release create v1.1.0 \
  --title "v1.1.0" \
  --notes "## What's Changed

### New Features
- 다음 버스 자동 스크롤 기능 추가
- 공지 배너 표시 기능

### Bug Fixes
- 공휴일 시간표 표시 버그 수정

### Improvements
- 오프라인 모드 안정성 개선

**Full Changelog**: https://github.com/username/LocalBus/compare/v1.0.0...v1.1.0"
```

### 6. App Store Connect

1. [App Store Connect](https://appstoreconnect.apple.com) 접속
2. 빌드 처리 완료 대기 (보통 5-30분)
3. 빌드 선택 → 메타데이터 작성
4. **심사 제출**

---

## 버전 규칙 (Semantic Versioning)

```
v{MAJOR}.{MINOR}.{PATCH}

예: v1.2.3
```

| 버전      | 변경 시점                     | 예시            |
| --------- | ----------------------------- | --------------- |
| **MAJOR** | Breaking changes, 대규모 변경 | v1.0.0 → v2.0.0 |
| **MINOR** | 새 기능 추가 (하위 호환)      | v1.0.0 → v1.1.0 |
| **PATCH** | 버그 수정, 핫픽스             | v1.0.0 → v1.0.1 |

### LocalBus 버전 예시

| 변경 내용                     | 버전 변화     |
| ----------------------------- | ------------- |
| 공휴일 버그 수정              | 1.0.0 → 1.0.1 |
| 다음 버스 자동 스크롤 추가    | 1.0.1 → 1.1.0 |
| 위젯 기능 추가                | 1.1.0 → 1.2.0 |
| 다중 노선 지원 (구조 변경)    | 1.2.0 → 2.0.0 |

---

## 핫픽스 워크플로우

App Store 배포 후 긴급 버그 발견 시:

```bash
# 1. main에서 핫픽스 브랜치 생성
git checkout main
git pull origin main
git checkout -b hotfix/critical-bug-fix

# 2. 버그 수정 & 커밋
git commit -m "[Fix]: 긴급 버그 수정"

# 3. main으로 PR 생성 및 머지
gh pr create --base main --head hotfix/critical-bug-fix
# 머지 후

# 4. 버전 업데이트 (패치 버전 증가)
# Xcode에서 Version: 1.1.0 → 1.1.1, Build 증가
git commit -m "[Chore]: v1.1.1 핫픽스 릴리즈"

# 5. 태그 생성
git tag -a v1.1.1 -m "Hotfix v1.1.1 - 긴급 버그 수정"
git push origin v1.1.1
git push origin main

# 6. Archive & App Store 제출 (긴급 심사 요청 가능)
```

---

## 심사 반려 대응

### 반려 시 워크플로우

```bash
# 1. 반려 사유 확인 후 수정
git checkout main
git checkout -b fix/app-review-rejection

# 2. 수정 & 커밋
git commit -m "[Fix]: App Store 심사 반려 사항 수정"

# 3. PR 생성 및 머지
gh pr create --base main --head fix/app-review-rejection

# 4. 빌드 번호만 증가 (버전은 동일)
# Xcode에서 Build: 2 → 3 (Version은 1.1.0 유지)
git commit -m "[Chore]: 빌드 번호 증가 (심사 재제출)"

# 5. Archive & 재제출
```

---

## 릴리즈 체크리스트

### 릴리즈 전

- [ ] main 브랜치 최신 상태 확인
- [ ] Xcode 빌드 성공
- [ ] 모든 테스트 통과
- [ ] 시뮬레이터 테스트 완료
- [ ] 실기기 테스트 완료 (가능한 경우)
- [ ] 버전 번호 결정
- [ ] 릴리즈 노트 작성

### 릴리즈 중

- [ ] Version & Build 번호 업데이트
- [ ] 버전 커밋
- [ ] Git 태그 생성 & 푸시
- [ ] Xcode Archive
- [ ] App Store Connect 업로드
- [ ] GitHub 릴리즈 생성

### 릴리즈 후

- [ ] App Store Connect 빌드 처리 확인
- [ ] 메타데이터 & 스크린샷 확인
- [ ] 심사 제출
- [ ] 심사 승인 후 출시
- [ ] 팀/사용자 공지

---

## App Store 메타데이터

### 앱 정보

| 항목 | 내용 |
|------|------|
| 앱 이름 | LocalBus |
| 부제 | 장유-사상 버스 시간표 |
| 카테고리 | 여행 또는 내비게이션 |
| 연령 등급 | 4+ |

### "이 버전의 새로운 기능" 예시

```
v1.1.0
- 다음 버스 자동 스크롤: 앱 실행 시 가장 가까운 버스로 자동 이동
- 공지 배너: 운행 변경사항 실시간 안내
- 오프라인 모드 개선: 네트워크 없이도 안정적 동작
- 버그 수정 및 성능 개선
```

---

## 참고

- [versioning-guide.md](../dev/versioning-guide.md) - 버전 관리 상세 가이드
- [micro-strategy.md](./micro-strategy.md) - 마이크로 브랜치 전략
- [commit.md](./commit.md) - 커밋 메시지 컨벤션
- [Semantic Versioning](https://semver.org/lang/ko/)
- [App Store Connect](https://appstoreconnect.apple.com)
