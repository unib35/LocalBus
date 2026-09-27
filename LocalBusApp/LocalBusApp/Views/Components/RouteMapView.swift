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
}

/// 지도 위 요소 색. 앱 토큰(AppTheme)과 같은 값 — 경로만 강조색, 핀은 흰/검.
private enum RouteMapTheme {
    static let accent = UIColor(red: 74 / 255, green: 222 / 255, blue: 128 / 255, alpha: 1)
    static let pinFill = UIColor.white
    static let pinRing = UIColor(white: 0.04, alpha: 1)
    static let labelBackground = UIColor(white: 0.08, alpha: 1)
    static let labelText = UIColor.white
    static let labelSecondaryText = UIColor(white: 0.64, alpha: 1)
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

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsCompass = false
        mapView.showsScale = true
        mapView.pointOfInterestFilter = .excludingAll

        context.coordinator.configure(mapView: mapView)
        context.coordinator.onPinTap = onPinTap
        context.coordinator.onLocationUpdate = onLocationUpdate
        context.coordinator.sheetTopY = sheetTopY
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
        context.coordinator.sheetTopY = sheetTopY

        uiView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light

        context.coordinator.updateRouteIfNeeded(
            pins,
            routePath: routePath,
            selectedStopID: selectedStopID,
            selectedCoordinate: selectedCoordinate,
            on: uiView
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
        var sheetTopY: CGFloat = 0

        override init() {
            super.init()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        }

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
            force: Bool = false
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

            if selectedCoordinate == nil {
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
                    view.apply(pin: pin)
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

            switch locationManager.authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                mapView.showsUserLocation = true
                locationManager.requestLocation()
            default:
                pendingCenterOnUser = false
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

            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = RouteMapTheme.accent
            renderer.lineWidth = 4
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let pin = annotation as? StopPin else { return nil }

            let view = mapView.dequeueReusableAnnotationView(withIdentifier: StopPinAnnotationView.reuseIdentifier) as? StopPinAnnotationView
                ?? StopPinAnnotationView(annotation: annotation, reuseIdentifier: StopPinAnnotationView.reuseIdentifier)
            view.annotation = annotation
            view.apply(pin: pin)
            return view
        }

        private var isAuthorizedForLocation: Bool {
            switch locationManager.authorizationStatus {
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

            let annotations = pins.map {
                StopPin(pin: $0, isSelected: $0.stopID == selectedStopID)
            }

            // routePath가 있으면 도로 경로, 없으면 정류장 직선으로 폴백
            if let path = routePath, path.count > 1 {
                mapView.addOverlay(MKPolyline(coordinates: path, count: path.count))
            } else if annotations.count > 1 {
                let coordinates = annotations.map(\.coordinate)
                mapView.addOverlay(MKPolyline(coordinates: coordinates, count: coordinates.count))
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
    let subtitleText: String?
    let isDeparture: Bool
    let isDestination: Bool
    var isSelected: Bool
    var title: String? { stopName }

    init(pin: RouteMapPin, isSelected: Bool) {
        self.coordinate = pin.coordinate
        self.stopID = pin.stopID
        self.stopName = pin.stopName
        self.subtitleText = pin.subtitle
        self.isDeparture = pin.isDeparture
        self.isDestination = pin.isDestination
        self.isSelected = isSelected
    }
}

/// 핀: 출발 = 강조색 원, 종점 = 흰 링, 중간 = 작은 흰 점. 선택 시 조금 커지고 라벨이 붙는다.
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

    func apply(pin: StopPin) {
        accessibilityLabel = pin.stopName
        accessibilityHint = pin.isDeparture
            ? "출발 정류장"
            : (pin.isDestination ? "종점 정류장" : "중간 정류장, 탭하면 상세 정보를 볼 수 있습니다")

        subviews.forEach { $0.removeFromSuperview() }

        let pinSize: CGFloat
        let dot: UIView

        if pin.isDeparture {
            pinSize = pin.isSelected ? 22 : 18
            dot = UIView(frame: CGRect(x: 0, y: 0, width: pinSize, height: pinSize))
            dot.backgroundColor = RouteMapTheme.accent
            dot.layer.borderColor = RouteMapTheme.pinRing.cgColor
            dot.layer.borderWidth = 3
        } else if pin.isDestination {
            pinSize = pin.isSelected ? 22 : 18
            dot = UIView(frame: CGRect(x: 0, y: 0, width: pinSize, height: pinSize))
            dot.backgroundColor = RouteMapTheme.pinRing
            dot.layer.borderColor = RouteMapTheme.pinFill.cgColor
            dot.layer.borderWidth = 3
        } else {
            pinSize = pin.isSelected ? 14 : 10
            dot = UIView(frame: CGRect(x: 0, y: 0, width: pinSize, height: pinSize))
            dot.backgroundColor = RouteMapTheme.pinFill
            dot.layer.borderColor = RouteMapTheme.pinRing.cgColor
            dot.layer.borderWidth = 2
        }
        dot.layer.cornerRadius = pinSize / 2
        addSubview(dot)
        frame = CGRect(x: 0, y: 0, width: pinSize, height: pinSize)

        let shouldShowLabel = pin.isDeparture || pin.isDestination || pin.isSelected
        guard shouldShowLabel else { return }

        let label = makeLabel(for: pin)
        let labelWidth = label.intrinsicContentSize.width + 20
        let labelHeight: CGFloat = 26
        let totalWidth = max(pinSize, labelWidth)

        label.frame = CGRect(
            x: (totalWidth - labelWidth) / 2,
            y: pinSize + 6,
            width: labelWidth,
            height: labelHeight
        )
        dot.frame.origin.x = (totalWidth - pinSize) / 2
        addSubview(label)
        frame = CGRect(x: 0, y: 0, width: totalWidth, height: pinSize + 6 + labelHeight)
        // 앵커는 핀 중심에 두고 라벨은 아래로 늘어난다.
        centerOffset = CGPoint(x: 0, y: (6 + labelHeight) / 2)
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
        if let subtitle = pin.subtitleText {
            name.append(NSAttributedString(
                string: "  \(subtitle)",
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
