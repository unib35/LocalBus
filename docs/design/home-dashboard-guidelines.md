# Home Dashboard 디자인 가이드라인

## 목적

메인 홈 화면은 `Zero-Click Info`를 가장 먼저 보여주는 대시보드다.
사용자는 앱 실행 직후 아래 3가지를 즉시 읽을 수 있어야 한다.

1. 현재 어느 터미널 기준 화면인지
2. 다음 버스가 몇 분 후 출발하는지
3. 뒤이어 탈 수 있는 버스가 언제 오는지

기준 시안: Figma `BusTime Home Dashboard` (`node-id=1:2`)

## 디자인 원칙

1. 정보 우선순위는 `다음 버스 > 예정된 버스 > 공지` 순서를 유지한다.
2. 전체 화면은 다크 베이스를 사용하고, 강조는 흰색 텍스트와 제한된 그린 상태색만 사용한다.
3. 카드 내부 텍스트는 한 단계씩만 크기 차이를 둔다. 과도한 점프를 피한다.
4. 시간 정보는 항상 모노스페이스 숫자 계열로 표시해 세로 정렬이 흔들리지 않게 한다.
5. 배지와 상태 칩은 텍스트보다 작은 보조 정보로 취급한다.

## 컬러 토큰

구현 토큰: `HomeDashboardTheme`

| 토큰 | 값 | 용도 |
|---|---|---|
| `screenBackground` | `#02060F` | 전체 배경 |
| `segmentBackground` | `#0F172A` | 방향 선택 배경 |
| `cardBackground` | `#0B0F18` | 리스트 카드 |
| `heroStart` | `#06122E` | 메인 카드 그라디언트 시작 |
| `heroEnd` | `#0C1834` | 메인 카드 그라디언트 끝 |
| `noteBackground` | `#0A1630` | 안내 카드 |
| `border` | `#1F2937` | 카드/구분선 |
| `secondaryText` | `#9CA3AF` | 보조 텍스트 |
| `tertiaryText` | `#6B7280` | 비활성 탭 텍스트 |
| `success` | `#10B981` | 정시 운행 점 상태 |

## 타이포그래피

구현 토큰: `HomeDashboardTypography`

| 토큰 | 크기/두께 | 사용 위치 |
|---|---|---|
| `headerLabel` | `14 / Medium` | `현재 위치` 텍스트 |
| `segmentSelected` | `14 / Bold` | 선택된 방향 탭 |
| `segmentDefault` | `14 / Medium` | 비선택 방향 탭 |
| `heroEyebrow` | `12 / Medium` | `다음 버스` |
| `heroValue` | `72 / Black` | 메인 숫자 카운트다운 |
| `heroUnit` | `24 / Bold` | `분` |
| `heroDescription` | `14 / Medium` | `후 출발`, 종료 안내 보조 문구 |
| `heroMetaLabel` | `10 / Bold` | `출발 시간`, `잔여 좌석` |
| `heroMetaValue` | `20 / Bold Monospaced` | 메인 카드 하단 숫자 |
| `heroMetaSuffix` | `12 / Medium` | `석` |
| `sectionTitle` | `20 / Black` | `예정된 버스` |
| `sectionBadge` | `10 / Bold` | `실시간` 배지 |
| `busTime` | `18 / Bold Monospaced` | 예정 버스 출발 시간 |
| `busRelativeStrong` | `14 / Bold` | 첫 카드 상대 시간 |
| `busRelativeMuted` | `14 / Medium` | 후속 카드 상대 시간 |
| `busArrival` | `12 / Medium` | 도착 예정 문구 |
| `statusChip` | `12 / Medium` | 상태 칩 |
| `noticeTitle` | `14 / Bold` | 공지 제목 |
| `noticeBody` | `12 / Medium` | 공지 본문 |
| `tabLabelSelected` | `10 / Bold` | 선택된 하단 탭 |
| `tabLabelDefault` | `10 / Medium` | 비선택 하단 탭 |

## 레이아웃 규칙

1. 메인 콘텐츠 좌우 패딩은 `20pt`를 기본으로 유지한다.
2. 메인 카드와 섹션 사이 간격은 `24pt`를 유지한다.
3. 카드 기본 코너 반경은 `14pt`, 메인 히어로 카드는 `20pt`를 사용한다.
4. 방향 선택 내부 패딩은 `5pt`, 버튼 세로 패딩은 `12pt`를 유지한다.
5. 하단 탭 바는 화면 하단 safe area와 붙이고 상단 1px 보더를 둔다.

## 컴포넌트별 규칙

### 상단 헤더

* 왼쪽은 위치 아이콘 + `현재 위치: {터미널명}` 조합을 유지한다.
* 오른쪽은 배경 없는 벨 아이콘만 사용한다.

### 메인 히어로 카드

* 첫 줄은 `다음 버스`
* 두 번째 줄은 `숫자 + 분`
* 세 번째 줄은 `후 출발` 또는 `곧 출발`
* 하단 메타 정보는 반드시 2열: `출발 시간 / 잔여 좌석`

### 예정된 버스 카드

* 왼쪽은 원형 아이콘, 중앙은 `시간 + 도착 예정`, 오른쪽은 `상대 시간 + 상태 칩`
* 첫 카드 상대 시간은 흰색 강조, 뒤 카드들은 보조 텍스트 톤 사용
* 지연 상태는 경고 아이콘과 `5분 지연` 텍스트를 함께 사용

### 안내 카드

* 제목 1줄, 본문 2줄 이내를 기본으로 한다
* 본문은 `12pt` 기준으로 줄간격을 약간 넓혀 읽기성을 확보한다

## 구현 규칙

1. 홈 화면에서 새 텍스트 스타일이 필요하면 먼저 `HomeDashboardTypography`에 토큰을 추가한다.
2. 새 색상은 먼저 `HomeDashboardTheme`에 정의하고 직접 hex 값을 반복하지 않는다.
3. 시간, 좌석 수, 도착 예정 시각은 숫자 정렬을 위해 모노스페이스 숫자 스타일을 우선한다.
4. Figma 수정 반영 시 임의 추정값으로 조정하지 말고, 먼저 해당 노드의 폰트 크기와 weight를 확인한다.
