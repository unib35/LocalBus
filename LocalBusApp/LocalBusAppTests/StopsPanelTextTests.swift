import Testing
import Foundation
import CoreLocation
@testable import JangyuBus

struct StopsPanelTextTests {

    @Test func 남은_시간은_60분_배수일_때_분을_생략한다() {
        #expect(StopsPanelText.untilText(minutes: 0) == "곧 출발")
        #expect(StopsPanelText.untilText(minutes: -3) == "곧 출발")
        #expect(StopsPanelText.untilText(minutes: 12) == "12분 후")
        #expect(StopsPanelText.untilText(minutes: 60) == "1시간 후")
        #expect(StopsPanelText.untilText(minutes: 72) == "1시간 12분 후")
        #expect(StopsPanelText.untilText(minutes: 120) == "2시간 후")
    }

    @Test func 목록_요약은_정류장_수_소요_탑승홈_기준_버스_순서다() {
        let full = StopsPanelText.listSummary(stopCount: 6, durationMinutes: 26, platform: "20번 홈", busTime: "07:20")
        #expect(full == "정류장 6곳 · 26분 소요 · 20번 홈에서 탑승 · 07:20 버스 기준")
    }

    @Test func 목록_요약은_없는_값을_건너뛴다() {
        let noPlatform = StopsPanelText.listSummary(stopCount: 6, durationMinutes: 26, platform: nil, busTime: "07:20")
        #expect(noPlatform == "정류장 6곳 · 26분 소요 · 07:20 버스 기준")
        let noBus = StopsPanelText.listSummary(stopCount: 3, durationMinutes: 30, platform: "19번 홈", busTime: nil)
        #expect(noBus == "정류장 3곳 · 30분 소요 · 19번 홈에서 탑승")
    }

    @Test func 도보_거리는_분과_거리를_함께_적는다() {
        #expect(StopsPanelText.walkText(meters: 450) == "도보 6분 (450m)")
        #expect(StopsPanelText.walkText(meters: 30) == "도보 1분 (30m)")
        #expect(StopsPanelText.walkText(meters: 1540) == "도보 19분 (1.5km)")
    }

    @Test func 출발_행_보조_줄은_탑승홈과_도보_거리를_붙인다() {
        #expect(StopsPanelText.departureDetail(platform: "20번 홈", walk: "도보 6분 (450m)") == "출발 · 20번 홈 · 도보 6분 (450m)")
        #expect(StopsPanelText.departureDetail(platform: nil, walk: "도보 6분 (450m)") == "출발 · 도보 6분 (450m)")
        #expect(StopsPanelText.departureDetail(platform: nil, walk: nil) == "출발")
    }

    @Test func 종점_행_보조_줄은_주소를_붙인다() {
        #expect(StopsPanelText.destinationDetail(address: "부산광역시 사상구 괘법동") == "종점 · 부산광역시 사상구 괘법동")
        #expect(StopsPanelText.destinationDetail(address: nil) == "종점")
    }

    @Test func 통과_시각은_고른_버스의_출발과_도착을_따른다() {
        #expect(StopsPanelText.passTime(index: 0, count: 6, departure: "18:50", arrival: "19:24") == "18:50")
        #expect(StopsPanelText.passTime(index: 2, count: 6, departure: "18:50", arrival: "19:24") == "18:52")
        #expect(StopsPanelText.passTime(index: 5, count: 6, departure: "18:50", arrival: "19:24") == "19:24")
        #expect(StopsPanelText.passTime(index: 1, count: 6, departure: nil, arrival: "19:24") == "--:--")
    }

    @Test func 핀_라벨_역할은_출발과_도착을_붙인다() {
        let coordinate = CLLocationCoordinate2D(latitude: 35.2, longitude: 128.8)
        let departure = RouteMapPin(coordinate: coordinate, stopID: "a", stopName: "사상터미널", subtitle: "20번 홈", isDeparture: true, isDestination: false)
        #expect(departure.roleText == "출발 · 20번 홈")
        let plainDeparture = RouteMapPin(coordinate: coordinate, stopID: "a", stopName: "갑을장유병원정류소", isDeparture: true, isDestination: false)
        #expect(plainDeparture.roleText == "출발")
        let destination = RouteMapPin(coordinate: coordinate, stopID: "b", stopName: "사상터미널", isDeparture: false, isDestination: true)
        #expect(destination.roleText == "도착")
        let middle = RouteMapPin(coordinate: coordinate, stopID: "c", stopName: "코아상가", isDeparture: false, isDestination: false)
        #expect(middle.roleText == nil)
    }

    @Test func 핀_라벨은_경로가_지나가지_않는_쪽에_놓는다() {
        // 장유(북) → 사상(남): 출발 핀에서 경로는 아래로 내려가므로 라벨은 위
        let southbound = [35.2078, 35.2070, 35.2060, 35.1633]
        #expect(RouteMapLabelPlacement.placement(forPinAt: 0, latitudes: southbound) == .above)
        // 종점에서는 경로가 위에서 내려오므로 라벨은 아래
        #expect(RouteMapLabelPlacement.placement(forPinAt: 3, latitudes: southbound) == .below)
        // 중간 정류장은 위
        #expect(RouteMapLabelPlacement.placement(forPinAt: 1, latitudes: southbound) == .above)

        let northbound = Array(southbound.reversed())
        #expect(RouteMapLabelPlacement.placement(forPinAt: 0, latitudes: northbound) == .below)
        #expect(RouteMapLabelPlacement.placement(forPinAt: 3, latitudes: northbound) == .above)
        // 정류장이 하나뿐이면 위
        #expect(RouteMapLabelPlacement.placement(forPinAt: 0, latitudes: [35.2]) == .above)
    }
}
