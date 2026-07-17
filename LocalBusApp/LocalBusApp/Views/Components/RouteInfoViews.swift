import SwiftUI
import UIKit
import MapKit
import CoreLocation

// MARK: - 정류장 화면

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

    // 시트 상태 (SwiftUI 표준 sheet)
    @State private var isSheetPresented: Bool = true
    @State private var sheetDetent: PresentationDetent = .medium
    private let peekDetent: PresentationDetent = .height(120)

    @Environment(\.colorScheme) private var colorScheme

    private var stopsDirection: RouteDirection { viewModel.selectedDirection }
    private var stops: [BusStop] { viewModel.getStops(for: stopsDirection) }
    private var adultFare: Int { viewModel.getFare(for: stopsDirection) }
    private var platform: String? { viewModel.getPlatformNumber(for: stopsDirection) }
    private var nightFare: Int? { viewModel.getNightFare(for: stopsDirection) }
    private var nightFareStartTime: String? { viewModel.getNightFareStartTime(for: stopsDirection) }
    private var selectedStopID: String? { selectedStop?.id }
    private var defaultStop: BusStop? { stops.first(where: \.isDeparture) ?? stops.first }

    private var selectedCoordinate: CLLocationCoordinate2D? {
        selectedStop.flatMap { coordinate(for: $0) }
    }

    private static let fareFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

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
                isDeparture: stop.isDeparture,
                isDestination: index == count - 1
            )
        }
    }

    private var mapRoutePath: [CLLocationCoordinate2D]? {
        viewModel.getRoutePath(for: stopsDirection)
    }

    private func formattedFare(_ amount: Int) -> String {
        Self.fareFormatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
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
            HomeDashboardTheme.screenBackground.ignoresSafeArea()

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
                        }
                        if !isSheetPresented {
                            isSheetPresented = true
                        }
                        if sheetDetent == peekDetent {
                            sheetDetent = .medium
                        }
                    },
                    onLocationUpdate: { location in
                        userLocation = location
                    }
                )
            }
            .ignoresSafeArea()

            // 우상단 고정 컨트롤 — safe area 안에 자동 위치 (시계 아래)
            VStack(spacing: 10) {
                mapControlButton(
                    systemName: "arrow.up.left.and.arrow.down.right",
                    accessibilityLabel: "노선 전체 보기"
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    fitToRoute = true
                }

                mapControlButton(
                    systemName: "location.fill",
                    accessibilityLabel: "현재 위치로 이동"
                ) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    centerOnUser = true
                }

                #if DEBUG
                mapControlButton(
                    systemName: "square.and.arrow.down.on.square",
                    accessibilityLabel: "경로 추출 (DEBUG)"
                ) {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    let direction = stopsDirection
                    let currentStops = stops
                    Task {
                        await RoutePathExporter.exportPath(
                            for: direction,
                            stops: currentStops
                        )
                    }
                }
                #endif
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity, alignment: .topTrailing)

            // 시트 닫혔을 때 다시 열기 버튼
            if !isSheetPresented {
                VStack {
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        isSheetPresented = true
                        sheetDetent = .medium
                    } label: {
                        HStack(spacing: 6) {
                            Text("정류장 목록")
                                .font(.system(.subheadline, weight: .semibold))
                            Image(systemName: "chevron.up")
                                .font(.system(.caption, weight: .bold))
                        }
                        .foregroundStyle(AppTheme.Color.primaryForeground)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(HomeDashboardTheme.primaryBlue)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("정류장 목록 열기")
                    .padding(.bottom, 24)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .onAppear {
            selectDefaultStopIfNeeded()
        }
        .onChange(of: viewModel.selectedDirection) { _ in
            selectDefaultStopIfNeeded(force: true)
        }
        .onChange(of: presentationToken) { _ in
            isSheetPresented = true
            sheetDetent = .medium
            selectDefaultStopIfNeeded()
        }
        .sheet(isPresented: $isSheetPresented) {
            ScrollView(showsIndicators: false) {
                sheetContent
                    .padding(.bottom, 40)
            }
            .presentationDetents([peekDetent, .medium, .large], selection: $sheetDetent)
            .presentationDragIndicator(.visible)
            .sheetEnhancements()
        }
    }

    // MARK: - Sheet 높이 추정 (지도 핀 centering 보정용)

    private func estimatedSheetTopY(for screenHeight: CGFloat) -> CGFloat {
        if sheetDetent == .large { return screenHeight * 0.10 }
        if sheetDetent == .medium { return screenHeight * 0.50 }
        return screenHeight * 0.85
    }

    // MARK: - 지도 컨트롤 버튼

    private func mapControlButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .glassCard(in: Circle(), fallback: Material.ultraThin, interactive: true)
                .shadow(color: .black.opacity(0.4), radius: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - 시트 콘텐츠

    private var sheetContent: some View {
        let currentStops = stops
        let adult = adultFare
        return VStack(spacing: 20) {
            DirectionSelector(selectedDirection: stopsDirection) { newDirection in
                viewModel.changeDirection(to: newDirection)
            }
            .padding(.horizontal, 24)

            if let platformNum = platform {
                platformBanner(platformNum)
                    .padding(.horizontal, 24)
            }

            stopListSection(currentStops)

            if let stop = selectedStop {
                selectedStopCard(stop: stop, stops: currentStops)
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            fareCard(adult: adult)
                .padding(.horizontal, 24)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: - 탑승홈 배너

    private func platformBanner(_ platformNum: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("탑승홈")
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                Text(platformNum)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(HomeDashboardTheme.primaryText)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .tintedGlass(
            HomeDashboardTheme.primaryBlue.opacity(0.25),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous),
            fallback: HomeDashboardTheme.primaryBlue.opacity(0.1)
        )
        .fallbackCardBorder(cornerRadius: 10, color: HomeDashboardTheme.primaryBlue.opacity(0.3))
    }

    // MARK: - 정류장 목록 섹션

    private func stopListSection(_ currentStops: [BusStop]) -> some View {
        Group {
            if currentStops.isEmpty {
                emptyStopsView
                    .padding(.horizontal, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(currentStops.enumerated()), id: \.element.id) { index, stop in
                        StopRowView(
                            stop: stop,
                            isFirst: index == 0,
                            isLast: index == currentStops.count - 1,
                            isSelected: stop.id == selectedStop?.id,
                            onTap: { handleStopSelection(stop) }
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private var emptyStopsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bus.fill")
                .font(.system(.title3, weight: .light))
                .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
            Text("정류장 정보를 불러올 수 없습니다")
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
            Text("네트워크 연결을 확인하고 다시 시도해 주세요")
                .font(.system(.caption, weight: .regular))
                .foregroundStyle(HomeDashboardTheme.timetableMutedText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 선택된 정류장 상세 카드

    private func selectedStopCard(stop: BusStop, stops currentStops: [BusStop]) -> some View {
        let isLast = currentStops.last?.id == stop.id
        let accent: Color = stop.isDeparture
            ? HomeDashboardTheme.departureGreen
            : HomeDashboardTheme.primaryBlue
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(stop.name)
                    .font(.system(.title3, weight: .bold))
                    .foregroundStyle(HomeDashboardTheme.primaryText)

                StopBadge(isDeparture: stop.isDeparture, isDestination: isLast)

                Spacer()
            }

            stopImageView(for: stop)

            HStack(spacing: 12) {
                if let address = stop.description {
                    Text(address)
                        .font(.system(.footnote, weight: .medium))
                        .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                }

                if let userLoc = userLocation, let coord = coordinate(for: stop) {
                    let stopLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    let meters = userLoc.distance(from: stopLoc)
                    let distanceText = meters < 1000
                        ? "\(Int(meters))m"
                        : String(format: "%.1fkm", meters / 1000)
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "figure.walk")
                            .font(.system(.caption2, weight: .medium))
                        Text(distanceText)
                            .font(.system(.caption, weight: .semibold))
                    }
                    .foregroundStyle(HomeDashboardTheme.primaryBlue)
                    .accessibilityLabel("도보 \(distanceText)")
                    .accessibilityElement(children: .ignore)
                }
            }

            if coordinate(for: stop) != nil {
                Button {
                    openMapsNavigation(for: stop)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.system(.subheadline, weight: .medium))
                        Text("길 찾기")
                            .font(.system(.subheadline, weight: .bold))
                    }
                    .foregroundStyle(AppTheme.Color.primaryForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 12, fallback: HomeDashboardTheme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accent.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - 정류장 이미지

    private func stopImageView(for stop: BusStop) -> some View {
        let uiImage = UIImage(named: stop.id)
        return ZStack(alignment: .bottomLeading) {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle()
                        .fill(HomeDashboardTheme.iconBackground)
                    VStack(spacing: 6) {
                        Image(systemName: "camera.slash")
                            .font(.system(.title3, weight: .light))
                            .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                        Text("사진 준비 중")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(HomeDashboardTheme.timetableMutedText)
                    }
                }
            }

            if uiImage != nil {
                LinearGradient(
                    colors: [.black.opacity(0.8), .clear],
                    startPoint: .bottom,
                    endPoint: .center
                )

                Text("정류장 전경")
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .glassCard(cornerRadius: 4, fallback: Material.ultraThin)
                    .padding(12)
            }
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HomeDashboardTheme.border, lineWidth: 1)
        )
    }

    // MARK: - 요금 카드

    private func fareCard(adult: Int) -> some View {
        VStack(spacing: 16) {
            Text("요금 정보")
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(HomeDashboardTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(HomeDashboardTheme.border)
                        .frame(height: 1)
                }

            VStack(spacing: 12) {
                fareRow(label: "성인", amount: adult)
                fareRow(label: "청소년 (13-18세)", amount: Int(Double(adult) * 0.8))
                fareRow(label: "어린이 (6-12세)", amount: Int(Double(adult) * 0.52))

                if let nFare = nightFare, let startTime = nightFareStartTime {
                    Rectangle()
                        .fill(HomeDashboardTheme.border)
                        .frame(height: 1)
                    HStack {
                        HStack(spacing: 4) {
                            Text("심야")
                                .font(.system(.caption2, weight: .bold))
                                .foregroundStyle(AppTheme.Color.nightFare)
                            Text("(\(startTime) 이후 성인 기준)")
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                        }
                        Spacer()
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text(formattedFare(nFare))
                                .font(.system(.callout, weight: .bold))
                                .foregroundStyle(HomeDashboardTheme.primaryText)
                            Text("원")
                                .font(.system(.caption))
                                .foregroundStyle(HomeDashboardTheme.timetableMutedText)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("심야 성인 \(nFare)원 (\(startTime) 이후)")
                    }
                }
            }
        }
        .padding(21)
        .glassCard(cornerRadius: 12, fallback: HomeDashboardTheme.cardBackground)
        .fallbackCardBorder(cornerRadius: 12, color: HomeDashboardTheme.border)
    }

    private func fareRow(label: String, amount: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
            Spacer()
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(formattedFare(amount))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(HomeDashboardTheme.primaryText)
                Text("원")
                    .font(.system(size: 12))
                    .foregroundStyle(HomeDashboardTheme.timetableMutedText)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(label) \(amount)원")
        }
    }

    private func openMapsNavigation(for stop: BusStop) {
        guard let coord = coordinate(for: stop) else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        item.name = stop.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault])
    }
}

// MARK: - 정류장 배지

struct StopBadge: View {
    let isDeparture: Bool
    let isDestination: Bool

    var body: some View {
        if isDeparture {
            Text("출발")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.black)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(HomeDashboardTheme.departureGreen)
                .clipShape(Capsule())
        } else if isDestination {
            Text("종점")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(HomeDashboardTheme.secondaryText)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(HomeDashboardTheme.chipBackground)
                .clipShape(Capsule())
        }
    }
}

// MARK: - 정류장 행 뷰

struct StopRowView: View {
    let stop: BusStop
    let isFirst: Bool
    let isLast: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 타임라인 열
                ZStack {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(HomeDashboardTheme.primaryBlue.opacity(0.4))
                            .frame(width: 2)
                            .opacity(isFirst ? 0 : 1)

                        Spacer()
                            .frame(height: 0)

                        Rectangle()
                            .fill(HomeDashboardTheme.primaryBlue.opacity(0.4))
                            .frame(width: 2)
                            .opacity(isLast ? 0 : 1)
                    }

                    if isFirst {
                        Circle()
                            .fill(HomeDashboardTheme.departureGreen)
                            .frame(width: 12, height: 12)
                    } else if isLast {
                        ZStack {
                            Circle()
                                .stroke(HomeDashboardTheme.primaryBlue, lineWidth: 2)
                                .frame(width: 14, height: 14)
                            Circle()
                                .fill(HomeDashboardTheme.primaryBlue)
                                .frame(width: 7, height: 7)
                        }
                    } else {
                        Circle()
                            .stroke(HomeDashboardTheme.primaryBlue.opacity(0.5), lineWidth: 1.5)
                            .frame(width: 10, height: 10)
                    }
                }
                .frame(width: 20)

                Text(stop.name)
                    .font(.system(size: 14, weight: isFirst || isLast ? .semibold : .regular))
                    .foregroundStyle(isSelected ? HomeDashboardTheme.primaryBlue : HomeDashboardTheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                StopBadge(isDeparture: isFirst, isDestination: isLast)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected
                          ? HomeDashboardTheme.primaryBlue.opacity(0.12)
                          : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isSelected ? "탭하면 선택이 해제됩니다" : "탭하면 지도에서 정류장 위치를 확인합니다")
    }

    private var accessibilityLabel: String {
        var parts = [stop.name]
        if isFirst { parts.append("출발 정류장") }
        else if isLast { parts.append("종점 정류장") }
        if isSelected { parts.append("선택됨") }
        return parts.joined(separator: ", ")
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
