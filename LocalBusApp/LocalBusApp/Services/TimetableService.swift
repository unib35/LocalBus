import Foundation

/// 시간표 데이터 관리 서비스
struct TimetableService {

    // MARK: - Constants

    private let cacheKey: String
    private let bundleFileName: String

    // MARK: - Initialization

    init(bundleFileName: String = "timetable", cacheKey: String = "cached_timetable_data") {
        self.bundleFileName = bundleFileName
        self.cacheKey = cacheKey
    }

    // MARK: - Local Data Loading

    /// 번들 내 기본 JSON 파일 로드
    /// - Returns: TimetableData 또는 nil (파일 없음/파싱 실패 시)
    func loadLocalData() -> TimetableData? {
        guard let url = Bundle.main.url(forResource: bundleFileName, withExtension: "json") else {
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(TimetableData.self, from: data)
    }

    // MARK: - Cache Management

    /// UserDefaults 캐시에서 데이터 로드
    /// - Returns: TimetableData 또는 nil (캐시 없음/파싱 실패 시)
    func loadCachedData() -> TimetableData? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return nil
        }

        return try? JSONDecoder().decode(TimetableData.self, from: data)
    }

    /// UserDefaults 캐시에 데이터 저장
    /// - Parameter data: 저장할 TimetableData
    func saveToCache(_ data: TimetableData) {
        guard let encoded = try? JSONEncoder().encode(data) else {
            return
        }

        UserDefaults.standard.set(encoded, forKey: cacheKey)
    }

    // MARK: - Timetable Selection

    /// 특정 날짜에 맞는 시간표 반환 (평일/주말)
    /// - Parameters:
    ///   - date: 기준 날짜
    ///   - data: 시간표 데이터
    /// - Returns: 해당 날짜의 버스 시간 배열
    func getCurrentTimetable(for date: Date, data: TimetableData) -> [String] {
        if DateService.shouldUseWeekdaySchedule(date, holidays: data.holidays) {
            return data.timetable.weekday
        } else {
            return data.timetable.weekend
        }
    }
}
