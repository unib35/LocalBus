import SwiftUI
import UIKit
import MapKit
import CoreLocation

struct RouteMapPin: Equatable {
    let coordinate: CLLocationCoordinate2D
    let stopID: String
    let stopName: String
    let isDeparture: Bool
    let isDestination: Bool

    static func == (lhs: RouteMapPin, rhs: RouteMapPin) -> Bool {
        lhs.stopID == rhs.stopID &&
        lhs.stopName == rhs.stopName &&
        lhs.isDeparture == rhs.isDeparture &&
        lhs.isDestination == rhs.isDestination &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

private enum RouteMapTheme {
    static let primaryBlue = UIColor(red: 59 / 255, green: 130 / 255, blue: 246 / 255, alpha: 1)
    static let departureGreen = UIColor(red: 74 / 255, green: 222 / 255, blue: 128 / 255, alpha: 1)
    static let stopBackground = UIColor(red: 51 / 255, green: 65 / 255, blue: 85 / 255, alpha: 1)
    static let labelBackground = UIColor(red: 30 / 255, green: 41 / 255, blue: 59 / 255, alpha: 0.9)
    static let selectedLabelBackground = UIColor(red: 30 / 255, green: 50 / 255, blue: 100 / 255, alpha: 0.95)
}

struct RouteMapView: UIViewRepresentable {
    let pins: [RouteMapPin]
    let selectedStopID: String?
    let selectedCoordinate: CLLocationCoordinate2D?
    @Binding var centerOnUser: Bool
    let colorScheme: ColorScheme
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
        mapView.showsScale = false
        mapView.pointOfInterestFilter = .excludingAll

        context.coordinator.configure(mapView: mapView)
        context.coordinator.onPinTap = onPinTap
        context.coordinator.onLocationUpdate = onLocationUpdate
        context.coordinator.updateRouteIfNeeded(
            pins,
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

        uiView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light

        context.coordinator.updateRouteIfNeeded(
            pins,
            selectedStopID: selectedStopID,
            selectedCoordinate: selectedCoordinate,
            on: uiView
        )
        context.coordinator.updateSelectionIfNeeded(selectedStopID, on: uiView)
        context.coordinator.centerOnSelectedStopIfNeeded(
            selectedCoordinate,
            sheetTopY: sheetTopY,
            on: uiView
        )

        if centerOnUser {
            context.coordinator.centerOnUser(on: uiView)
            DispatchQueue.main.async {
                centerOnUser = false
            }
        }
    }
}

extension RouteMapView {
    final class Coordinator: NSObject, MKMapViewDelegate, CLLocationManagerDelegate {
        private let locationManager = CLLocationManager()
        private weak var mapView: MKMapView?
        private var lastRouteSignature: [RouteMapPin] = []
        private var lastSelectedStopID: String?
        private var pendingCenterOnUser = false
        private var lastCenteredCoordinate: CLLocationCoordinate2D?

        var onPinTap: ((String) -> Void)?
        var onLocationUpdate: ((CLLocation) -> Void)?

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
            selectedStopID: String?,
            selectedCoordinate: CLLocationCoordinate2D?,
            on mapView: MKMapView,
            force: Bool = false
        ) {
            guard force || pins != lastRouteSignature else { return }

            lastRouteSignature = pins
            replaceRouteAnnotations(with: pins, selectedStopID: selectedStopID, on: mapView)

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

        func centerOnSelectedStopIfNeeded(
            _ coordinate: CLLocationCoordinate2D?,
            sheetTopY: CGFloat,
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
            renderer.strokeColor = RouteMapTheme.primaryBlue.withAlphaComponent(0.7)
            renderer.lineWidth = 2.5
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
            selectedStopID: String?,
            on mapView: MKMapView
        ) {
            let customAnnotations = mapView.annotations.filter { $0 is StopPin }
            mapView.removeAnnotations(customAnnotations)
            mapView.removeOverlays(mapView.overlays)

            let annotations = pins.map {
                StopPin(pin: $0, isSelected: $0.stopID == selectedStopID)
            }

            if annotations.count > 1 {
                let coordinates = annotations.map(\.coordinate)
                mapView.addOverlay(MKPolyline(coordinates: coordinates, count: coordinates.count))
            }

            mapView.addAnnotations(annotations)
            lastSelectedStopID = selectedStopID
        }

        private func fitRouteIfNeeded(_ pins: [RouteMapPin], on mapView: MKMapView) {
            guard pins.isEmpty == false else { return }

            let latitudes = pins.map(\.coordinate.latitude)
            let longitudes = pins.map(\.coordinate.longitude)

            guard
                let minLatitude = latitudes.min(),
                let maxLatitude = latitudes.max(),
                let minLongitude = longitudes.min(),
                let maxLongitude = longitudes.max()
            else {
                return
            }

            let center = CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            )
            let span = MKCoordinateSpan(
                latitudeDelta: max((maxLatitude - minLatitude) * 1.4, 0.01),
                longitudeDelta: max((maxLongitude - minLongitude) * 1.4, 0.01)
            )

            mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: true)
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
    let isDeparture: Bool
    let isDestination: Bool
    var isSelected: Bool
    var title: String? { stopName }

    init(pin: RouteMapPin, isSelected: Bool) {
        self.coordinate = pin.coordinate
        self.stopID = pin.stopID
        self.stopName = pin.stopName
        self.isDeparture = pin.isDeparture
        self.isDestination = pin.isDestination
        self.isSelected = isSelected
    }
}

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

        if pin.isDeparture {
            let size: CGFloat = pin.isSelected ? 28 : 20
            let circle = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            circle.backgroundColor = RouteMapTheme.departureGreen
            circle.layer.cornerRadius = size / 2
            circle.layer.borderColor = UIColor.white.cgColor
            circle.layer.borderWidth = pin.isSelected ? 2.5 : 2

            if pin.isSelected {
                circle.layer.shadowColor = RouteMapTheme.departureGreen.withAlphaComponent(0.8).cgColor
                circle.layer.shadowRadius = 10
                circle.layer.shadowOpacity = 1
                circle.layer.shadowOffset = .zero
            }

            addSubview(circle)
            frame = CGRect(x: 0, y: 0, width: size, height: size)
        } else if pin.isDestination {
            let size: CGFloat = pin.isSelected ? 36 : 32
            let outer = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            outer.backgroundColor = RouteMapTheme.primaryBlue
            outer.layer.cornerRadius = size / 2
            outer.layer.borderColor = UIColor.white.cgColor
            outer.layer.borderWidth = pin.isSelected ? 2.5 : 2
            outer.layer.shadowColor = RouteMapTheme.primaryBlue.withAlphaComponent(pin.isSelected ? 0.8 : 0.5).cgColor
            outer.layer.shadowRadius = pin.isSelected ? 10 : 8
            outer.layer.shadowOpacity = 1
            outer.layer.shadowOffset = .zero

            let dotSize: CGFloat = size / 3
            let dot = UIView(
                frame: CGRect(
                    x: (size - dotSize) / 2,
                    y: (size - dotSize) / 2,
                    width: dotSize,
                    height: dotSize
                )
            )
            dot.backgroundColor = .white
            dot.layer.cornerRadius = dotSize / 2

            outer.addSubview(dot)
            addSubview(outer)
            frame = CGRect(x: 0, y: 0, width: size, height: size)
        } else if pin.isSelected {
            let size: CGFloat = 28
            let outer = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            outer.backgroundColor = RouteMapTheme.primaryBlue
            outer.layer.cornerRadius = size / 2
            outer.layer.borderColor = UIColor.white.cgColor
            outer.layer.borderWidth = 2.5
            outer.layer.shadowColor = RouteMapTheme.primaryBlue.withAlphaComponent(0.8).cgColor
            outer.layer.shadowRadius = 10
            outer.layer.shadowOpacity = 1
            outer.layer.shadowOffset = .zero
            addSubview(outer)
            frame = CGRect(x: 0, y: 0, width: size, height: size)
        } else {
            let size: CGFloat = 16
            let circle = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            circle.backgroundColor = RouteMapTheme.stopBackground
            circle.layer.cornerRadius = size / 2
            circle.layer.borderColor = UIColor.white.cgColor
            circle.layer.borderWidth = 2
            addSubview(circle)
            frame = CGRect(x: 0, y: 0, width: size, height: size)
        }

        let label = UILabel()
        label.text = pin.stopName
        label.textColor = .white
        label.font = pin.isDestination || pin.isDeparture
            ? UIFont.boldSystemFont(ofSize: 12)
            : UIFont.systemFont(ofSize: 10, weight: .medium)
        label.sizeToFit()
        label.backgroundColor = pin.isSelected
            ? RouteMapTheme.selectedLabelBackground
            : RouteMapTheme.labelBackground
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true

        let labelWidth = label.intrinsicContentSize.width + 16
        let labelHeight: CGFloat = 20
        let pinSize = frame.width
        let totalWidth = max(pinSize, labelWidth)

        label.frame = CGRect(
            x: (totalWidth - labelWidth) / 2,
            y: pinSize + 6,
            width: labelWidth,
            height: labelHeight
        )
        addSubview(label)
        frame = CGRect(x: 0, y: 0, width: totalWidth, height: pinSize + 6 + labelHeight)
    }
}
