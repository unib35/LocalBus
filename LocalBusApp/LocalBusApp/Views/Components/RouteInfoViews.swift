import SwiftUI
import UIKit
import MapKit
import CoreLocation

// MARK: - 정류장 화면 (디자인 캔버스 통합안 MapUnified · 펼침 ImprovedMapList)
//
// 지도 위 플로팅 노선 바(노선 칩 + 방향 스왑 + 현재 위치 + 노선 전체 보기).
// 아래 패널은 요약형: 선택 정류장 · 도보 거리 · 버스 선택 · 도착 예상 · 길 찾기 / 버스 상세.
// '정류장 N곳'을 누르거나 패널을 끝까지 올리면 정류장 목록(고른 버스 기준 통과 시각)으로 바뀐다.

// 좌표 없는 노선의 임시 폴백 (율하 노선 등)
private let fallbackCoordinates: [String: CLLocationCoordinate2D] = [
    "sasang_terminal": CLLocationCoordinate2D(latitude: 35.163329, longitude: 128.981845),
    "gimhae_foreign":  CLLocationCoordinate2D(latitude: 35.2257, longitude: 128.8928),
    "yulha_central":   CLLocationCoordinate2D(latitude: 35.2207, longitude: 128.8994),
]

// MARK: - 패널 문구

/// 정류장 패널에 쓰는 문구 조합.
enum StopsPanelText {
    /// "곧 출발" / "12분 후" / "1시간 후" / "1시간 12분 후"
    static func untilText(minutes: Int) -> String {
        if minutes <= 0 { return "곧 출발" }
        if minutes < 60 { return "\(minutes)분 후" }
        let rest = minutes % 60
        return rest == 0 ? "\(minutes / 60)시간 후" : "\(minutes / 60)시간 \(rest)분 후"
    }

    /// "정류장 6곳 · 26분 소요 · 20번 홈에서 탑승 · 07:20 버스 기준"
    static func listSummary(stopCount: Int, durationMinutes: Int, platform: String?, busTime: String?) -> String {
        var parts = ["정류장 \(stopCount)곳", "\(durationMinutes)분 소요"]
        if let platform { parts.append("\(platform)에서 탑승") }
        if let busTime { parts.append("\(busTime) 버스 기준") }
        return parts.joined(separator: " · ")
    }

    /// "도보 6분 (450m)". 걷는 속도는 약 80m/분.
    static func walkText(meters: Double) -> String {
        let distanceText = meters < 1000 ? "\(Int(meters))m" : String(format: "%.1fkm", meters / 1000)
        let walkMinutes = max(1, Int((meters / 80).rounded()))
        return "도보 \(walkMinutes)분 (\(distanceText))"
    }

    /// "출발 · 20번 홈 · 도보 6분 (450m)"
    static func departureDetail(platform: String?, walk: String?) -> String {
        (["출발"] + [platform, walk].compactMap { $0 }).joined(separator: " · ")
    }

    /// "종점 · 부산광역시 사상구 괘법동"
    static func destinationDetail(address: String?) -> String {
        (["종점"] + [address].compactMap { $0 }).joined(separator: " · ")
    }

    /// 정류장 통과 시각. 출발·종점은 고른 버스의 출발·도착 예상, 중간은 출발 기준 예상값.
    static func passTime(index: Int, count: Int, departure: String?, arrival: String) -> String {
        guard let departure else { return "--:--" }
        if index == 0 { return departure }
        if index == count - 1 { return arrival }
        return DateService.timeByAdding(minutes: index, to: departure) ?? "--:--"
    }
}

/// 토큰에 없는 패널 전용 색 (캔버스 값).
private enum MapPanelColor {
    private static func dynamic(dark: CGFloat, light: CGFloat) -> Color {
        Color(UIColor { trait in
            UIColor(white: trait.userInterfaceStyle == .dark ? dark : light, alpha: 1)
        })
    }

    /// 패널 손잡이 (#444444 / #C8C8C8)
    static let handle = dynamic(dark: 0.267, light: 0.784)
    /// 정류장 사이 연결선 (#333333 / #D4D4D4)
    static let track = dynamic(dark: 0.2, light: 0.831)
}

private struct PanelHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct StopsScreenView: View {
    @ObservedObject var viewModel: MainViewModel
    let presentationToken: Int

    @State private var selectedStop: BusStop? = nil
    @State private var centerOnUser = false
    @State private var fitToRoute = false
    @State private var userLocation: CLLocation? = nil
    @State private var showLocationDeniedAlert = false

    // 하단 패널 상태. 모달 시트가 아니라 뷰 안의 패널이라 탭 바가 가려지지 않는다.
    @State private var panelDetent: MapPanelDetent = .medium
    /// 요약 내용의 실제 높이. 패널이 버튼에서 끝나도록 중간 높이를 여기에 맞춘다.
    @State private var summaryHeight: CGFloat = 0

    // 패널에서 고른 버스와 상세 시트
    @State private var pickedBusTime: String? = nil
    @State private var mapBusDetail: BusDetailInfo? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var stopsDirection: RouteDirection { viewModel.selectedDirection }
    private var stops: [BusStop] { viewModel.getStops(for: stopsDirection) }
    private var platform: String? { viewModel.getPlatformNumber(for: stopsDirection) }
    private var selectedStopID: String? { selectedStop?.id }
    private var defaultStop: BusStop? { stops.first(where: \.isDeparture) ?? stops.first }

    private var selectedCoordinate: CLLocationCoordinate2D? {
        selectedStop.flatMap { coordinate(for: $0) }
    }

    /// 패널 중간 높이: 손잡이 + 요약 + 아래 여백
    private var mediumPanelHeight: CGFloat? {
        summaryHeight > 0 ? MapPanelDetent.handleAreaHeight + summaryHeight + 26 : nil
    }

    /// JSON 좌표 우선, 없으면 폴백 사용
    private func coordinate(for stop: BusStop) -> CLLocationCoordinate2D? {
        if let lat = stop.latitude, let lng = stop.longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        return fallbackCoordinates[stop.id]
    }

    private var mapPins: [RouteMapPin] {
        let currentStops = stops
        let count = currentStops.count
        return currentStops.enumerated().compactMap { index, stop in
            guard let coord = coordinate(for: stop) else { return nil }
            return RouteMapPin(
                coordinate: coord,
                stopID: stop.id,
                stopName: stop.name,
                subtitle: stop.isDeparture ? platform : nil,
                isDeparture: stop.isDeparture,
                isDestination: index == count - 1
            )
        }
    }

    private var mapRoutePath: [CLLocationCoordinate2D]? {
        viewModel.getRoutePath(for: stopsDirection)
    }

    private func handleStopSelection(_ stop: BusStop) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedStop = stop
        }
    }

    private func selectDefaultStopIfNeeded(force: Bool = false) {
        guard let defaultStop else {
            selectedStop = nil
            return
        }

        let currentSelectionIsValid = selectedStop.map { selected in
            stops.contains(where: { $0.id == selected.id })
        } ?? false

        guard force || !currentSelectionIsValid else { return }
        selectedStop = defaultStop
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.Color.screenBackground.ignoresSafeArea()

            // 지도 — 화면 전체. safe area 무시
            GeometryReader { geo in
                RouteMapView(
                    pins: mapPins,
                    routePath: mapRoutePath,
                    selectedStopID: selectedStopID,
                    selectedCoordinate: selectedCoordinate,
                    centerOnUser: $centerOnUser,
                    fitToRoute: $fitToRoute,
                    colorScheme: colorScheme,
                    sheetTopY: estimatedSheetTopY(for: geo.size.height),
                    onPinTap: { stopID in
                        guard let stop = stops.first(where: { $0.id == stopID }) else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedStop = stop
                            // 핀을 누르면 그 정류장 요약이 보이도록
                            if panelDetent != .medium { panelDetent = .medium }
                        }
                    },
                    onLocationUpdate: { location in
                        userLocation = location
                    },
                    onLocationDenied: {
                        showLocationDeniedAlert = true
                    }
                )
            }
            .ignoresSafeArea()

            floatingBar
                .padding(.horizontal, 16)
                .padding(.top, 4)

        }
        .overlay(alignment: .bottom) {
            MapBottomPanel(detent: $panelDetent, mediumHeight: mediumPanelHeight) {
                sheetContent
            }
        }
        .sheet(item: $mapBusDetail) { info in
            BusDetailView(
                info: info,
                alert: viewModel.alert(for: info.departureTime),
                onSetAlert: { lead, repeats in
                    await viewModel.setAlert(for: info.departureTime, leadMinutes: lead, repeatsWeekdays: repeats)
                },
                onRemoveAlert: {
                    if let alert = viewModel.alert(for: info.departureTime) { viewModel.removeAlert(id: alert.id) }
                },
                onRefreshTraffic: {
                    await viewModel.refreshTrafficDuration(force: true)
                    return viewModel.arrivalEstimate(for: info.departureTime)
                }
            )
        }
        .alert("위치 권한이 필요합니다", isPresented: $showLocationDeniedAlert) {
            Button("설정으로 이동") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("현재 위치를 보려면\n설정 > 장유시외버스 > 위치를 허용해주세요.")
        }
        .onAppear {
            selectDefaultStopIfNeeded()
        }
        .onChange(of: viewModel.selectedDirection) { _ in
            pickedBusTime = nil
            selectDefaultStopIfNeeded(force: true)
        }
        .onChange(of: stops.map(\.id)) { _ in
            // 시간표가 뒤늦게 로드되면 그때 기본 정류장을 고른다.
            selectDefaultStopIfNeeded()
        }
        .onChange(of: presentationToken) { _ in
            withAnimation(.easeInOut(duration: 0.25)) { panelDetent = .medium }
            selectDefaultStopIfNeeded()
        }
    }

    // MARK: - Sheet 높이 추정 (지도 핀 centering / 노선 fit 보정용)

    private func estimatedSheetTopY(for screenHeight: CGFloat) -> CGFloat {
        screenHeight - panelDetent.height(in: screenHeight, mediumHeight: mediumPanelHeight)
    }

    // MARK: - 플로팅 노선 바

    private var floatingBar: some View {
        HStack(spacing: 8) {
            MapRouteLineMenu(selectedLine: stopsDirection.routeLine) { line in
                viewModel.changeDirection(to: line.defaultDirection)
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.changeDirection(to: stopsDirection.opposite)
            } label: {
                HStack(spacing: 8) {
                    Text(stopsDirection.departureName)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.Color.tertiaryText)
                    Text(stopsDirection.arrivalName)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.Color.secondaryText)
                        .padding(.leading, 2)
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.Color.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .glassCard(in: Capsule(), fallback: AppTheme.Color.surface, interactive: true)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("방향 바꾸기: 현재 \(stopsDirection.displayName)")

            // 통합안 보드에는 없지만 내 위치로 가는 다른 길이 없어 남겨 둔다.
            mapControlButton(systemName: "location.fill", accessibilityLabel: "현재 위치로 이동") {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                centerOnUser = true
            }

            mapControlButton(systemName: "arrow.up.left.and.arrow.down.right", accessibilityLabel: "노선 전체 보기") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                fitToRoute = true
            }
        }
    }

    private func mapControlButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.Color.primaryText)
                .frame(width: 44, height: 44)
                .glassCard(in: Circle(), fallback: AppTheme.Color.surface, interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - 패널 콘텐츠

    @ViewBuilder
    private var sheetContent: some View {
        let currentStops = stops
        Group {
            if panelDetent == .large, !currentStops.isEmpty {
                stopListContent(currentStops)
                    .padding(.top, 2)
            } else if let stop = selectedStop {
                selectedStopSummary(stop: stop, stops: currentStops)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: PanelHeightKey.self, value: geo.size.height)
                        }
                    )
            } else if currentStops.isEmpty {
                emptyStopsView
            }
        }
        .padding(.horizontal, 20)
        .onPreferenceChange(PanelHeightKey.self) { height in
            guard height > 0, abs(height - summaryHeight) > 0.5 else { return }
            summaryHeight = height
        }
    }

    // MARK: - 선택 정류장 요약

    private func selectedStopSummary(stop: BusStop, stops currentStops: [BusStop]) -> some View {
        let isLast = currentStops.last?.id == stop.id
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text(stop.name)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if stop.isDeparture {
                    LabelChip(text: platform.map { "출발 · \($0)" } ?? "출발")
                } else if isLast {
                    LabelChip(text: "종점")
                }

                Spacer(minLength: 4)

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        panelDetent = .large
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text("정류장 \(currentStops.count)곳")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Color.secondaryText)
                    .padding(.horizontal, 8)
                    .frame(height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, -8)
                .accessibilityLabel("정류장 \(currentStops.count)곳 목록 펼치기")
            }
            .frame(height: 24)

            Text(stopMetaText(for: stop))
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Color.secondaryText)
                .lineLimit(1)
                .frame(height: 16)
                .padding(.top, 2)

            if stop.isDeparture {
                busPickerSection
                    .padding(.top, 10)
            }

            HStack(spacing: 10) {
                if coordinate(for: stop) != nil {
                    Button {
                        openMapsNavigation(for: stop)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.system(size: 16, weight: .semibold))
                            Text("길 찾기")
                        }
                    }
                    .buttonStyle(MapPrimaryButtonStyle())
                }

                if stop.isDeparture, let picked = pickedBusTimeToday {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        mapBusDetail = viewModel.makeBusDetailInfo(for: picked)
                    } label: {
                        HStack(spacing: 4) {
                            Text("버스 상세 · 알림")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle(height: 46))
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - 버스 선택 · 도착 예상

    /// 오늘 남은 버스 앞 4대
    private var pickerBusTimes: [String] {
        Array(viewModel.buildUpcomingBuses(limit: 4).filter { $0.statusKind != .nextDay }.map(\.departureTime))
    }

    /// 고른 버스. 고른 적이 없거나 이미 지나갔으면 남은 버스 중 첫 번째.
    private var pickedBusTimeToday: String? {
        let times = pickerBusTimes
        if let picked = pickedBusTime, times.contains(picked) { return picked }
        return times.first
    }

    /// 정류장 목록의 기준 버스. 오늘 남은 버스가 없으면 내일 첫차.
    private func basisBus(at date: Date) -> (time: String, isNextDay: Bool)? {
        if let picked = pickedBusTimeToday { return (picked, false) }
        let firstBus = viewModel.makeTimingSnapshot(at: date).firstBusTime
        guard DateService.timeByAdding(minutes: 0, to: firstBus) != nil else { return nil }
        return (firstBus, true)
    }

    private var busPickerSection: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let times = pickerBusTimes
            let snapshot = viewModel.makeTimingSnapshot(at: context.date)
            VStack(spacing: 8) {
                if times.isEmpty {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("오늘 운행 종료")
                                .font(AppTheme.Typography.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Color.secondaryText)
                            Text("내일 첫차 \(snapshot.firstBusTime)")
                                .font(AppTheme.Typography.rowTime)
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.Color.primaryText)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 66)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .secondarySurface(cornerRadius: 14)
                } else {
                    let picked = pickedBusTimeToday ?? times[0]
                    HStack(spacing: 8) {
                        ForEach(times, id: \.self) { time in
                            let isSelected = time == picked
                            Button {
                                UISelectionFeedbackGenerator().selectionChanged()
                                pickedBusTime = time
                            } label: {
                                Text(time)
                                    .font(.system(size: 14, weight: isSelected ? .bold : .semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(isSelected ? AppTheme.Color.screenBackground : AppTheme.Color.primaryText)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(isSelected ? AppTheme.Color.primaryText : AppTheme.Color.secondaryButton)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("버스 선택")

                    let estimate = viewModel.arrivalEstimate(for: picked, at: context.date)
                    let minutes = viewModel.minutesUntilDeparture(of: picked, isNextDay: false, at: context.date)
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("\(picked) 출발")
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AppTheme.Color.tertiaryText)
                                Text("약 \(estimate.arrivalTime) 도착")
                            }
                            .font(AppTheme.Typography.rowValue.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.Color.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                            HStack(spacing: 6) {
                                TrafficBasisDot(basis: estimate.basis)
                                Text("\(viewModel.isViaBus(for: picked) ? "경유 · " : "")\(estimate.basis.usesTraffic ? "현재 교통 반영" : "시간표 기준") · \(estimate.durationText)")
                            }
                            .font(AppTheme.Typography.footnote)
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.Color.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        }

                        Spacer(minLength: 4)

                        Text(StopsPanelText.untilText(minutes: minutes))
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.Color.accent)
                            .fixedSize()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 60)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .secondarySurface(cornerRadius: 14)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func walkText(for stop: BusStop) -> String? {
        guard let userLoc = userLocation, let coord = coordinate(for: stop) else { return nil }
        let meters = userLoc.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
        return StopsPanelText.walkText(meters: meters)
    }

    private func stopMetaText(for stop: BusStop) -> String {
        let parts = [stop.description, walkText(for: stop)].compactMap { $0 }
        return parts.isEmpty ? stopsDirection.displayName : parts.joined(separator: " · ")
    }

    // MARK: - 정류장 목록 (패널 펼침)

    private func stopListContent(_ currentStops: [BusStop]) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let basis = basisBus(at: context.date)
            let estimate = basis.map {
                viewModel.arrivalEstimate(for: $0.time, isNextDay: $0.isNextDay, at: context.date)
            }
            let count = currentStops.count

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Text(stopsDirection.departureName)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.Color.tertiaryText)
                        Text(stopsDirection.arrivalName)
                    }
                    .font(AppTheme.Typography.sheetTitle)
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(stopsDirection.displayName)
                    .accessibilityAddTraits(.isHeader)

                    Spacer(minLength: 8)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.changeDirection(to: stopsDirection.opposite)
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.Color.primaryText)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(AppTheme.Color.secondaryButton))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("방향 바꾸기: \(stopsDirection.opposite.displayName)")
                }
                .frame(height: 36)

                Text(StopsPanelText.listSummary(
                    stopCount: count,
                    durationMinutes: estimate?.durationMinutes ?? viewModel.currentDurationMinutes,
                    platform: platform,
                    busTime: basis?.time
                ))
                .font(AppTheme.Typography.caption)
                .monospacedDigit()
                .foregroundStyle(AppTheme.Color.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(height: 18)
                .padding(.top, 4)

                VStack(spacing: 0) {
                    ForEach(Array(currentStops.enumerated()), id: \.element.id) { index, stop in
                        let isSelected = stop.id == selectedStop?.id
                        let role: MapStopRow.Role = index == 0 ? .departure : (index == count - 1 ? .destination : .intermediate)
                        Button {
                            handleStopSelection(stop)
                        } label: {
                            MapStopRow(
                                time: StopsPanelText.passTime(
                                    index: index,
                                    count: count,
                                    departure: basis?.time,
                                    arrival: estimate?.arrivalTime ?? "--:--"
                                ),
                                name: stop.name,
                                detail: rowDetail(for: stop, role: role),
                                role: role,
                                isOnly: count == 1
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isSelected ? AppTheme.Color.surfaceSecondary : Color.clear)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                        .accessibilityHint("탭하면 지도에서 정류장 위치를 확인합니다")
                    }
                }
                .padding(.top, 14)

                if count > 2 {
                    Text("중간 정류장 시각은 출발 기준 예상값입니다 · 도로 사정에 따라 달라질 수 있어요")
                        .font(AppTheme.Typography.footnote)
                        .foregroundStyle(AppTheme.Color.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                }

                if let target = selectedStop ?? defaultStop, coordinate(for: target) != nil {
                    Button {
                        openMapsNavigation(for: target)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.system(size: 16, weight: .semibold))
                            Text("\(target.name) 길 찾기")
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(PrimaryButtonStyle(height: 50))
                    .padding(.top, 16)
                }
            }
        }
    }

    private func rowDetail(for stop: BusStop, role: MapStopRow.Role) -> String? {
        switch role {
        case .departure:
            return StopsPanelText.departureDetail(platform: platform, walk: walkText(for: stop))
        case .destination:
            return StopsPanelText.destinationDetail(address: stop.description)
        case .intermediate:
            return nil
        }
    }

    private var emptyStopsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("정류장 정보를 불러올 수 없습니다")
                .font(AppTheme.Typography.rowTitle)
                .foregroundStyle(AppTheme.Color.primaryText)
            Text("네트워크 연결을 확인하고 다시 시도해 주세요")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Color.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
    }

    private func openMapsNavigation(for stop: BusStop) {
        guard let coord = coordinate(for: stop) else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        item.name = stop.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault])
    }
}

// MARK: - 플로팅 바 노선 칩

/// 지도 위 "장유 노선 ▾" 칩. 옆 버튼들과 같은 높이 44의 알약.
private struct MapRouteLineMenu: View {
    let selectedLine: RouteLine
    let onSelect: (RouteLine) -> Void

    var body: some View {
        Menu {
            ForEach(RouteLine.allCases, id: \.self) { line in
                Button {
                    onSelect(line)
                } label: {
                    if line == selectedLine {
                        Label(line.displayName, systemImage: "checkmark")
                    } else {
                        Text(line.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedLine.displayName)
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(AppTheme.Color.primaryText)
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .frame(height: 44)
            .glassCard(in: Capsule(), fallback: AppTheme.Color.surface, interactive: true)
            .contentShape(Capsule())
        }
        .accessibilityLabel("노선 선택: \(selectedLine.displayName)")
    }
}

// MARK: - 패널 버튼

/// 요약 패널의 기본 버튼. 두 버튼이 나란히 놓이는 자리라 보조 버튼과 같은 높이 46, 모서리 12.
private struct MapPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(AppTheme.Color.accentForeground)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.secondaryButton, style: .continuous)
                    .fill(configuration.isPressed ? AppTheme.Color.accentPressed : AppTheme.Color.accent)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - 정류장 목록 행

/// 시각 → 마커(세로 연결선) → 이름·보조 줄. 높이 60.
private struct MapStopRow: View {
    enum Role {
        case departure, intermediate, destination
    }

    let time: String
    let name: String
    /// 출발·종점에만 붙는 보조 줄
    let detail: String?
    let role: Role
    /// 정류장이 하나뿐이면 연결선을 그리지 않는다.
    var isOnly: Bool = false

    private var isEndpoint: Bool { role != .intermediate }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(time)
                .font(.system(size: 13, weight: isEndpoint ? .semibold : .medium))
                .monospacedDigit()
                .foregroundStyle(isEndpoint ? AppTheme.Color.primaryText : AppTheme.Color.secondaryText)
                .frame(width: 40, alignment: .leading)

            marker
                .frame(width: 16, height: 60)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 16, weight: isEndpoint ? .bold : .medium))
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if let detail {
                    Text(detail)
                        .font(AppTheme.Typography.caption)
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.Color.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(height: 60)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var marker: some View {
        ZStack {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(role == .departure || isOnly ? Color.clear : MapPanelColor.track)
                Rectangle()
                    .fill(role == .destination || isOnly ? Color.clear : MapPanelColor.track)
            }
            .frame(width: 2)

            switch role {
            case .departure:
                Circle()
                    .fill(AppTheme.Color.accent)
                    .frame(width: 14, height: 14)
            case .intermediate:
                Circle()
                    .fill(AppTheme.Color.tertiaryText)
                    .frame(width: 8, height: 8)
            case .destination:
                Circle()
                    .fill(AppTheme.Color.surface)
                    .overlay(Circle().strokeBorder(AppTheme.Color.primaryText, lineWidth: 2.5))
                    .frame(width: 14, height: 14)
            }
        }
    }

    private var accessibilityText: String {
        ([name, "\(time) 통과 예상"] + [detail].compactMap { $0 }).joined(separator: ", ")
    }
}

// MARK: - 하단 패널 (뷰 안의 시트)

/// 지도 위 하단 패널의 높이 단계.
enum MapPanelDetent: Equatable {
    case peek, medium, large

    /// 손잡이 영역 높이 (위 8 + 손잡이 5 + 아래 8)
    static let handleAreaHeight: CGFloat = 21

    /// - Parameter mediumHeight: 요약 내용에 맞춘 중간 높이. nil이면 화면의 절반.
    func height(in containerHeight: CGFloat, mediumHeight: CGFloat? = nil) -> CGFloat {
        switch self {
        case .peek:
            return 132
        case .medium:
            guard let mediumHeight else { return containerHeight * 0.50 }
            return min(max(mediumHeight, 132), containerHeight * 0.60)
        case .large:
            return containerHeight * 0.88
        }
    }
}

/// 모달 `.sheet` 대신 쓰는 뷰 내부 패널. 탭 바와 지도 컨트롤을 가리지 않고, 손잡이를 끌어 높이를 바꾼다.
struct MapBottomPanel<Content: View>: View {
    @Binding var detent: MapPanelDetent
    /// 요약 내용에 맞춘 중간 높이
    var mediumHeight: CGFloat? = nil
    @ViewBuilder let content: () -> Content

    @State private var dragOffset: CGFloat = 0

    /// 목록을 펼치거나 요약으로 접는다.
    private func toggleExpanded() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            detent = detent == .large ? .medium : .large
        }
    }

    var body: some View {
        GeometryReader { geo in
            let containerHeight = geo.size.height
            let baseHeight = detent.height(in: containerHeight, mediumHeight: mediumHeight)
            let height = min(max(baseHeight - dragOffset, MapPanelDetent.peek.height(in: containerHeight)),
                             MapPanelDetent.large.height(in: containerHeight))

            VStack(spacing: 0) {
                Capsule()
                    .fill(MapPanelColor.handle)
                    .frame(width: 36, height: 5)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { toggleExpanded() }
                    .accessibilityElement()
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("정류장 패널 손잡이")
                    .accessibilityValue(detent == .large ? "펼침" : "접힘")
                    .accessibilityHint("누르거나 위아래로 끌어 패널 높이를 바꿉니다")
                    .accessibilityAction { toggleExpanded() }

                ScrollView(showsIndicators: false) {
                    content()
                        .padding(.bottom, 40)
                }
                .scrollDisabled(detent != .large)
            }
            .frame(width: geo.size.width, height: height, alignment: .top)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 20, style: .continuous)
                    .fill(AppTheme.Color.surface)
            )
            .clipShape(
                UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 20, style: .continuous)
            )
            .frame(maxHeight: .infinity, alignment: .bottom)
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        let projected = baseHeight - value.predictedEndTranslation.height
                        let candidates: [MapPanelDetent] = [.peek, .medium, .large]
                        let nearest = candidates.min {
                            abs($0.height(in: containerHeight, mediumHeight: mediumHeight) - projected)
                                < abs($1.height(in: containerHeight, mediumHeight: mediumHeight) - projected)
                        } ?? .medium
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            dragOffset = 0
                            detent = nearest
                        }
                    }
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: detent)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: mediumHeight)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Preview

#Preview {
    struct Wrapper: View {
        @StateObject var vm = MainViewModel()
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                Text("정류장 위치 (시뮬레이터에서 확인)")
                    .foregroundStyle(.white)
            }
        }
    }
    return Wrapper()
}
