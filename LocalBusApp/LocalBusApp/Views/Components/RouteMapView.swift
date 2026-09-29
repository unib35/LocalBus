import SwiftUI
import UIKit
import MapKit
import CoreLocation

struct RouteMapPin: Equatable {
    let coordinate: CLLocationCoordinate2D
    let stopID: String
    let stopName: String
    /// 라벨에 덧붙일 정보 (출발 정류장의 탑승홈 등)
    var subtitle: String? = nil
    let isDeparture: Bool
    let isDestination: Bool

    static func == (lhs: RouteMapPin, rhs: RouteMapPin) -> Bool {
        lhs.stopID == rhs.stopID &&
        lhs.stopName == rhs.stopName &&
        lhs.subtitle == rhs.subtitle &&
        lhs.isDeparture == rhs.isDeparture &&
        lhs.isDestination == rhs.isDestination &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }

    /// 핀 라벨에서 이름 뒤에 붙는 역할. 출발은 탑승홈이 있으면 함께 적는다.
    var roleText: String? {
        if isDeparture { return subtitle.map { "출발 · \($0)" } ?? "출발" }
        if isDestination { return "도착" }
        return nil
    }
}

/// 핀 라벨을 놓는 쪽. 경로선이 지나가지 않는 쪽을 고른다.
enum RouteMapLabelPlacement: Equatable {
    case above, below

    /// 출발·종점은 이웃 정류장이 북쪽(화면 위)에 있으면 아래, 아니면 위. 중간 정류장은 위.
    static func placement(forPinAt index: Int, latitudes: [Double]) -> RouteMapLabelPlacement {
        guard latitudes.indices.contains(index), latitudes.count > 1 else { return .above }

        let neighborIndex: Int
        if index == 0 {
            neighborIndex = 1
        } else if index == latitudes.count - 1 {
            neighborIndex = index - 1
        } else {
            return .above
        }
        return latitudes[neighborIndex] > latitudes[index] ? .below : .above
    }
}

/// 지도 위 요소 색 — 경로만 강조색, 핀은 흰/검. 라벨은 두 모드 모두 어두운 모양 그대로.
///
/// 어두운 지도에서는 밝은 초록 한 줄, 밝은 지도에서는 짙은 초록에 흰 테두리를 둘러 도로 위에서도 보이게 한다.
private struct RouteMapTheme {
    let route: UIColor
    let routeWidth: CGFloat
    /// 경로선 아래에 까는 테두리. nil이면 그리지 않는다.
    let routeCasing: UIColor?
    let routeCasingWidth: CGFloat
    let departureFill: UIColor
    let departureRing: UIColor
    let destinationFill: UIColor
    let destinationRing: UIColor
    let stopFill: UIColor
    let stopRing: UIColor

    static let labelBackground = UIColor(white: 0.08, alpha: 1)          // #141414
    static let labelText = UIColor.white
    static let labelSecondaryText = UIColor(white: 0.64, alpha: 1)       // #A3A3A3

    static let dark = RouteMapTheme(
        route: UIColor(red: 74 / 255, green: 222 / 255, blue: 128 / 255, alpha: 1),   // #4ADE80
        routeWidth: 4,
        routeCasing: nil,
        routeCasingWidth: 0,
        departureFill: UIColor(red: 74 / 255, green: 222 / 255, blue: 128 / 255, alpha: 1),
        departureRing: UIColor(white: 0.04, alpha: 1),                                 // #0A0A0A
        destinationFill: UIColor(white: 0.04, alpha: 1),
        destinationRing: .white,
        stopFill: .white,
        stopRing: UIColor(white: 0.04, alpha: 1)
    )

    static let light = RouteMapTheme(
        route: UIColor(red: 21 / 255, green: 128 / 255, blue: 61 / 255, alpha: 1),    // #15803D
        routeWidth: 5,
        routeCasing: .white,
        routeCasingWidth: 9,
        departureFill: UIColor(red: 21 / 255, green: 128 / 255, blue: 61 / 255, alpha: 1),
        departureRing: .white,
        destinationFill: UIColor(white: 0.08, alpha: 1),                               // #141414
        destinationRing: .white,
        stopFill: .white,
        stopRing: UIColor(white: 0.08, alpha: 1)
    )

    static func theme(isDark: Bool) -> RouteMapTheme { isDark ? .dark : .light }
}

/// 경로선과 그 아래 테두리를 구분하기 위한 폴리라인.
private final class RoutePolyline: MKPolyline {
    var isCasing = false
}

struct RouteMapView: UIViewRepresentable {
    let pins: [RouteMapPin]
    /// 미리 추출한 도로 경로 좌표. nil이면 정류장 직선으로 폴백.
    let routePath: [CLLocationCoordinate2D]?
    let selectedStopID: String?
    let selectedCoordinate: CLLocationCoordinate2D?
    @Binding var centerOnUser: Bool
    @Binding var fitToRoute: Bool
    let colorScheme: ColorScheme
    /// 시트 상단 y (지도 좌표계). 시트에 가려지지 않는 영역 기준으로 fit/센터링한다.
    let sheetTopY: CGFloat
    var onPinTap: (String) -> Void
    var onLocationUpdate: ((CLLocation) -> Void)?
    /// 위치 권한이 꺼져 있어 현재 위치로 갈 수 없을 때
    var onLocationDenied: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsCompass = false
        mapView.showsScale = true
        mapView.pointOfInterestFilter = .excludingAll
        mapView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light

        context.coordinator.configure(mapView: mapView)
        context.coordinator.onPinTap = onPinTap
        context.coordinator.onLocationUpdate = onLocationUpdate
        context.coordinator.onLocationDenied = onLocationDenied
        context.coordinator.sheetTopY = sheetTopY
        context.coordinator.isDarkMap = colorScheme == .dark
        context.coordinator.updateRouteIfNeeded(
            pins,
            routePath: routePath,
            selectedStopID: selectedStopID,
            selectedCoordinate: selectedCoordinate,
            on: mapView,
            force: true
        )

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.onPinTap = onPinTap
        context.coordinator.onLocationUpdate = onLocationUpdate
        context.coordinator.onLocationDenied = onLocationDenied
        context.coordinator.sheetTopY = sheetTopY

        let isDarkMap = colorScheme == .dark
        let themeChanged = context.coordinator.isDarkMap != isDarkMap
        context.coordinator.isDarkMap = isDarkMap
        uiView.overrideUserInterfaceStyle = isDarkMap ? .dark : .light

        // 색 모드가 바뀌면 경로선과 핀을 새 색으로 다시 그린다. 이때 지도 위치는 건드리지 않는다.
        context.coordinator.updateRouteIfNeeded(
            pins,
            routePath: routePath,
            selectedStopID: selectedStopID,
            selectedCoordinate: selectedCoordinate,
            on: uiView,
            force: themeChanged,
            refitsRoute: !themeChanged
        )
        context.coordinator.updateSelectionIfNeeded(selectedStopID, on: uiView)
        context.coordinator.centerOnSelectedStopIfNeeded(
            selectedCoordinate,
            on: uiView
        )

        if centerOnUser {
            context.coordinator.centerOnUser(on: uiView)
            DispatchQueue.main.async {
                centerOnUser = false
            }
        }

        if fitToRoute {
            context.coordinator.fitRoute(pins, on: uiView)
            DispatchQueue.main.async {
                fitToRoute = false
            }
        }
    }
}

extension RouteMapView {
    final class Coordinator: NSObject, MKMapViewDelegate, CLLocationManagerDelegate {
        private let locationManager = CLLocationManager()
        private weak var mapView: MKMapView?
        private var lastRouteSignature: [RouteMapPin] = []
        private var lastPathSignature: [Double] = []
        private var lastSelectedStopID: String?
        private var pendingCenterOnUser = false
        private var lastCenteredCoordinate: CLLocationCoordinate2D?

        var onPinTap: ((String) -> Void)?
        var onLocationUpdate: ((CLLocation) -> Void)?
        var onLocationDenied: (() -> Void)?
        var sheetTopY: CGFloat = 0
        var isDarkMap = true

        private var theme: RouteMapTheme { .theme(isDark: isDarkMap) }

        override init() {
            super.init()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        }

        private var authorizationStatus: CLAuthorizationStatus { locationManager.authorizationStatus }

        func configure(mapView: MKMapView) {
            self.mapView = mapView
            updateUserLocationVisibility(on: mapView)

            if isAuthorizedForLocation {
                locationManager.requestLocation()
            }
        }

        func updateRouteIfNeeded(
            _ pins: [RouteMapPin],
            routePath: [CLLocationCoordinate2D]?,
            selectedStopID: String?,
            selectedCoordinate: CLLocationCoordinate2D?,
            on mapView: MKMapView,
            force: Bool = false,
            refitsRoute: Bool = true
        ) {
            let pathSignature: [Double] = routePath?.flatMap { [$0.latitude, $0.longitude] } ?? []
            let pinsChanged = pins != lastRouteSignature
            let pathChanged = pathSignature != lastPathSignature

            guard force || pinsChanged || pathChanged else { return }

            lastRouteSignature = pins
            lastPathSignature = pathSignature
            replaceRouteAnnotations(
                with: pins,
                routePath: routePath,
                selectedStopID: selectedStopID,
                on: mapView
            )

            if selectedCoordinate == nil, refitsRoute {
                fitRouteIfNeeded(pins, on: mapView)
            }
        }

        func updateSelectionIfNeeded(_ selectedStopID: String?, on mapView: MKMapView) {
            guard selectedStopID != lastSelectedStopID else { return }

            lastSelectedStopID = selectedStopID

            for annotation in mapView.annotations {
                guard let pin = annotation as? StopPin else { continue }
                let nextSelected = pin.stopID == selectedStopID
                guard pin.isSelected != nextSelected else { continue }

                pin.isSelected = nextSelected
                if let view = mapView.view(for: pin) as? StopPinAnnotationView {
                    view.apply(pin: pin, theme: theme)
                }
            }
        }

        /// 선택 정류장을 시트 위 영역의 가운데에 놓는다.
        func centerOnSelectedStopIfNeeded(
            _ coordinate: CLLocationCoordinate2D?,
            on mapView: MKMapView
        ) {
            guard let coordinate else {
                lastCenteredCoordinate = nil
                return
            }

            let isSameCoordinate = lastCenteredCoordinate.map {
                abs($0.latitude - coordinate.latitude) < 0.000001 &&
                abs($0.longitude - coordinate.longitude) < 0.000001
            } ?? false

            guard !isSameCoordinate else { return }

            lastCenteredCoordinate = coordinate

            let span = MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            var center = coordinate
            let mapHeight = mapView.frame.height

            if mapHeight > 0, sheetTopY > 0 {
                let visibleCenterY = sheetTopY / 2
                let pixelOffset = mapHeight / 2 - visibleCenterY
                let latitudeOffset = pixelOffset * span.latitudeDelta / mapHeight
                center = CLLocationCoordinate2D(
                    latitude: coordinate.latitude - latitudeOffset,
                    longitude: coordinate.longitude
                )
            }

            mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: true)
        }

        func fitRoute(_ pins: [RouteMapPin], on mapView: MKMapView) {
            fitRouteIfNeeded(pins, on: mapView)
        }

        func centerOnUser(on mapView: MKMapView) {
            if let userLocation = mapView.userLocation.location {
                centerMap(on: userLocation.coordinate, in: mapView)
                onLocationUpdate?(userLocation)
                return
            }

            pendingCenterOnUser = true

            switch authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                mapView.showsUserLocation = true
                locationManager.requestLocation()
            default:
                // 권한이 꺼져 있으면 조용히 넘기지 않고 알려 준다.
                pendingCenterOnUser = false
                onLocationDenied?()
            }
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            guard let mapView else { return }

            updateUserLocationVisibility(on: mapView)

            guard isAuthorizedForLocation else {
                pendingCenterOnUser = false
                return
            }

            locationManager.requestLocation()
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.last else { return }

            onLocationUpdate?(location)

            guard pendingCenterOnUser, let mapView else { return }

            pendingCenterOnUser = false
            centerMap(on: location.coordinate, in: mapView)
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            pendingCenterOnUser = false
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let pin = view.annotation as? StopPin else { return }

            mapView.deselectAnnotation(view.annotation, animated: false)
            onPinTap?(pin.stopID)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let isCasing = (polyline as? RoutePolyline)?.isCasing ?? false
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = isCasing ? (theme.routeCasing ?? theme.route) : theme.route
            renderer.lineWidth = isCasing ? theme.routeCasingWidth : theme.routeWidth
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let pin = annotation as? StopPin else { return nil }

            let view = mapView.dequeueReusableAnnotationView(withIdentifier: StopPinAnnotationView.reuseIdentifier) as? StopPinAnnotationView
                ?? StopPinAnnotationView(annotation: annotation, reuseIdentifier: StopPinAnnotationView.reuseIdentifier)
            view.annotation = annotation
            view.apply(pin: pin, theme: theme)
            return view
        }

        private var isAuthorizedForLocation: Bool {
            switch authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                return true
            default:
                return false
            }
        }

        private func updateUserLocationVisibility(on mapView: MKMapView) {
            mapView.showsUserLocation = isAuthorizedForLocation
        }

        private func replaceRouteAnnotations(
            with pins: [RouteMapPin],
            routePath: [CLLocationCoordinate2D]?,
            selectedStopID: String?,
            on mapView: MKMapView
        ) {
            let customAnnotations = mapView.annotations.filter { $0 is StopPin }
            mapView.removeAnnotations(customAnnotations)
            mapView.removeOverlays(mapView.overlays)

            let latitudes = pins.map(\.coordinate.latitude)
            let annotations = pins.enumerated().map { index, pin in
                StopPin(
                    pin: pin,
                    isSelected: pin.stopID == selectedStopID,
                    labelPlacement: RouteMapLabelPlacement.placement(forPinAt: index, latitudes: latitudes)
                )
            }

            // routePath가 있으면 도로 경로, 없으면 정류장 직선으로 폴백
            let coordinates: [CLLocationCoordinate2D]
            if let path = routePath, path.count > 1 {
                coordinates = path
            } else if annotations.count > 1 {
                coordinates = annotations.map(\.coordinate)
            } else {
                coordinates = []
            }

            if coordinates.isEmpty == false {
                // 테두리를 먼저 깔고 그 위에 경로선
                if theme.routeCasing != nil {
                    let casing = RoutePolyline(coordinates: coordinates, count: coordinates.count)
                    casing.isCasing = true
                    mapView.addOverlay(casing)
                }
                mapView.addOverlay(RoutePolyline(coordinates: coordinates, count: coordinates.count))
            }

            mapView.addAnnotations(annotations)
            lastSelectedStopID = selectedStopID
        }

        /// 시트에 가려지는 아래쪽을 제외한 영역에 노선 전체가 들어오도록 맞춘다.
        private func fitRouteIfNeeded(_ pins: [RouteMapPin], on mapView: MKMapView) {
            guard pins.isEmpty == false else { return }

            var rect = MKMapRect.null
            for pin in pins {
                let point = MKMapPoint(pin.coordinate)
                rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
            }

            let mapHeight = mapView.frame.height
            let coveredBySheet = (mapHeight > 0 && sheetTopY > 0) ? max(mapHeight - sheetTopY, 0) : 0
            let padding = UIEdgeInsets(
                top: 120,
                left: 48,
                bottom: coveredBySheet + 40,
                right: 48
            )

            mapView.setVisibleMapRect(rect, edgePadding: padding, animated: true)
        }

        private func centerMap(on coordinate: CLLocationCoordinate2D, in mapView: MKMapView) {
            let span = MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            mapView.setRegion(MKCoordinateRegion(center: coordinate, span: span), animated: true)
        }
    }
}

private final class StopPin: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let stopID: String
    let stopName: String
    /// 이름 뒤에 붙는 역할 ("출발", "출발 · 20번 홈", "도착")
    let roleText: String?
    let isDeparture: Bool
    let isDestination: Bool
    let labelPlacement: RouteMapLabelPlacement
    var isSelected: Bool
    var title: String? { stopName }

    init(pin: RouteMapPin, isSelected: Bool, labelPlacement: RouteMapLabelPlacement) {
        self.coordinate = pin.coordinate
        self.stopID = pin.stopID
        self.stopName = pin.stopName
        self.roleText = pin.roleText
        self.isDeparture = pin.isDeparture
        self.isDestination = pin.isDestination
        self.labelPlacement = labelPlacement
        self.isSelected = isSelected
    }
}

/// 핀: 출발 = 강조색 원, 종점 = 어두운 원 + 흰 링, 중간 = 작은 흰 점. 선택 시 조금 커지고 라벨이 붙는다.
private final class StopPinAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "StopPin"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        canShowCallout = false
        isAccessibilityElement = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(pin: StopPin, theme: RouteMapTheme) {
        accessibilityLabel = pin.roleText.map { "\(pin.stopName) \($0)" } ?? pin.stopName
        accessibilityHint = pin.isDeparture
            ? "출발 정류장"
            : (pin.isDestination ? "종점 정류장" : "중간 정류장, 탭하면 상세 정보를 볼 수 있습니다")

        subviews.forEach { $0.removeFromSuperview() }

        let pinSize: CGFloat
        let dot: UIView

        if pin.isDeparture {
            pinSize = pin.isSelected ? 22 : 18
            dot = UIView(frame: CGRect(x: 0, y: 0, width: pinSize, height: pinSize))
            dot.backgroundColor = theme.departureFill
            dot.layer.borderColor = theme.departureRing.cgColor
            dot.layer.borderWidth = 3
        } else if pin.isDestination {
            pinSize = pin.isSelected ? 22 : 18
            dot = UIView(frame: CGRect(x: 0, y: 0, width: pinSize, height: pinSize))
            dot.backgroundColor = theme.destinationFill
            dot.layer.borderColor = theme.destinationRing.cgColor
            dot.layer.borderWidth = 3
        } else {
            pinSize = pin.isSelected ? 14 : 10
            dot = UIView(frame: CGRect(x: 0, y: 0, width: pinSize, height: pinSize))
            dot.backgroundColor = theme.stopFill
            dot.layer.borderColor = theme.stopRing.cgColor
            dot.layer.borderWidth = 2
        }
        dot.layer.cornerRadius = pinSize / 2
        addSubview(dot)
        frame = CGRect(x: 0, y: 0, width: pinSize, height: pinSize)
        centerOffset = .zero

        let shouldShowLabel = pin.isDeparture || pin.isDestination || pin.isSelected
        guard shouldShowLabel else { return }

        let label = makeLabel(for: pin)
        let labelWidth = label.intrinsicContentSize.width + 20
        let labelHeight: CGFloat = 28
        let gap: CGFloat = 7
        let totalWidth = max(pinSize, labelWidth)
        let isAbove = pin.labelPlacement == .above

        label.frame = CGRect(
            x: (totalWidth - labelWidth) / 2,
            y: isAbove ? 0 : pinSize + gap,
            width: labelWidth,
            height: labelHeight
        )
        dot.frame.origin = CGPoint(
            x: (totalWidth - pinSize) / 2,
            y: isAbove ? labelHeight + gap : 0
        )
        addSubview(label)
        frame = CGRect(x: 0, y: 0, width: totalWidth, height: pinSize + gap + labelHeight)
        // 앵커는 핀 중심에 두고 라벨은 위나 아래로 늘어난다.
        let shift = (gap + labelHeight) / 2
        centerOffset = CGPoint(x: 0, y: isAbove ? -shift : shift)
    }

    private func makeLabel(for pin: StopPin) -> UILabel {
        let label = UILabel()
        let name = NSMutableAttributedString(
            string: pin.stopName,
            attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: RouteMapTheme.labelText
            ]
        )
        if let role = pin.roleText {
            name.append(NSAttributedString(
                string: "  \(role)",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: RouteMapTheme.labelSecondaryText
                ]
            ))
        }
        label.attributedText = name
        label.backgroundColor = RouteMapTheme.labelBackground
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.sizeToFit()
        return label
    }
}
