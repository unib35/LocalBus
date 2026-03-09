import SwiftUI
import MapKit

// MARK: - 정류장 화면

// 좌표 없는 노선의 임시 폴백 (율하 노선 등)
private let fallbackCoordinates: [String: CLLocationCoordinate2D] = [
    "사상터미널":   CLLocationCoordinate2D(latitude: 35.163329, longitude: 128.981845),
    "김해외고":     CLLocationCoordinate2D(latitude: 35.2257,   longitude: 128.8928),
    "율하2지구입구": CLLocationCoordinate2D(latitude: 35.2207,  longitude: 128.8994),
]

struct StopsScreenView: View {
    @ObservedObject var viewModel: MainViewModel

    private var destinationStop: BusStop? { viewModel.currentStops.last }
    private var isTerminal: Bool { destinationStop?.isDeparture == false }
    private var adultFare: Int { viewModel.fare }
    private var youthFare: Int { Int(Double(adultFare) * 0.8) }
    private var childFare: Int { Int(Double(adultFare) * 0.52) }

    /// JSON 좌표 우선, 없으면 폴백 사용
    private func coordinate(for stop: BusStop) -> CLLocationCoordinate2D? {
        if let lat = stop.latitude, let lng = stop.longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        return fallbackCoordinates[stop.name]
    }

    /// 지도에 표시할 핀 목록
    private var mapPins: [StopPin] {
        let count = viewModel.currentStops.count
        return viewModel.currentStops.enumerated().compactMap { index, stop in
            guard let coord = coordinate(for: stop) else { return nil }
            return StopPin(
                coordinate: coord,
                stopName: stop.name,
                isDestination: index == count - 1
            )
        }
    }

    private func formattedFare(_ amount: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                // 지도
                RouteMapView(pins: mapPins)
                .frame(height: geo.size.height * 0.44 + geo.safeAreaInsets.top)
                .ignoresSafeArea(edges: .top)

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
        VStack(spacing: 24) {
            stationHeader
            stationImage
            fareCard
            navigateButton
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // MARK: - 정류장 헤더

    private var stationHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(destinationStop?.name ?? viewModel.currentArrivalStopName)
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-0.6)
                        .foregroundStyle(.white)

                    if isTerminal {
                        Text("종점")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.white)
                            .clipShape(Capsule())
                    }
                }

                if let address = destinationStop?.description {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                        Text(address)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)
                    }
                }

                platformBadge
                    .padding(.top, 2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("다음 도착")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HomeDashboardTheme.timetableSecondaryText)

                Text(viewModel.nextBusArrivalTime)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .tracking(-0.5)
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - 탑승 홈 배지

    @ViewBuilder
    private var platformBadge: some View {
        if let platform = viewModel.platformNumber {
            HStack(spacing: 6) {
                Image(systemName: "signpost.right.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(platform)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white)
            .clipShape(Capsule())
        }
    }

    // MARK: - 정류장 사진 (플레이스홀더)

    private var stationImage: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Color(red: 38/255, green: 38/255, blue: 38/255))

            // 그라디언트 오버레이
            LinearGradient(
                colors: [.black.opacity(0.8), .clear],
                startPoint: .bottom,
                endPoint: .center
            )

            // "정류장 전경" 레이블
            Text("정류장 전경")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .padding(12)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(red: 64/255, green: 64/255, blue: 64/255), lineWidth: 1)
        )
    }

    // MARK: - 요금 카드

    private var fareCard: some View {
        VStack(spacing: 16) {
            // 헤더
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

            // 요금 행
            VStack(spacing: 12) {
                fareRow(label: "성인", amount: adultFare)
                fareRow(label: "청소년 (13-18세)", amount: youthFare)
                fareRow(label: "어린이 (6-12세)", amount: childFare)

                if let nightFare = viewModel.nightFare,
                   let startTime = viewModel.nightFareStartTime {
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
                            Text(formattedFare(nightFare))
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

    // MARK: - 길 찾기 버튼

    private var navigateButton: some View {
        Button {
            openMapsNavigation()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 16, weight: .medium))
                Text("길 찾기")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .white.opacity(0.1), radius: 20)
        }
        .buttonStyle(.plain)
    }

    private func openMapsNavigation() {
        let coord = mapPins.last?.coordinate
            ?? CLLocationCoordinate2D(latitude: 35.163329, longitude: 128.981845)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        item.name = destinationStop?.name ?? viewModel.currentArrivalStopName
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit])
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

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let mv = MKMapView()
        mv.delegate = context.coordinator
        mv.overrideUserInterfaceStyle = .dark
        mv.showsCompass = false
        mv.showsScale = false
        mv.isUserInteractionEnabled = false
        mv.pointOfInterestFilter = .excludingAll

        refresh(mv)
        return mv
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeAnnotations(uiView.annotations)
        uiView.removeOverlays(uiView.overlays)
        refresh(uiView)
    }

    private func refresh(_ mv: MKMapView) {
        guard !pins.isEmpty else { return }

        let coords = pins.map(\.coordinate)

        // 경로 선
        mv.addOverlay(MKPolyline(coordinates: coords, count: coords.count))

        // 핀
        mv.addAnnotations(pins)

        // 지도 범위를 모든 핀이 보이도록 조정
        let lats  = coords.map(\.latitude)
        let lngs  = coords.map(\.longitude)
        let minLat = lats.min()!,  maxLat = lats.max()!
        let minLng = lngs.min()!,  maxLng = lngs.max()!
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

    // MARK: Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let pl = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let r = MKPolylineRenderer(polyline: pl)
            r.strokeColor = UIColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 0.7)
            r.lineWidth = 2.5
            return r
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let pin = annotation as? StopPin else { return nil }
            let v = MKAnnotationView(annotation: annotation, reuseIdentifier: nil)
            v.canShowCallout = false

            if pin.isDestination {
                let size: CGFloat = 32
                let outer = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                outer.backgroundColor = UIColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 1)
                outer.layer.cornerRadius = size / 2
                outer.layer.borderColor = UIColor.white.cgColor
                outer.layer.borderWidth = 2
                outer.layer.shadowColor = UIColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 0.5).cgColor
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
                let size: CGFloat = 16
                let circle = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                circle.backgroundColor = UIColor(red: 51/255, green: 65/255, blue: 85/255, alpha: 1)
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
            label.font = pin.isDestination
                ? UIFont.boldSystemFont(ofSize: 12)
                : UIFont.systemFont(ofSize: 10, weight: .medium)
            label.sizeToFit()
            label.backgroundColor = UIColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 0.9)
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
    let isDestination: Bool
    var title: String? { stopName }

    init(coordinate: CLLocationCoordinate2D, stopName: String, isDestination: Bool) {
        self.coordinate = coordinate
        self.stopName = stopName
        self.isDestination = isDestination
    }
}

// MARK: - Preview

#Preview {
    struct Wrapper: View {
        @StateObject var vm = MainViewModel()
        var body: some View {
            // MapKit을 직접 로드하지 않도록 Preview에서는 간단한 placeholder 표시
            ZStack {
                Color.black.ignoresSafeArea()
                Text("정류장 위치 (시뮬레이터에서 확인)")
                    .foregroundStyle(.white)
            }
        }
    }
    return Wrapper()
}
