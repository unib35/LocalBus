import Foundation

/// 네트워크 에러 타입
enum NetworkError: Error, Equatable {
    case invalidURL
    case requestFailed
    case decodingFailed
}

/// 네트워크 요청을 처리하는 서비스
class NetworkService {

    init() {}

    /// 지정된 URL에서 JSON 데이터를 fetch하고 디코딩
    /// - Parameters:
    ///   - url: 데이터를 가져올 URL
    ///   - session: URLSession (테스트용 mock session 주입 가능)
    /// - Returns: 디코딩된 데이터
    /// - Throws: NetworkError
    func fetch<T: Decodable>(
        from url: URL,
        session: URLSession = .shared
    ) async throws -> T {
        // 네트워크 요청 수행
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw NetworkError.requestFailed
        }

        // HTTP 응답 검증
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.requestFailed
        }

        // JSON 디코딩
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed
        }
    }
}
