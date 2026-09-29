import Testing
@testable import JangyuBus

struct OnboardingRouteDescriptionTests {

    @Test func 정류소_꼬리말을_떼고_소요시간과_요금을_붙인다() {
        let text = OnboardingRouteDescription.text(
            areaName: "장유", stopName: "갑을장유병원정류소", platform: nil, durationMinutes: 26, fare: 2500
        )
        #expect(text == "갑을장유병원 출발 · 26분 · 2,500원")
    }

    @Test func 탑승홈은_출발지_이름_뒤에_붙는다() {
        let text = OnboardingRouteDescription.text(
            areaName: "사상", stopName: "사상터미널", platform: "20번 홈", durationMinutes: 31, fare: nil
        )
        #expect(text == "사상터미널 20번 홈 출발 · 31분")
    }

    @Test func 정류장_이름에_지역이_없으면_지역을_앞에_둔다() {
        let text = OnboardingRouteDescription.text(
            areaName: "율하", stopName: "김해외고", platform: nil, durationMinutes: nil, fare: nil
        )
        #expect(text == "율하 (김해외고) 출발")
    }

    @Test func 시간표가_아직_없으면_지역_이름만_쓴다() {
        let text = OnboardingRouteDescription.text(
            areaName: "장유", stopName: nil, platform: nil, durationMinutes: nil, fare: 0
        )
        #expect(text == "장유 출발")
    }
}
