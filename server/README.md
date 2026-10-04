# 도착예상 서버

주 1회 교통 예측을 수집하고 공통 JSON을 생성하는 TypeScript 작업 공간입니다.
실제 차량 위치나 출발 지연을 추적하는 실시간 버스 서버는 아닙니다.
Orca 작업폴더에 있던 구현 초안을 2026-09-29 실제 저장소로 복원했습니다.

## 기술 선택

2026-09-29 사용자 결정으로 서버 구현 언어를 TypeScript로 확정했습니다.
현재 개발 도구인 Node.js와 pnpm을 유지하며 기존 수집기와 테스트를 발전시킵니다.
현재 범위는 외부 HTTP 요청과 JSON 처리가 중심인 주간 배치이며,
기존 구현을 활용해 데이터 검증·실패 복구·앱 연동을 완성하는 데 우선순위를 둡니다.
운영 실행 환경과 저장소/CDN은 아직 미정입니다. TypeScript 선택이
Cloudflare Workers 채택을 의미하지는 않습니다.

## 로컬 실행

Node.js 22.18 이상과 pnpm을 사용합니다. 저장소 루트에서 실행합니다.

```sh
pnpm --dir server install --frozen-lockfile
pnpm --dir server check
pnpm --dir server test
pnpm --dir server plan
pnpm --dir server demo
```

- `plan`: 다음 날부터 7일의 수집 계획·요청 수 출력. 외부 API 호출 없음.
- `demo`: 합성 응답으로 수집·검증·파일 게시 흐름 실행. 외부 API 호출 없음.
- 날짜를 고정하려면 `pnpm --dir server plan 2026-10-05`처럼 전달합니다.
  demo는 미래 출발 슬롯을 대상으로 하므로 재검증 시 현재 이후 날짜를 사용합니다.
- demo 결과는 `server/dist/demo/`에 생성됩니다. 생성물은 Git에서 제외됩니다.

## 구조

| 경로 | 역할 |
|---|---|
| `src/cli.ts` | plan/demo/collect 진입점 |
| `src/contract.ts` | 스냅샷 타입·검증·KST 날짜 유틸리티 |
| `src/schedule.ts` | 날짜·노선·경유편별 수집 슬롯 |
| `src/provider.ts` | 외부 예측 API 어댑터·반환 경로 검사 |
| `src/collect.ts` | 요청 예산·재시도·누락 처리 |
| `src/checkpoint.ts` | 성공 표본 중간 저장·재실행 시 재사용 대상 검증 |
| `src/store.ts` | 로컬 파일 저장·잠금·스냅샷 게시 |
| `config/routes.json` | 노선·경유편·보정·수집 간격·검증 상태 |
| `schemas/arrival-estimates.schema.json` | 앱과 서버의 데이터 계약 |
| `fixtures/` | 합성 스냅샷 |
| `test/` | 계약·스케줄·오류·게시 검증 |

[설계](arrival-estimate-design.md)와 [구현 계획](implementation-plan.md)을 기준으로 진행합니다.
기존 시간표는 `../LocalBusApp/LocalBusApp/Resources/timetable.json`을 읽으며 위치를 유지합니다.

## 현재 구현과 남은 작업

로컬 수집기와 합성 테스트가 있으며, 운영 서버·관리자 API·예약 배포는 아직 없습니다.
현재 Node 파일 시스템을 사용하므로 Cloudflare Workers에 그대로 배포할 수 없습니다.
실행기·저장소를 확정한 뒤 해당 환경의 예약 실행 및 저장소 어댑터를 구현합니다.

실 API 모드 `pnpm --dir server collect`는 `KAKAO_REST_API_KEY` 환경변수,
`usageApproved: true`, 검증된 노선 설정을 요구합니다. 현재는 모든 경로가 미검증 상태입니다.
키는 실행 환경의 비밀값 저장소에서 주입하며 CLI는 `.env`를 자동으로 읽지 않습니다.
이번 정리에서는 실 API 호출과 배포를 수행하지 않았습니다.

다음 구현 순서:

1. 제공사 저장·공유 조건과 실제 경로·쿼터 확인 결과 기록.
2. 공통 fixture 확장 및 구현 계획 P1/P2의 남은 완료 조건 검증.
3. 현재 앱 구조에 맞춰 스냅샷 캐시·운행편별 계산 이식 (보존 위치는
   [정리 기록](../documentation/repository-organization.md) 참고).
4. 예약 실행·객체 저장소/CDN·관측 및 롤백 구현.

관리자 웹은 후속 범위인 `../admin/`에 분리합니다. 외부 API 결과의 공유·보관 범위는
제공사 이용조건 확인 결과에 따라 확정합니다.

## 수집 중단과 복구

성공한 표본은 각 응답 처리 후 `dist/demo/checkpoint.json` 또는
`dist/live/checkpoint.json`에 원자적으로 저장합니다. 같은 시작 날짜로 재실행하면
공개 결과와 중간 저장에서 성공 표본을 재사용하고 누락된 슬롯을 요청합니다.
노선·보정 버전, 보정값, 출처가 다르거나 만료된 데이터는 재사용하지 않습니다.
API 응답 수신과 중간 저장 사이에 강제 종료되면 해당 마지막 요청은 다시 발생할 수 있습니다.

완료된 수집의 `last-run.json`에는 슬롯별 실패 원인이 기록됩니다.
`provider-401/403/429`, `request-budget-exhausted`, `monthly-budget-exhausted`,
`provider-422`, `provider-5xx`, `past-departure`를 구분합니다.
5xx는 최대 2회 재시도하며 저장 오류·깨진 예산 장부·깨진 중간 저장 파일은 실행을 실패시킵니다.
이 오류들은 자동으로 파일을 초기화하거나 추가 API 호출로 우회하지 않습니다.

게시 이력 저장 후 최신 문서 갱신 전에 실패해도 같은 ID·동일 내용으로 게시를 재시도할 수 있습니다.
같은 ID의 다른 내용은 거부하며 기존 최신 문서를 유지합니다.

동시 수집은 `.collect.lock`으로 막습니다. 프로세스 강제 종료나 전원 중단 후에는
잠금 파일이 남을 수 있습니다. 실행 중인 수집기가 없는지 확인한 뒤 해당 출력 폴더의
잠금 파일만 정리하고 재실행합니다. 예산 장부와 중간 저장 파일은 유지합니다.
이 잠금은 단일 호스트용이며 분산 배포에서는 저장소의 조건부 쓰기 또는 분산 잠금이 필요합니다.
