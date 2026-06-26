#if DEBUG
import Foundation
import MapKit
import CoreLocation

/// 인접 정류장 사이를 MKDirections로 순차 조회해 도로 좌표를 모은 뒤
/// timetable.json의 `path` 필드에 그대로 붙여 넣을 수 있는 JSON 문자열을 콘솔에 출력한다.
///
/// 사용:
/// 1) 디버그 빌드에서 지도 우상단의 "경로 추출" 버튼 탭
/// 2) 콘솔에 찍힌 `"path": [[...], ...]` 블록을 timetable.json의 해당 노선에 복사
enum RoutePathExporter {
    static func exportPath(
        for direction: RouteDirection,
        stops: [BusStop],
        transportType: MKDirectionsTransportType = .automobile
    ) async {
        let coords: [(String, CLLocationCoordinate2D)] = stops.compactMap { stop in
            guard let lat = stop.latitude, let lng = stop.longitude else { return nil }
            return (stop.name, CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }

        guard coords.count >= 2 else {
            print("⚠️ [RoutePathExporter] \(direction.rawValue): 좌표가 2개 미만이라 추출 불가")
            return
        }

        print("🛣️ [RoutePathExporter] \(direction.rawValue) 경로 추출 시작 (\(coords.count - 1) 구간)")

        var merged: [CLLocationCoordinate2D] = []

        for index in 0..<(coords.count - 1) {
            let (fromName, from) = coords[index]
            let (toName, to)     = coords[index + 1]

            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
            request.transportType = transportType

            do {
                let response = try await MKDirections(request: request).calculate()
                guard let route = response.routes.first else {
                    print("⚠️ [\(index + 1)/\(coords.count - 1)] \(fromName) → \(toName): 경로 없음")
                    continue
                }

                let segment = route.polyline.coordinates
                if merged.isEmpty {
                    merged.append(contentsOf: segment)
                } else if let last = merged.last,
                          let first = segment.first,
                          areClose(last, first) {
                    merged.append(contentsOf: segment.dropFirst())
                } else {
                    merged.append(contentsOf: segment)
                }

                print("✅ [\(index + 1)/\(coords.count - 1)] \(fromName) → \(toName): \(segment.count) pts")
            } catch {
                print("❌ [\(index + 1)/\(coords.count - 1)] \(fromName) → \(toName): \(error.localizedDescription)")
            }

            // Apple throttling 회피
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        print("🛣️ [RoutePathExporter] 총 \(merged.count) pts")
        print(formattedJSON(direction: direction, points: merged))
    }

    private static func areClose(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        abs(a.latitude - b.latitude) < 0.00001 && abs(a.longitude - b.longitude) < 0.00001
    }

    private static func formattedJSON(direction: RouteDirection, points: [CLLocationCoordinate2D]) -> String {
        let lines = points.map { String(format: "    [%.6f, %.6f]", $0.latitude, $0.longitude) }
        return """

        ───── \(direction.rawValue) — timetable.json에 붙여넣기 ─────
        "path": [
        \(lines.joined(separator: ",\n"))
        ]
        ─────────────────────────────────────────────
        """
    }
}

private extension MKPolyline {
    /// MKPolyline의 좌표를 Swift 배열로 변환
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
#endif
