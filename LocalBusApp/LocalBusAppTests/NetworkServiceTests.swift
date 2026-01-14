import Testing
import Foundation
@testable import LocalBusApp

@Suite("NetworkService 테스트", .serialized)
struct NetworkServiceTests {

    // MARK: - 테스트용 Mock 데이터

    struct MockData: Codable, Equatable {
        let message: String
        let value: Int
    }

    // MARK: - 성공 케이스 테스트

    @Test("유효한 JSON 데이터를 성공적으로 디코딩한다")
    func 유효한JSON데이터를_성공적으로_디코딩한다() async throws {
        // Given
        let sut = NetworkService()
        let mockJSON = """
        {
            "message": "hello",
            "value": 42
        }
        """

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, mockJSON.data(using: .utf8)!)
        }

        // When
        let url = URL(string: "https://example.com/data.json")!
        let result: MockData = try await sut.fetch(from: url, session: session)

        // Then
        #expect(result.message == "hello")
        #expect(result.value == 42)
    }

    @Test("TimetableData를 성공적으로 fetch한다")
    func TimetableData를_성공적으로_fetch한다() async throws {
        // Given
        let sut = NetworkService()
        let mockJSON = """
        {
            "meta": {
                "version": 1,
                "updated_at": "2026-01-10",
                "notice_message": "테스트 공지",
                "contact_email": "test@example.com"
            },
            "holidays": ["2026-01-01", "2026-12-25"],
            "timetable": {
                "weekday": ["06:00", "07:00"],
                "weekend": ["08:00", "09:00"]
            }
        }
        """

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, mockJSON.data(using: .utf8)!)
        }

        // When
        let url = URL(string: "https://raw.githubusercontent.com/example/timetable.json")!
        let result: TimetableData = try await sut.fetch(from: url, session: session)

        // Then
        #expect(result.meta.version == 1)
        #expect(result.holidays.count == 2)
        #expect(result.timetable.weekday.count == 2)
    }

    // MARK: - 실패 케이스 테스트

    @Test("네트워크 요청 실패 시 requestFailed 에러를 던진다")
    func 네트워크요청실패시_requestFailed에러를던진다() async throws {
        // Given
        let sut = NetworkService()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        // When/Then
        let url = URL(string: "https://example.com/notfound.json")!
        await #expect(throws: NetworkError.requestFailed) {
            let _: MockData = try await sut.fetch(from: url, session: session)
        }
    }

    @Test("잘못된 JSON 형식일 때 decodingFailed 에러를 던진다")
    func 잘못된JSON형식일때_decodingFailed에러를던진다() async throws {
        // Given
        let sut = NetworkService()
        let invalidJSON = """
        {
            "invalid": "data"
        }
        """

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, invalidJSON.data(using: .utf8)!)
        }

        // When/Then
        let url = URL(string: "https://example.com/invalid.json")!
        await #expect(throws: NetworkError.decodingFailed) {
            let _: MockData = try await sut.fetch(from: url, session: session)
        }
    }

    @Test("서버 에러 응답 시 requestFailed 에러를 던진다")
    func 서버에러응답시_requestFailed에러를던진다() async throws {
        // Given
        let sut = NetworkService()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        // When/Then
        let url = URL(string: "https://example.com/error.json")!
        await #expect(throws: NetworkError.requestFailed) {
            let _: MockData = try await sut.fetch(from: url, session: session)
        }
    }
}

// MARK: - MockURLProtocol for Testing

class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("Handler is unavailable.")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        // Nothing to do here
    }
}
