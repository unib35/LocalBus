# SwiftUI Preview

Xcode에서 아래 Swift 파일을 열고 Editor > Canvas에서 Preview를 실행합니다.
앱 화면은 LocalBusApp 스킴, 위젯은 위젯 타깃 파일의 Preview를 사용합니다.

## 화면

- MainView: 전체 탭 앱, 라이트/다크. 설정에 필요한 StoreService 포함.
- LaunchScreenView: 시작 화면.
- TimetableViews: 번들 데이터를 이용한 전체 시간표.
- RouteInfoViews: 실제 정류장 지도·목록, 라이트/다크.
- BusDetailView: 일반 버스와 심야/알림 설정 상태.
- InfoView: 설정.
- BusTipsView: 버스 이용 안내.
- NoticeListView / NoticeDetailView: 공지 목록과 상세.
- ContactView / ReportView: 문의 및 시간표 제보.
- PrivacyPolicyView: 약관·개인정보 화면, 라이트/다크. 문서 본문은 레이아웃 확인용 샘플.
- PaywallView: Pro 혜택 및 상품 미연결 상태. 실제 구매는 StoreKit 테스트 환경에서 검증.
- ErrorView: 오류/재시도 화면.

## 구성 요소 및 위젯

- HomeDashboardViews: 정상 홈 카드, 로딩, 운행 종료.
- DirectionSelector: Preview 안에서 노선·방향 전환 가능.
- RouteMapView: 정류장 핀 지도.
- 기존 배너·버스 카드·시간표 공유 카드·정보 칩 Preview 유지.
- LocalBusWidget: small/medium/large 및 잠금화면 circular/rectangular/inline.
- BusLiveActivityView: 잠금화면, Dynamic Island expanded/compact/minimal. 출발 대기와 이동 중 상태.

## 실행 범위

XCODE_RUNNING_FOR_PREVIEWS가 설정된 Debug Canvas에서만 번들 시간표를 초기 상태로 사용하고 원격 시간표 확인, 교통 API 조회, 결제 상품 조회/거래 리스너, Firebase 초기화를 생략합니다. 앱의 일반 실행과 Release에서는 기존 동작을 유지합니다. MainView와 InfoView의 AppStorage는 Preview 전용 저장소를 사용합니다.
지도 배경 타일은 MapKit의 네트워크/캐시 상태에 따라 달라질 수 있습니다. Preview는 레이아웃 확인용이며 실제 결제, 알림 권한, 외부 메일 전송 검증을 대체하지 않습니다.
