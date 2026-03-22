import SwiftUI
import UIKit
import MapKit
import CoreLocation

// MARK: - 정류장 화면

// 좌표 없는 노선의 임시 폴백 (율하 노선 등)
private let fallbackCoordinates: [String: CLLocationCoordinate2D] = [
    "사상터미널":   CLLocationCoordinate2D(latitude: 35.163329, longitude: 128.981845),
    "김해외고":     CLLocationCoordinate2D(latitude: 35.2257,   longitude: 128.8928),
    "율하2지구입구": CLLocationCoordinate2D(latitude: 35.2207,  longitude: 128.8994),
]

// MARK: - MapKit UIColor 상수

private enum MapTheme {
    static let primaryBlue    = UIColor(red: 59/255,  green: 130/255, blue: 246/255, alpha: 1)
    static let departureGreen = UIColor(red: 74/255,  green: 222/255, blue: 128/255, alpha: 1)
    static let stopBg         = UIColor(red: 51/255,  green: 65/255,  blue: 85/255,  alpha: 1)
    static let labelBg        = UIColor(red: 30/255,  green: 41/255,  blue: 59/255,  alpha: 0.9)
    static let selectedLabelBg = UIColor(red: 30/255, green: 50/255,  blue: 100/255, alpha: 0.95)
}

struct StopsScreenView: View {
    @ObservedObject var viewModel: MainViewModel

    @State private var stopsDirection: RouteDirection = .jangyuToSasang
    @State private var selectedStop: BusStop? = nil
    @State private var centerOnUser = false
    @State private var userLocation: CLLocation? = nil

    // 시트 드래그
    @GestureState private var dragTranslation: CGFloat = 0
    @State private var sheetOffset: CGFloat = 0

    private var stops: [BusStop]            { viewModel.getStops(for: stopsDirection) }
    private var adultFare: Int              { viewModel.getFare(for: stopsDirection) }
    private var platform: String?           { viewModel.getPlatformNumber(for: stopsDirection) }
    private var nightFare: Int?             { viewModel.getNightFare(for: stopsDirection) }
    private var nightFareStartTime: String? { viewModel.getNightFareStartTime(for: stopsDirection) }

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
        return fallbackCoordinates[stop.name]
    }

    private var mapPins: [StopPin] {
        let currentStops = stops
        let count = currentStops.count
        let selectedID = selectedStop?.id
        return currentStops.enumerated().compactMap { index, stop in
            guard let coord = coordinate(for: stop) else { return nil }
            return StopPin(
                coordinate: coord,
                stopID: stop.id,
                stopName: stop.name,
                isDeparture: stop.isDeparture,
                isDestination: index == count - 1,
                isSelected: stop.id == selectedID
            )
        }
    }

    private func formattedFare(_ amount: Int) -> String {
        Self.fareFormatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    private func handleStopSelection(_ stop: BusStop) {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedStop = selectedStop?.id == stop.id ? nil : stop
        }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let collapsedOffset = geo.size.height * 0.52
            let hiddenOffset = geo.size.height * 0.88
            let sheetY = min(hiddenOffset, max(0, sheetOffset + dragTranslation))

            ZStack(alignment: .top) {
                HomeDashboardTheme.screenBackground.ignoresSafeArea()

                // 지도 — 전체 화면. 시트가 위에 오버레이되며, 시트가 내려가면 지도가 드러남
                RouteMapView(
                    pins: mapPins,
                    selectedCoordinate: selectedCoordinate,
                    centerOnUser: $centerOnUser,
                    sheetTopY: geo.size.height * 0.40 + geo.safeAreaInsets.top + sheetY,
                    onPinTap: { stopID in
                        guard let stop = stops.first(where: { $0.id == stopID }) else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedStop = selectedStop?.id == stop.id ? nil : stop
                            if sheetOffset > 0 { sheetOffset = 0 }
                        }
                    },
                    onLocationUpdate: { location in
                        userLocation = location
                    }
                )
                .ignoresSafeArea()

                // 현재위치 버튼 — 시트 상단을 따라 이동
                VStack {
                    Spacer()
                        .frame(height: max(
                            geo.safeAreaInsets.top + 16,
                            geo.size.height * 0.40 + geo.safeAreaInsets.top + sheetY - 52
                        ))
                    HStack {
                        Spacer()
                        Button {
                            centerOnUser = true
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.4), radius: 8)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 16)
                    }
                }

                // 바텀 시트
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: geo.size.height * 0.40 + geo.safeAreaInsets.top)

                    ZStack(alignment: .top) {
                        // 배경 (하단까지 채우기)
                        HomeDashboardTheme.sheetBackground
                            .clipShape(TopRoundedShape(radius: 32))
                            .ignoresSafeArea(edges: .bottom)
                            .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: -10)

                        VStack(spacing: 0) {
                            // 드래그 핸들 (제스처 영역)
                            dragHandleArea(collapsedOffset: collapsedOffset, hiddenOffset: hiddenOffset)

                            ScrollView(showsIndicators: false) {
                                sheetContent
                                    .padding(.bottom, 40)
                            }
                        }
                    }
                    .offset(y: sheetY)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            stopsDirection = viewModel.selectedDirection
        }
    }

    // MARK: - 드래그 핸들

    private func dragHandleArea(collapsedOffset: CGFloat, hiddenOffset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(HomeDashboardTheme.border)
                .frame(width: 48, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .updating($dragTranslation) { value, state, _ in
                    state = value.translation.height
                }
                .onEnded { value in
                    let velocity = value.velocity.height
                    let projected = sheetOffset + value.predictedEndTranslation.height
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        if velocity > 800 {
                            // 빠른 다운스와이프: 현재 위치에서 다음 단계로
                            sheetOffset = sheetOffset < collapsedOffset / 2 ? collapsedOffset : hiddenOffset
                        } else if velocity < -800 {
                            // 빠른 업스와이프: 현재 위치에서 이전 단계로
                            sheetOffset = sheetOffset > collapsedOffset * 1.3 ? collapsedOffset : 0
                        } else {
                            // 위치 기반 스냅: 가장 가까운 단계
                            let snapPoints: [CGFloat] = [0, collapsedOffset, hiddenOffset]
                            sheetOffset = snapPoints.min(by: { abs($0 - projected) < abs($1 - projected) }) ?? collapsedOffset
                        }
                    }
                }
        )
    }

    // MARK: - 시트 콘텐츠

    private var sheetContent: some View {
        let currentStops = stops
        let adult = adultFare
        return VStack(spacing: 20) {
            DirectionSelector(selectedDirection: stopsDirection) { newDirection in
                stopsDirection = newDirection
                selectedStop = nil
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
            Image(systemName: "signpost.right.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(HomeDashboardTheme.primaryBlue)

            VStack(alignment: .leading, spacing: 1) {
                Text("탑승홈")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                Text(platformNum)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(HomeDashboardTheme.primaryText)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(HomeDashboardTheme.primaryBlue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(HomeDashboardTheme.primaryBlue.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 정류장 목록 섹션

    private func stopListSection(_ currentStops: [BusStop]) -> some View {
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

    // MARK: - 선택된 정류장 상세 카드

    private func selectedStopCard(stop: BusStop, stops currentStops: [BusStop]) -> some View {
        let isLast = currentStops.last?.id == stop.id
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(stop.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(HomeDashboardTheme.primaryText)

                StopBadge(isDeparture: stop.isDeparture, isDestination: isLast)

                Spacer()
            }

            stopImageView(for: stop)

            HStack(spacing: 12) {
                if let address = stop.description {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                        Text(address)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                    }
                }

                if let userLoc = userLocation, let coord = coordinate(for: stop) {
                    let stopLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    let meters = userLoc.distance(from: stopLoc)
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 10, weight: .medium))
                        Text(meters < 1000
                             ? "\(Int(meters))m"
                             : String(format: "%.1fkm", meters / 1000))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(HomeDashboardTheme.primaryBlue)
                }
            }

            if (stop.isDeparture || isLast), let platformNum = platform {
                HStack(spacing: 6) {
                    Image(systemName: "signpost.right.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(platformNum)
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white)
                .clipShape(Capsule())
            }

            if coordinate(for: stop) != nil {
                Button {
                    openMapsNavigation(for: stop)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 14, weight: .medium))
                        Text("길 찾기")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(HomeDashboardTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HomeDashboardTheme.primaryBlue.opacity(0.5), lineWidth: 1)
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
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                        Text("사진 준비 중")
                            .font(.system(size: 12, weight: .medium))
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
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
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
            HStack(spacing: 8) {
                Image(systemName: "creditcard")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(HomeDashboardTheme.primaryText)
                Text("요금 정보")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(HomeDashboardTheme.primaryText)
            }
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
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.orange)
                            Text("(\(startTime) 이후 성인 기준)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                        }
                        Spacer()
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text(formattedFare(nFare))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(HomeDashboardTheme.primaryText)
                            Text("원")
                                .font(.system(size: 12))
                                .foregroundStyle(HomeDashboardTheme.timetableMutedText)
                        }
                    }
                }
            }
        }
        .padding(21)
        .background(HomeDashboardTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HomeDashboardTheme.border, lineWidth: 1)
        )
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

private struct StopBadge: View {
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
                .foregroundStyle(.black)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.white)
                .clipShape(Capsule())
        }
    }
}

// MARK: - 정류장 행 뷰

private struct StopRowView: View {
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
                    .foregroundStyle(isSelected ? HomeDashboardTheme.primaryBlue : .white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                StopBadge(isDeparture: isFirst, isDestination: isLast)

                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(HomeDashboardTheme.primaryBlue)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected
                          ? HomeDashboardTheme.primaryBlue.opacity(0.12)
                          : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 상단 모서리 둥근 Shape (iOS 16 호환)

private struct TopRoundedShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - MapKit UIViewRepresentable

private struct RouteMapView: UIViewRepresentable {
    let pins: [StopPin]
    let selectedCoordinate: CLLocationCoordinate2D?
    @Binding var centerOnUser: Bool
    let sheetTopY: CGFloat           // 시트 상단 Y (시트 위 visible 영역 높이)
    var onPinTap: (String) -> Void   // stop ID 전달
    var onLocationUpdate: ((CLLocation) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let mv = MKMapView()
        mv.delegate = context.coordinator
        mv.overrideUserInterfaceStyle = .dark
        mv.showsCompass = false
        mv.showsScale = false
        mv.showsUserLocation = true
        mv.pointOfInterestFilter = .excludingAll

        context.coordinator.requestLocationIfNeeded()
        refresh(mv)
        return mv
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.onPinTap = onPinTap
        context.coordinator.onLocationUpdate = onLocationUpdate

        if centerOnUser {
            uiView.setUserTrackingMode(.follow, animated: true)
            DispatchQueue.main.async { centerOnUser = false }
        }

        if let coord = selectedCoordinate {
            let span = MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            let mapHeight = uiView.frame.height
            var center = coord
            if mapHeight > 0 && sheetTopY > 0 {
                // 시트가 가리는 만큼 위도를 내려서, 핀이 visible 영역 중앙에 오도록 보정
                let visibleCenterY = sheetTopY / 2
                let pixelOffset = mapHeight / 2 - visibleCenterY
                let latOffset = pixelOffset * span.latitudeDelta / mapHeight
                center = CLLocationCoordinate2D(
                    latitude: coord.latitude - latOffset,
                    longitude: coord.longitude
                )
            }
            uiView.setRegion(MKCoordinateRegion(center: center, span: span), animated: true)
        }

        let existing = uiView.annotations.compactMap { $0 as? StopPin }
        let pinsChanged = existing.count != pins.count ||
            !zip(existing, pins).allSatisfy {
                $0.stopName == $1.stopName &&
                $0.coordinate.latitude == $1.coordinate.latitude &&
                $0.coordinate.longitude == $1.coordinate.longitude &&
                $0.isSelected == $1.isSelected
            }

        if pinsChanged {
            let customAnnotations = uiView.annotations.filter { !($0 is MKUserLocation) }
            uiView.removeAnnotations(customAnnotations)
            uiView.removeOverlays(uiView.overlays)
            refresh(uiView)
        }
    }

    private func refresh(_ mv: MKMapView) {
        guard !pins.isEmpty else { return }

        let coords = pins.map(\.coordinate)
        mv.addOverlay(MKPolyline(coordinates: coords, count: coords.count))
        mv.addAnnotations(pins)

        if selectedCoordinate == nil {
            let lats = coords.map(\.latitude)
            let lngs = coords.map(\.longitude)
            guard let minLat = lats.min(), let maxLat = lats.max(),
                  let minLng = lngs.min(), let maxLng = lngs.max() else { return }
            let center = CLLocationCoordinate2D(
                latitude:  (minLat + maxLat) / 2,
                longitude: (minLng + maxLng) / 2
            )
            let span = MKCoordinateSpan(
                latitudeDelta:  (maxLat - minLat) * 1.4,
                longitudeDelta: (maxLng - minLng) * 1.4
            )
            mv.setRegion(MKCoordinateRegion(center: center, span: span), animated: true)
        }
    }

    // MARK: Coordinator

    class Coordinator: NSObject, MKMapViewDelegate, CLLocationManagerDelegate {
        private let locationManager = CLLocationManager()
        var onPinTap: ((String) -> Void)?
        var onLocationUpdate: ((CLLocation) -> Void)?

        func requestLocationIfNeeded() {
            locationManager.delegate = self
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
            locationManager.startUpdatingLocation()
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let loc = locations.last else { return }
            DispatchQueue.main.async { self.onLocationUpdate?(loc) }
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let pin = view.annotation as? StopPin else { return }
            // MapKit 기본 선택 상태 즉시 해제 (UI는 SwiftUI가 관리)
            mapView.deselectAnnotation(view.annotation, animated: false)
            onPinTap?(pin.stopID)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let pl = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let r = MKPolylineRenderer(polyline: pl)
            r.strokeColor = MapTheme.primaryBlue.withAlphaComponent(0.7)
            r.lineWidth = 2.5
            return r
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let pin = annotation as? StopPin else { return nil }
            let reuseID = "StopPin"
            let v = mapView.dequeueReusableAnnotationView(withIdentifier: reuseID)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
            v.annotation = annotation
            v.canShowCallout = false
            v.subviews.forEach { $0.removeFromSuperview() }
            v.isAccessibilityElement = true
            v.accessibilityLabel = pin.stopName
            v.accessibilityHint = pin.isDeparture ? "출발 정류장" : (pin.isDestination ? "종점 정류장" : "중간 정류장, 탭하면 상세 정보를 볼 수 있습니다")

            if pin.isDeparture {
                let size: CGFloat = pin.isSelected ? 28 : 20
                let circle = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                circle.backgroundColor = MapTheme.departureGreen
                circle.layer.cornerRadius = size / 2
                circle.layer.borderColor = UIColor.white.cgColor
                circle.layer.borderWidth = pin.isSelected ? 2.5 : 2
                if pin.isSelected {
                    circle.layer.shadowColor = MapTheme.departureGreen.withAlphaComponent(0.8).cgColor
                    circle.layer.shadowRadius = 10
                    circle.layer.shadowOpacity = 1
                    circle.layer.shadowOffset = .zero
                }
                v.addSubview(circle)
                v.frame = CGRect(x: 0, y: 0, width: size, height: size)
            } else if pin.isDestination {
                let size: CGFloat = pin.isSelected ? 36 : 32
                let outer = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                outer.backgroundColor = MapTheme.primaryBlue
                outer.layer.cornerRadius = size / 2
                outer.layer.borderColor = UIColor.white.cgColor
                outer.layer.borderWidth = pin.isSelected ? 2.5 : 2
                outer.layer.shadowColor = MapTheme.primaryBlue.withAlphaComponent(pin.isSelected ? 0.8 : 0.5).cgColor
                outer.layer.shadowRadius = pin.isSelected ? 10 : 8
                outer.layer.shadowOpacity = 1
                outer.layer.shadowOffset = .zero
                let dotSize: CGFloat = size / 3
                let dot = UIView(frame: CGRect(x: (size - dotSize) / 2, y: (size - dotSize) / 2, width: dotSize, height: dotSize))
                dot.backgroundColor = .white
                dot.layer.cornerRadius = dotSize / 2
                outer.addSubview(dot)
                v.addSubview(outer)
                v.frame = CGRect(x: 0, y: 0, width: size, height: size)
            } else if pin.isSelected {
                let size: CGFloat = 28
                let outer = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                outer.backgroundColor = MapTheme.primaryBlue
                outer.layer.cornerRadius = size / 2
                outer.layer.borderColor = UIColor.white.cgColor
                outer.layer.borderWidth = 2.5
                outer.layer.shadowColor = MapTheme.primaryBlue.withAlphaComponent(0.8).cgColor
                outer.layer.shadowRadius = 10
                outer.layer.shadowOpacity = 1
                outer.layer.shadowOffset = .zero
                v.addSubview(outer)
                v.frame = CGRect(x: 0, y: 0, width: size, height: size)
            } else {
                let size: CGFloat = 16
                let circle = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                circle.backgroundColor = MapTheme.stopBg
                circle.layer.cornerRadius = size / 2
                circle.layer.borderColor = UIColor.white.cgColor
                circle.layer.borderWidth = 2
                v.addSubview(circle)
                v.frame = CGRect(x: 0, y: 0, width: size, height: size)
            }

            let label = UILabel()
            label.text = pin.stopName
            label.textColor = .white
            label.font = pin.isDestination || pin.isDeparture
                ? UIFont.boldSystemFont(ofSize: 12)
                : UIFont.systemFont(ofSize: 10, weight: .medium)
            label.sizeToFit()
            label.backgroundColor = pin.isSelected ? MapTheme.selectedLabelBg : MapTheme.labelBg
            label.textAlignment = .center
            label.layer.cornerRadius = 4
            label.layer.masksToBounds = true
            let lw = label.intrinsicContentSize.width + 16
            let lh: CGFloat = 20
            let pinSize = v.frame.width
            let totalWidth = max(pinSize, lw)
            label.frame = CGRect(x: (totalWidth - lw) / 2, y: pinSize + 6, width: lw, height: lh)
            v.addSubview(label)
            v.frame = CGRect(x: 0, y: 0, width: totalWidth, height: pinSize + 6 + lh)

            return v
        }
    }
}

// MARK: - 지도 핀 모델

private final class StopPin: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let stopID: String
    let stopName: String
    let isDeparture: Bool
    let isDestination: Bool
    let isSelected: Bool
    var title: String? { stopName }

    init(coordinate: CLLocationCoordinate2D, stopID: String, stopName: String,
         isDeparture: Bool, isDestination: Bool, isSelected: Bool) {
        self.coordinate = coordinate
        self.stopID = stopID
        self.stopName = stopName
        self.isDeparture = isDeparture
        self.isDestination = isDestination
        self.isSelected = isSelected
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
