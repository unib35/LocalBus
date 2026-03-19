import Foundation

// MARK: - Kakao Mobility 응답 모델

private struct KakaoDirectionsResponse: Decodable {
    let routes: [KakaoRoute]
}

private struct KakaoRoute: Decodable {
    let resultCode: Int
    let summary: KakaoSummary

    enum CodingKeys: String, CodingKey {
        case resultCode = "result_code"
        case summary
    }
}

private struct KakaoSummary: Decodable {
    let duration: Int  // 초 단위
}

// MARK: - 캐시 항목

private struct TrafficCache {
    let durationMinutes: Int
    let cachedAt: Date

    var isExpired: Bool {
        Date().timeIntervalSince(cachedAt) > 20 * 60  // 20분
    }
}

// MARK: - TrafficService

/// Kakao Mobility API를 이용해 실시간 교통 소요시간을 조회합니다.
final class TrafficService {

    static let shared = TrafficService()
    private init() {}

    private var cache: [String: TrafficCache] = [:]

    private var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "KakaoRestAPIKey") as? String ?? ""
    }

    // MARK: - Public

    /// 출발지 → 도착지 실시간 소요시간(분)을 반환합니다.
    /// 캐시가 유효하면 API 호출 없이 캐시된 값을 반환합니다.
    func fetchDuration(
        origin: Coordinate,
        destination: Coordinate
    ) async -> Int? {
        let cacheKey = "\(origin.latitude),\(origin.longitude)→\(destination.latitude),\(destination.longitude)"

        if let cached = cache[cacheKey], !cached.isExpired {
            return cached.durationMinutes
        }

        guard let minutes = await requestDuration(origin: origin, destination: destination) else {
            return cache[cacheKey]?.durationMinutes  // 실패 시 만료된 캐시라도 반환
        }

        cache[cacheKey] = TrafficCache(durationMinutes: minutes, cachedAt: Date())
        return minutes
    }

    func invalidateCache() {
        cache.removeAll()
    }

    // MARK: - Private

    private func requestDuration(
        origin: Coordinate,
        destination: Coordinate
    ) async -> Int? {
        guard !apiKey.isEmpty else { return nil }

        var components = URLComponents(string: "https://apis-navi.kakaomobility.com/v1/directions")
        components?.queryItems = [
            URLQueryItem(name: "origin", value: "\(origin.longitude),\(origin.latitude)"),
            URLQueryItem(name: "destination", value: "\(destination.longitude),\(destination.latitude)"),
            URLQueryItem(name: "priority", value: "RECOMMEND")
        ]

        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("KakaoAK \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            let result = try JSONDecoder().decode(KakaoDirectionsResponse.self, from: data)

            guard let route = result.routes.first, route.resultCode == 0 else { return nil }

            return route.summary.duration / 60  // 초 → 분
        } catch {
            return nil
        }
    }
}

// MARK: - Coordinate

struct Coordinate {
    let latitude: Double
    let longitude: Double
}
