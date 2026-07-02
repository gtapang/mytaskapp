import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Transport abstraction so the client is testable and portable (Linux CI
/// uses it too). The default implementation wraps URLSession.
public protocol HermesTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct HermesConfiguration: Equatable, Sendable {
    public var baseURL: URL
    public var bearerToken: String

    public init(baseURL: URL, bearerToken: String) {
        self.baseURL = baseURL
        self.bearerToken = bearerToken
    }
}

public enum HermesError: Error, Equatable, Sendable {
    case notConfigured
    case httpStatus(Int)
    case invalidResponse
}

/// Thin async client for the Hermes v1 API. Every method is a single
/// request/response; queuing, retry, and offline durability live in
/// `HermesOutbox`, not here.
public struct HermesClient: Sendable {
    public let configuration: HermesConfiguration
    private let transport: any HermesTransport

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public init(configuration: HermesConfiguration, transport: any HermesTransport = URLSessionTransport()) {
        self.configuration = configuration
        self.transport = transport
    }

    // MARK: Reads

    /// Important email/calendar/summary context since a given time.
    public func importantContext(since: Date?) async throws -> [HermesContextPayload] {
        try await get("/v1/context/important", since: since)
    }

    /// Telegram captures awaiting inbox delivery.
    public func telegramCaptures(since: Date?) async throws -> [TelegramCapturePayload] {
        try await get("/v1/capture/telegram", since: since)
    }

    // MARK: Writes (normally called via HermesOutbox)

    public func routeToWiki(_ payload: WikiRoutePayload) async throws {
        try await post("/v1/wiki/route", body: payload)
    }

    public func pushToTelegram(_ payload: TelegramPushPayload) async throws {
        try await post("/v1/telegram/push", body: payload)
    }

    /// Generic raw POST used by the outbox to replay persisted actions.
    public func post(path: String, body: Data) async throws {
        var request = makeRequest(path: path, query: [])
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (_, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw HermesError.httpStatus(response.statusCode)
        }
    }

    // MARK: Internals

    private func get<T: Decodable>(_ path: String, since: Date?) async throws -> [T] where T: Sendable {
        var query: [URLQueryItem] = []
        if let since {
            query.append(URLQueryItem(name: "since", value: ISO8601DateFormatter().string(from: since)))
        }
        let request = makeRequest(path: path, query: query)
        let (data, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw HermesError.httpStatus(response.statusCode)
        }
        return try Self.decoder.decode([T].self, from: data)
    }

    private func post<T: Encodable>(_ path: String, body: T) async throws {
        try await post(path: path, body: try Self.encoder.encode(body))
    }

    private func makeRequest(path: String, query: [URLQueryItem]) -> URLRequest {
        var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(configuration.bearerToken)", forHTTPHeaderField: "Authorization")
        return request
    }
}

/// URLSession-backed transport. Uses the completion-handler API under a
/// continuation so it works identically on Apple platforms and Linux
/// (swift-corelibs-foundation).
public struct URLSessionTransport: HermesTransport {
    public init() {}

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let http = response as? HTTPURLResponse {
                    continuation.resume(returning: (data ?? Data(), http))
                } else {
                    continuation.resume(throwing: HermesError.invalidResponse)
                }
            }.resume()
        }
    }
}
