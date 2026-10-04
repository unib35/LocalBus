# 실제 폴더 정리 기록

2026-09-29, 작업 위치: `/Users/lee/Developer/personal/LocalBus`.

## 반영한 변경

- `/Users/lee/orca/workspaces/LocalBus/codex/server/`의 소스·테스트·설계·설정·잠금 파일을 실제 폴더의 `server/`로 복원.
- 같은 작업폴더의 `admin/README.md`를 `admin/`으로 복원.
- `node_modules`, `dist`, 비밀값 파일은 복사하지 않고 잠금 파일로 개발 의존성 설치.
- 루트 TESTING·PREVIEWS·HOLIDAY_DATA 문서를 `documentation/ios/`로 이동.
- RELEASE_REVIEW 문서를 `documentation/releases/`로 이동.
- `release-audit/`를 `artifacts/release-audit/`로 이동하고 문서 링크 갱신.
- 기존 `LocalBusApp.zip`은 `archives/LocalBusApp.zip`으로 보존.

앱·Xcode 프로젝트·시간표·스크립트 경로는 유지합니다. 원격 시간표 URL과 GitHub Pages 경로도 유지합니다.
Orca CLI가 설치되어 있지 않아 Orca 상태 변경은 수행하지 않았습니다.

## 앱 연동 변경 보존

Orca codex 작업폴더의 앱 연동은 실제 폴더의 날짜 계산·Live Activity·화면 수정과 충돌합니다.
패치 적용 가능 여부만 검사했으며 앱 파일은 덮어쓰지 않았습니다.
전체 앱 브랜치를 병합하면 기존 개선이 유실될 수 있으므로, 후속 앱 연동에서 현재 구조에 맞게 이식해야 합니다.

실제 폴더의 로컬 보관 위치:

- `archives/orca-arrival-app-2026-09-29/tracked-app.patch`: 기존 파일에 대한 연동 변경.
- `archives/orca-arrival-app-2026-09-29/new-files/`: ArrivalEstimateSnapshot, ArrivalEstimateCalculator,
  ArrivalEstimateService 및 ArrivalEstimateTests 원본.

`archives/`는 Git에서 제외되므로 이 복원 자료는 이 컴퓨터에만 보관됩니다.
원본 Orca 작업폴더도 삭제·수정하지 않았습니다. 다른 UI 브랜치 전체의 병합은 이번 정리 범위에 포함하지 않습니다.

## 서버 상태

문서의 최초 상태는 구현 미착수였지만 실제 작업폴더에는 로컬 수집기 초안이 존재했습니다.
복원한 구현은 로컬 파일 게시 방식이며 운영 예약 실행·CDN 연결은 아직 없습니다.
이용조건·실제 경로 검증과 앱 연동 완료를 뜻하지 않습니다. 세부 상태는 `server/README.md`를 참고합니다.

## 복원 후 검증

- `pnpm --dir server check`: 타입 검사 통과.
- `pnpm --dir server test`: 7개 테스트 통과.
- `pnpm --dir server plan`: 2026-09-30부터 7일, 499개 요청 계획.
- `pnpm --dir server demo`: 합성 표본 499개, 실패 0개.
- `python3 scripts/check_release_config.py`: 출시 설정 검사 통과.
- 앱 Swift 파일과 Info.plist·Xcode 프로젝트 총 73개 파일의 작업 전후 SHA-256 일치.
- 서버 소스·설정·테스트 등 14개 파일의 Orca 원본과 복사본 일치 (갱신한 안내 문서 제외).
- 이동 문서의 로컬 링크 검사 통과. 앱 코드 변경이 없어 iOS 빌드·UI 테스트는 재실행하지 않음.
