import Testing
import Foundation
@testable import LocalBusApp

@Suite(.serialized)
@MainActor
struct UpcomingBusesStatusTests {

    // MARK: - Helper: ViewModel 생성

    /// 주어진 시간표와 현재 시각으로 ViewModel을 구성한다.
    /// nightFareStartTime 이 있으면 routes 기반, 없으면 timetable 기반으로 데이터를 만든다.
    private func makeViewModel(
        times: [String],
        currentTime: Date,
        nightFareStartTime: String? = nil
    ) async -> MainViewModel {
        let vm = MainViewModel()

        let data: TimetableData
        if let nightStart = nightFareStartTime {
            let routeData = RouteData(
                name: "테스트 노선",
                durationMinutes: 60,
                fare: 3000,
                nightFare: 4000,
                nightFareStartTime: nightStart,
                platformNumber: nil,
                viaTimes: nil,
                stops: [],
                timetable: Timetable(weekday: times, weekend: [])
            )
            data = TimetableData(
                meta: makeMeta(),
                holidays: [],
                timetable: nil,
                routes: [RouteDirection.jangyuToSasang.rawValue: routeData]
            )
        } else {
            data = TimetableData(
                meta: makeMeta(),
                holidays: [],
                timetable: Timetable(weekday: times, weekend: []),
                routes: nil
            )
        }

        await vm.loadTimetable(with: data)
        vm.selectedScheduleType = .weekday
        vm.currentTime = currentTime
        return vm
    }

    private func makeMeta() -> Meta {
        Meta(version: 1, updatedAt: "2026-01-01", noticeMessage: nil, contactEmail: "test@test.com")
    }

    /// "HH:mm" 형식의 시각 문자열로 오늘 날짜 Date를 만든다.
    private func makeTime(hhmm: String) -> Date {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 1
        comps.day = 14
        comps.hour = parts[0]
        comps.minute = parts[1]
        comps.second = 0
        comps.timeZone = TimeZone(identifier: "Asia/Seoul")
        return Calendar.current.date(from: comps)!
    }

    // MARK: - 막차 관련

    @Test func 오늘버스3개_limit5_세번째만_막차() async {
        // Given: 현재 시각 09:00, 오늘 버스 10:00 11:00 12:00 (3개)
        let times = ["10:00", "11:00", "12:00"]
        let now = makeTime(hhmm: "09:00")
        let vm = await makeViewModel(times: times, currentTime: now)

        // When
        let result = vm.buildUpcomingBuses(limit: 5)

        // Then: 3개 반환, 마지막만 막차
        #expect(result.count == 3)
        #expect(result[0].statusText == "정시 운행")
        #expect(result[0].statusKind == .onTime)
        #expect(result[1].statusText == "정시 운행")
        #expect(result[1].statusKind == .onTime)
        #expect(result[2].statusText == "막차")
        #expect(result[2].statusKind == .lastBus)
    }

    @Test func 오늘버스10개_limit3_모두_정시운행() async {
        // Given: 버스 10개, 현재 시각 첫차 이전 → limit 3 안에 막차 없음
        let times = (0..<10).map { String(format: "%02d:00", $0 + 8) }  // 08:00 ~ 17:00
        let now = makeTime(hhmm: "07:00")
        let vm = await makeViewModel(times: times, currentTime: now)

        // When
        let result = vm.buildUpcomingBuses(limit: 3)

        // Then
        #expect(result.count == 3)
        #expect(result[0].statusKind == .onTime)
        #expect(result[1].statusKind == .onTime)
        #expect(result[2].statusKind == .onTime)
        #expect(result.allSatisfy { $0.statusKind != .lastBus })
    }

    @Test func 오늘버스1개_그버스가_막차() async {
        // Given
        let times = ["10:00"]
        let now = makeTime(hhmm: "09:00")
        let vm = await makeViewModel(times: times, currentTime: now)

        // When
        let result = vm.buildUpcomingBuses(limit: 5)

        // Then
        #expect(result.count == 1)
        #expect(result[0].statusText == "막차")
        #expect(result[0].statusKind == .lastBus)
    }

    @Test func 오늘버스5개_limit5_다섯번째만_막차() async {
        // Given
        let times = ["10:00", "11:00", "12:00", "13:00", "14:00"]
        let now = makeTime(hhmm: "09:00")
        let vm = await makeViewModel(times: times, currentTime: now)

        // When
        let result = vm.buildUpcomingBuses(limit: 5)

        // Then
        #expect(result.count == 5)
        #expect(result[4].statusText == "막차")
        #expect(result[4].statusKind == .lastBus)
        #expect(result[0].statusKind == .onTime)
        #expect(result[1].statusKind == .onTime)
        #expect(result[2].statusKind == .onTime)
        #expect(result[3].statusKind == .onTime)
    }

    @Test func 오늘버스5개_limit3_막차없음() async {
        // Given
        let times = ["10:00", "11:00", "12:00", "13:00", "14:00"]
        let now = makeTime(hhmm: "09:00")
        let vm = await makeViewModel(times: times, currentTime: now)

        // When
        let result = vm.buildUpcomingBuses(limit: 3)

        // Then: 3개 모두 막차 아님 (14:00이 실제 막차지만 limit 안에 없음)
        #expect(result.count == 3)
        #expect(result.allSatisfy { $0.statusKind != .lastBus })
    }

    // MARK: - 내일 첫차/운행 관련

    @Test func 오늘버스0개_내일버스3개_첫번째만_내일첫차() async {
        // Given: 현재 시각 23:00, 오늘 버스 없음 (모두 과거)
        let times = ["06:00", "07:00", "08:00"]
        let now = makeTime(hhmm: "23:00")
        let vm = await makeViewModel(times: times, currentTime: now)

        // When
        let result = vm.buildUpcomingBuses(limit: 3)

        // Then: 전부 내일 버스, 첫번째만 "내일 첫차"
        #expect(result.count == 3)
        #expect(result[0].statusText == "내일 첫차")
        #expect(result[0].statusKind == .nextDay)
        #expect(result[1].statusText == "내일 운행")
        #expect(result[1].statusKind == .nextDay)
        #expect(result[2].statusText == "내일 운행")
        #expect(result[2].statusKind == .nextDay)
    }

    @Test func 오늘버스2개_limit5_내일첫번째만_내일첫차() async {
        // Given: 오늘 버스 2개, 내일 버스 3개로 채움
        let times = ["10:00", "11:00", "12:00", "13:00", "14:00"]
        let now = makeTime(hhmm: "09:30")
        let vm = await makeViewModel(times: times, currentTime: now)

        // When: 오늘 미래 버스 = 10:00, 11:00 (2개) → 나머지 3개는 내일
        let result = vm.buildUpcomingBuses(limit: 5)

        // Then
        #expect(result.count == 5)
        // 오늘 버스
        #expect(result[0].statusKind != .nextDay)
        #expect(result[1].statusKind != .nextDay)
        // 내일 버스
        #expect(result[2].statusText == "내일 첫차")
        #expect(result[2].statusKind == .nextDay)
        #expect(result[3].statusText == "내일 운행")
        #expect(result[3].statusKind == .nextDay)
        #expect(result[4].statusText == "내일 운행")
        #expect(result[4].statusKind == .nextDay)
    }

    @Test func 오늘버스5개_limit5_내일첫차없음() async {
        // Given: 오늘 버스 5개 모두 미래, limit=5 → 내일 버스 없음
        let times = ["10:00", "11:00", "12:00", "13:00", "14:00"]
        let now = makeTime(hhmm: "09:00")
        let vm = await makeViewModel(times: times, currentTime: now)

        // When
        let result = vm.buildUpcomingBuses(limit: 5)

        // Then
        #expect(result.count == 5)
        #expect(result.allSatisfy { $0.statusKind != .nextDay })
    }

    // MARK: - 심야 관련 (nightFareStartTime = "22:10")

    @Test func 야간시작시각이후_버스_심야() async {
        // Given: nightFareStartTime = "22:10", 버스 22:10 (막차 아님)
        let times = ["22:10", "22:30"]
        let now = makeTime(hhmm: "21:00")
        let vm = await makeViewModel(times: times, currentTime: now, nightFareStartTime: "22:10")

        // When
        let result = vm.buildUpcomingBuses(limit: 5)

        // Then: 22:10은 심야지만 막차 아님, 22:30은 막차
        #expect(result[0].statusText == "심야")
        #expect(result[0].statusKind == .nightBus)
    }

    @Test func 야간시작시각직전_버스_심야아님() async {
        // Given
        let times = ["22:09", "22:30"]
        let now = makeTime(hhmm: "21:00")
        let vm = await makeViewModel(times: times, currentTime: now, nightFareStartTime: "22:10")

        // When
        let result = vm.buildUpcomingBuses(limit: 5)

        // Then: 22:09은 심야 아님
        #expect(result[0].statusText == "정시 운행")
        #expect(result[0].statusKind == .onTime)
    }

    @Test func 심야버스가_마지막이면_막차우선() async {
        // Given: 마지막 버스가 심야 시간 → 막차가 심야보다 우선순위 높음
        let times = ["22:10"]
        let now = makeTime(hhmm: "21:00")
        let vm = await makeViewModel(times: times, currentTime: now, nightFareStartTime: "22:10")

        // When
        let result = vm.buildUpcomingBuses(limit: 5)

        // Then
        #expect(result.count == 1)
        #expect(result[0].statusText == "막차")
        #expect(result[0].statusKind == .lastBus)
    }

    @Test func 심야버스여러개_마지막만_막차() async {
        // Given: 심야 버스 3개, 마지막만 막차
        let times = ["22:10", "22:30", "22:50"]
        let now = makeTime(hhmm: "21:00")
        let vm = await makeViewModel(times: times, currentTime: now, nightFareStartTime: "22:10")

        // When
        let result = vm.buildUpcomingBuses(limit: 5)

        // Then
        #expect(result.count == 3)
        #expect(result[0].statusText == "심야")
        #expect(result[0].statusKind == .nightBus)
        #expect(result[1].statusText == "심야")
        #expect(result[1].statusKind == .nightBus)
        #expect(result[2].statusText == "막차")
        #expect(result[2].statusKind == .lastBus)
    }

    // MARK: - 곧 출발 관련

    @Test func 출발5분이내_곧출발() async {
        // Given: 버스 10:05, 현재 10:00 (5분 후) → 5분 이내
        let times = ["10:05", "11:00", "12:00"]
        let now = makeTime(hhmm: "10:00")
        let vm = await makeViewModel(times: times, currentTime: now)

        // When
        let result = vm.buildUpcomingBuses(limit: 5)

        // Then
        #expect(result[0].statusText == "곧 출발")
        #expect(result[0].statusKind == .onTime)
    }

    @Test func 출발6분이후_정시운행() async {
        // Given: 버스 10:06, 현재 10:00 (6분 후)
        let times = ["10:06", "11:00", "12:00"]
        let now = makeTime(hhmm: "10:00")
        let vm = await makeViewModel(times: times, currentTime: now)

        // When
        let result = vm.buildUpcomingBuses(limit: 5)

        // Then
        #expect(result[0].statusText == "정시 운행")
        #expect(result[0].statusKind == .onTime)
    }

    // MARK: - 복합 시나리오

    @Test func 심야2개_첫번째_심야_두번째_막차() async {
        // Given: 오늘 버스 22:10, 22:30 / nightFareStartTime="22:10" / limit=5
        let times = ["22:10", "22:30"]
        let now = makeTime(hhmm: "21:00")
        let vm = await makeViewModel(times: times, currentTime: now, nightFareStartTime: "22:10")

        // When
        let result = vm.buildUpcomingBuses(limit: 5)

        // Then
        #expect(result.count == 2)
        #expect(result[0].statusText == "심야")
        #expect(result[0].statusKind == .nightBus)
        #expect(result[1].statusText == "막차")
        #expect(result[1].statusKind == .lastBus)
    }
}
