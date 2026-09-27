import SwiftUI
import UIKit
import MapKit
import CoreLocation

// MARK: - 정류장 화면 (디자인 캔버스 개선안)
//
// 지도 위 플로팅 노선 바(노선 칩 + 방향 스왑 + 현재 위치), 아래 시트는 요약형:
// 선택 정류장 · 탑승홈 · 도보 거리 · 다음 버스 · 길 찾기. 펼치면 정류장 목록(통과 시각).
// 요금 카드는 버스 상세 시트로 이관.

// 좌표 없는 노선의 임시 폴백 (율하 노선 등)
private let fallbackCoordinates: [String: CLLocationCoordinate2D] = [
    "sasang_terminal": CLLocationCoordinate2D(latitude: 35.163329, longitude: 128.981845),
    "gimhae_foreign":  CLLocationCoordinate2D(latitude: 35.2257, longitude: 128.8928),
    "yulha_central":   CLLocationCoordinate2D(latitude: 35.2207, longitude: 128.8994),
]

struct StopsScreenView: View {
    @ObservedObject var viewModel: MainViewModel
    let presentationToken: Int

    @State private var selectedStop: BusStop? = nil
    @State private var centerOnUser = false
    @State private var fitToRoute = false
    @State private var userLocation: CLLocation? = nil

    // 하단 패널 상태. 모달 시트가 아니라 뷰 안의 패널이라 탭 바가 가려지지 않는다.
    @State private var panelDetent: MapPanelDetent = .medium

    @Environment(\.colorScheme) private var colorScheme

    private var stopsDirection: RouteDirection { viewModel.selectedDirection }
    private var stops: [BusStop] { viewModel.getStops(for: stopsDirection) }
    private var platform: String? { viewModel.getPlatformNumber(for: stopsDirection) }
    private var selectedStopID: String? { selectedStop?.id }
    private var defaultStop: BusStop? { stops.first(where: \.isDeparture) ?? stops.first }

    private var selectedCoordinate: CLLocationCoordinate2D? {
        selectedStop.flatMap { coordinate(for: $0) }
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
                            if panelDetent == .peek { panelDetent = .medium }
                        }
                    },
                    onLocationUpdate: { location in
                        userLocation = location
                    }
                )
            }
            .ignoresSafeArea()

            floatingBar
                .padding(.horizontal, 16)
                .padding(.top, 4)

        }
        .overlay(alignment: .bottom) {
            MapBottomPanel(detent: $panelDetent) {
                sheetContent
            }
        }
        .onAppear {
            selectDefaultStopIfNeeded()
        }
        .onChange(of: viewModel.selectedDirection) { _ in
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
        screenHeight - panelDetent.height(in: screenHeight)
    }

    // MARK: - 플로팅 노선 바

    private var floatingBar: some View {
        HStack(spacing: 8) {
            RouteLineMenu(selectedLine: stopsDirection.routeLine) { line in
                viewModel.changeDirection(to: line.defaultDirection)
            }
            .frame(height: 44)

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
                .font(AppTheme.Typography.buttonLabelStrong)
                .foregroundStyle(AppTheme.Color.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .glassCard(in: Capsule(), fallback: AppTheme.Color.surface, interactive: true)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("방향 바꾸기: 현재 \(stopsDirection.displayName)")

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

    // MARK: - 시트 콘텐츠

    private var sheetContent: some View {
        let currentStops = stops
        return VStack(alignment: .leading, spacing: 0) {
            if let stop = selectedStop {
                selectedStopSummary(stop: stop, stops: currentStops)
            } else if currentStops.isEmpty {
                emptyStopsView
            }

            if !currentStops.isEmpty {
                stopListSection(currentStops)
                    .padding(.top, 28)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    // MARK: - 선택 정류장 요약

    private func selectedStopSummary(stop: BusStop, stops currentStops: [BusStop]) -> some View {
        let isLast = currentStops.last?.id == stop.id
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text(stop.name)
                    .font(AppTheme.Typography.sheetTitle)
                    .foregroundStyle(AppTheme.Color.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if stop.isDeparture {
                    LabelChip(text: platform.map { "출발 · \($0)" } ?? "출발")
                } else if isLast {
                    LabelChip(text: "종점")
                }

                Spacer(minLength: 0)
            }

            Text(stopMetaText(for: stop))
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Color.secondaryText)
                .lineLimit(1)
                .padding(.top, 4)

            if stop.isDeparture {
                nextBusRow
                    .padding(.top, 12)
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
                    .buttonStyle(PrimaryButtonStyle(height: 46))
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        panelDetent = panelDetent == .large ? .medium : .large
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("정류장 \(currentStops.count)곳")
                        Image(systemName: panelDetent == .large ? "chevron.down" : "chevron.up")
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                .buttonStyle(SecondaryButtonStyle(height: 46))
            }
            .padding(.top, 12)
        }
    }

    private func stopMetaText(for stop: BusStop) -> String {
        var parts: [String] = []
        if let address = stop.description { parts.append(address) }
        if let userLoc = userLocation, let coord = coordinate(for: stop) {
            let meters = userLoc.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
            let distanceText = meters < 1000 ? "\(Int(meters))m" : String(format: "%.1fkm", meters / 1000)
            let walkMinutes = max(1, Int((meters / 80).rounded()))   // 약 80m/분
            parts.append("도보 \(walkMinutes)분 (\(distanceText))")
        }
        return parts.isEmpty ? stopsDirection.displayName : parts.joined(separator: " · ")
    }

    /// 출발 정류장일 때 다음 버스 한 줄
    private var nextBusRow: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let snapshot = viewModel.makeTimingSnapshot(at: context.date)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.isServiceEnded ? "오늘 운행 종료" : "다음 버스")
                        .font(AppTheme.Typography.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Color.secondaryText)
                    if snapshot.isServiceEnded {
                        Text("내일 첫차 \(snapshot.firstBusTime)")
                            .font(AppTheme.Typography.rowTime)
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.Color.primaryText)
                    } else if let next = snapshot.nextBusTime {
                        Text("\(next) 출발 · \(snapshot.nextBusArrivalTime) \(viewModel.currentArrivalHubName) 도착")
                            .font(AppTheme.Typography.rowTime)
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.Color.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }

                Spacer(minLength: 8)

                if !snapshot.isServiceEnded {
                    Text(snapshot.nextBusMinuteDisplay.isEmpty
                         ? snapshot.nextBusCountdownDescription
                         : "\(snapshot.nextBusMinuteDisplay)\(snapshot.nextBusUnitDisplay) 후")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.Color.accent)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 56)
            .secondarySurface(cornerRadius: 14)
        }
    }

    // MARK: - 정류장 목록

    private func stopListSection(_ currentStops: [BusStop]) -> some View {
        let snapshot = viewModel.makeTimingSnapshot(at: Date())
        let departure = snapshot.nextBusTime
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("정류장")
                    .font(AppTheme.Typography.groupTitle)
                    .foregroundStyle(AppTheme.Color.primaryText)
                Spacer()
                if let departure {
                    Text("\(departure) 버스 기준")
                        .font(AppTheme.Typography.footnote)
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.Color.secondaryText)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(currentStops.enumerated()), id: \.element.id) { index, stop in
                    let isSelected = stop.id == selectedStop?.id
                    Button {
                        handleStopSelection(stop)
                    } label: {
                        StopTimelineRow(
                            name: stop.name,
                            time: estimatedPassTime(index: index, count: currentStops.count, departure: departure, arrival: snapshot.nextBusArrivalTime),
                            role: index == 0 ? .departure : (index == currentStops.count - 1 ? .destination : .intermediate)
                        )
                        .padding(.horizontal, 12)
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

            if currentStops.count > 2 {
                Text("중간 정류장 시각은 출발 기준 예상값입니다 · 도로 사정에 따라 달라질 수 있어요")
                    .font(AppTheme.Typography.footnote)
                    .foregroundStyle(AppTheme.Color.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func estimatedPassTime(index: Int, count: Int, departure: String?, arrival: String) -> String {
        guard let departure else { return "--:--" }
        if index == 0 { return departure }
        if index == count - 1 { return arrival }
        return DateService.timeByAdding(minutes: index, to: departure) ?? "--:--"
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

// MARK: - 하단 패널 (뷰 안의 시트)

/// 지도 위 하단 패널의 높이 단계.
enum MapPanelDetent: Equatable {
    case peek, medium, large

    func height(in containerHeight: CGFloat) -> CGFloat {
        switch self {
        case .peek: return 132
        case .medium: return containerHeight * 0.50
        case .large: return containerHeight * 0.88
        }
    }
}

/// 모달 `.sheet` 대신 쓰는 뷰 내부 패널. 탭 바와 지도 컨트롤을 가리지 않고, 손잡이를 끌어 높이를 바꾼다.
struct MapBottomPanel<Content: View>: View {
    @Binding var detent: MapPanelDetent
    @ViewBuilder let content: () -> Content

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let containerHeight = geo.size.height
            let baseHeight = detent.height(in: containerHeight)
            let height = min(max(baseHeight - dragOffset, MapPanelDetent.peek.height(in: containerHeight)),
                             MapPanelDetent.large.height(in: containerHeight))

            VStack(spacing: 0) {
                Capsule()
                    .fill(AppTheme.Color.secondaryButton)
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .accessibilityLabel("정류장 패널 손잡이")
                    .accessibilityHint("위아래로 끌어 패널 높이를 바꿉니다")

                ScrollView(showsIndicators: false) {
                    content()
                        .padding(.bottom, 40)
                }
                .scrollDisabled(detent != .large)
            }
            .frame(width: geo.size.width, height: height, alignment: .top)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 28, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 28, style: .continuous)
                    .fill(AppTheme.Color.sheetBackground)
                    .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: -4)
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
                            abs($0.height(in: containerHeight) - projected) < abs($1.height(in: containerHeight) - projected)
                        } ?? .medium
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            dragOffset = 0
                            detent = nearest
                        }
                    }
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: detent)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Sheet enhancements (iOS 16.4+ API 안전 적용)

private extension View {
    @ViewBuilder
    func sheetEnhancements() -> some View {
        if #available(iOS 16.4, *) {
            self
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationCornerRadius(28)
                .presentationContentInteraction(.scrolls)
        } else {
            self
        }
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
