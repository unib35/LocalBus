import SwiftUI
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

    private var stops: [BusStop]          { viewModel.getStops(for: stopsDirection) }
    private var adultFare: Int            { viewModel.getFare(for: stopsDirection) }
    private var platform: String?         { viewModel.getPlatformNumber(for: stopsDirection) }
    private var nightFare: Int?           { viewModel.getNightFare(for: stopsDirection) }
    private var nightFareStartTime: String? { viewModel.getNightFareStartTime(for: stopsDirection) }

    // selectedCoordinate는 selectedStop에서 파생되므로 @State 불필요
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

    /// 지도에 표시할 핀 목록 — stops를 한 번 캡처 후 사용
    private var mapPins: [StopPin] {
        let currentStops = stops
        let count = currentStops.count
        let selectedID = selectedStop?.id
        return currentStops.enumerated().compactMap { index, stop in
            guard let coord = coordinate(for: stop) else { return nil }
            return StopPin(
                coordinate: coord,
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

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                // 지도
                RouteMapView(pins: mapPins, selectedCoordinate: selectedCoordinate, centerOnUser: $centerOnUser)
                .frame(height: geo.size.height * 0.44 + geo.safeAreaInsets.top)
                .ignoresSafeArea(edges: .top)

                // 현재위치 버튼
                VStack {
                    Spacer()
                        .frame(height: geo.size.height * 0.40 + geo.safeAreaInsets.top - 52)
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
                        VStack(spacing: 0) {
                            Color(red: 30/255, green: 30/255, blue: 30/255)
                                .frame(height: 200)
                                .clipShape(TopRoundedShape(radius: 32))
                            Color(red: 30/255, green: 30/255, blue: 30/255)
                        }
                        .ignoresSafeArea(edges: .bottom)
                        .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: -10)

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                dragHandle
                                sheetContent
                                    .padding(.bottom, 40)
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            stopsDirection = viewModel.selectedDirection
        }
    }

    // MARK: - 드래그 핸들

    private var dragHandle: some View {
        Capsule()
            .fill(Color(red: 82/255, green: 82/255, blue: 82/255))
            .frame(width: 48, height: 4)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }

    // MARK: - 시트 콘텐츠

    private var sheetContent: some View {
        // stops를 한 번만 조회하여 stopListSection·selectedStopCard·fareCard에 전달
        let currentStops = stops
        let adult = adultFare
        return VStack(spacing: 20) {
            DirectionSelector(selectedDirection: stopsDirection) { newDirection in
                stopsDirection = newDirection
                selectedStop = nil
            }
            .padding(.horizontal, 24)

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
                    .foregroundStyle(.white)

                StopBadge(isDeparture: stop.isDeparture, isDestination: isLast)

                Spacer()
            }

            stopImageView(for: stop)

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
        .background(Color(red: 20/255, green: 20/255, blue: 30/255))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HomeDashboardTheme.primaryBlue.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - 정류장 이미지

    private func stopImageView(for stop: BusStop) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let uiImage = UIImage(named: stop.id) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(red: 38/255, green: 38/255, blue: 38/255))
            }

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
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(red: 64/255, green: 64/255, blue: 64/255), lineWidth: 1)
        )
    }

    // MARK: - 요금 카드

    private func fareCard(adult: Int) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "creditcard")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Text("요금 정보")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(red: 31/255, green: 41/255, blue: 55/255))
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
                                .foregroundStyle(.white)
                            Text("원")
                                .font(.system(size: 12))
                                .foregroundStyle(HomeDashboardTheme.timetableMutedText)
                        }
                    }
                }
            }
        }
        .padding(21)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(red: 51/255, green: 51/255, blue: 51/255), lineWidth: 1)
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
                    .foregroundStyle(.white)
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
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit])
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

                    // 원형 마커
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

                // 정류장 이름
                Text(stop.name)
                    .font(.system(size: 14, weight: isFirst || isLast ? .semibold : .regular))
                    .foregroundStyle(isSelected ? HomeDashboardTheme.primaryBlue : .white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 배지
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
        // 현재위치 버튼 탭 시 포커스
        if centerOnUser {
            uiView.setUserTrackingMode(.follow, animated: true)
            DispatchQueue.main.async { centerOnUser = false }
        }

        // 선택된 좌표가 바뀌면 해당 위치로 포커스
        if let coord = selectedCoordinate {
            let region = MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            )
            uiView.setRegion(region, animated: true)
        }

        // compactMap으로 StopPin만 추출 (MKUserLocation 등 다른 annotation 제외)
        let existing = uiView.annotations.compactMap { $0 as? StopPin }
        let pinsChanged = existing.count != pins.count ||
            !zip(existing, pins).allSatisfy {
                $0.stopName == $1.stopName &&
                $0.coordinate.latitude == $1.coordinate.latitude &&
                $0.coordinate.longitude == $1.coordinate.longitude &&
                $0.isSelected == $1.isSelected
            }

        if pinsChanged {
            // MKUserLocation은 제외하고 StopPin만 제거
            let customAnnotations = uiView.annotations.filter { !($0 is MKUserLocation) }
            uiView.removeAnnotations(customAnnotations)
            uiView.removeOverlays(uiView.overlays)
            refresh(uiView)
        }
    }

    private func refresh(_ mv: MKMapView) {
        guard !pins.isEmpty else { return }

        let coords = pins.map(\.coordinate)

        // 경로 선
        mv.addOverlay(MKPolyline(coordinates: coords, count: coords.count))

        // 핀
        mv.addAnnotations(pins)

        // 전체 범위 (선택된 좌표가 없을 때만 fit)
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
            mv.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)
        }
    }

    // MARK: Coordinator

    class Coordinator: NSObject, MKMapViewDelegate, CLLocationManagerDelegate {
        private let locationManager = CLLocationManager()

        func requestLocationIfNeeded() {
            locationManager.delegate = self
            switch locationManager.authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            default:
                break
            }
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
            // 재사용 시 기존 서브뷰 제거
            v.subviews.forEach { $0.removeFromSuperview() }

            if pin.isSelected {
                // 선택됨: 파랑 28pt + 글로우
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
            } else if pin.isDeparture {
                // 출발: 초록 20pt
                let size: CGFloat = 20
                let circle = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                circle.backgroundColor = MapTheme.departureGreen
                circle.layer.cornerRadius = size / 2
                circle.layer.borderColor = UIColor.white.cgColor
                circle.layer.borderWidth = 2
                v.addSubview(circle)
                v.frame = CGRect(x: 0, y: 0, width: size, height: size)
            } else if pin.isDestination {
                // 종착: 파랑 32pt + 글로우
                let size: CGFloat = 32
                let outer = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                outer.backgroundColor = MapTheme.primaryBlue
                outer.layer.cornerRadius = size / 2
                outer.layer.borderColor = UIColor.white.cgColor
                outer.layer.borderWidth = 2
                outer.layer.shadowColor = MapTheme.primaryBlue.withAlphaComponent(0.5).cgColor
                outer.layer.shadowRadius = 8
                outer.layer.shadowOpacity = 1
                outer.layer.shadowOffset = .zero
                let dot = UIView(frame: CGRect(x: 11, y: 11, width: 10, height: 10))
                dot.backgroundColor = .white
                dot.layer.cornerRadius = 5
                outer.addSubview(dot)
                v.addSubview(outer)
                v.frame = CGRect(x: 0, y: 0, width: size, height: size)
            } else {
                // 일반: 어두운 16pt
                let size: CGFloat = 16
                let circle = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                circle.backgroundColor = MapTheme.stopBg
                circle.layer.cornerRadius = size / 2
                circle.layer.borderColor = UIColor.white.cgColor
                circle.layer.borderWidth = 2
                v.addSubview(circle)
                v.frame = CGRect(x: 0, y: 0, width: size, height: size)
            }

            // 이름 레이블
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
            label.frame = CGRect(x: (pinSize - lw) / 2, y: pinSize + 6, width: lw, height: lh)
            v.addSubview(label)
            v.frame = CGRect(x: 0, y: 0, width: max(pinSize, lw), height: pinSize + 6 + lh)

            return v
        }
    }
}

// MARK: - 지도 핀 모델

private final class StopPin: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let stopName: String
    let isDeparture: Bool
    let isDestination: Bool
    let isSelected: Bool
    var title: String? { stopName }

    init(coordinate: CLLocationCoordinate2D, stopName: String,
         isDeparture: Bool, isDestination: Bool, isSelected: Bool) {
        self.coordinate = coordinate
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
