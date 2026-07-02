import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import HermesNotesCore

/// In-memory transport that scripts responses and records requests.
actor MockTransport: HermesTransport {
    struct Call: Sendable {
        var path: String
        var method: String
        var body: Data?
    }

    private(set) var calls: [Call] = []
    private var failuresRemaining: Int
    private let responseBody: Data

    init(failuresRemaining: Int = 0, responseBody: Data = Data("[]".utf8)) {
        self.failuresRemaining = failuresRemaining
        self.responseBody = responseBody
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        calls.append(Call(
            path: request.url?.path ?? "",
            method: request.httpMethod ?? "GET",
            body: request.httpBody
        ))
        let status: Int
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            status = 503
        } else {
            status = 200
        }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil
        )!
        return (responseBody, response)
    }
}

private func makeClient(transport: MockTransport) -> HermesClient {
    HermesClient(
        configuration: HermesConfiguration(
            baseURL: URL(string: "https://hermes.example.com")!,
            bearerToken: "test-token"
        ),
        transport: transport
    )
}

@Suite struct HermesClientTests {
    @Test func decodesImportantContext() async throws {
        let json = """
        [{"id":"e1","kind":"email","title":"Grant deadline","summary":"NSF due Friday",
          "importance":0.92,"ruleHit":"vip-sender","sourceMetadata":{"messageId":"m-1"},
          "occursAt":"2026-07-02T09:00:00Z"}]
        """
        let transport = MockTransport(responseBody: Data(json.utf8))
        let items = try await makeClient(transport: transport).importantContext(since: nil)
        #expect(items.count == 1)
        #expect(items[0].kind == .email)
        #expect(items[0].importance == 0.92)
        #expect(items[0].ruleHit == "vip-sender")
    }

    @Test func surfacesHTTPFailuresAsErrors() async {
        let transport = MockTransport(failuresRemaining: 1)
        await #expect(throws: HermesError.httpStatus(503)) {
            try await makeClient(transport: transport).pushToTelegram(TelegramPushPayload(text: "hi"))
        }
    }
}

@Suite struct HermesOutboxTests {
    private func makeOutbox() -> HermesOutbox {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hermesnotes-outbox-\(UUID().uuidString)/outbox.json")
        return HermesOutbox(storageURL: url)
    }

    @Test func drainsInOrderAndEmptiesQueue() async throws {
        let outbox = makeOutbox()
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        try await outbox.enqueue(path: "/v1/telegram/push", payload: TelegramPushPayload(text: "one"), now: now)
        try await outbox.enqueue(path: "/v1/wiki/route", payload: TelegramPushPayload(text: "two"), now: now)

        let transport = MockTransport()
        let delivered = await outbox.drain(using: makeClient(transport: transport))
        #expect(delivered == 2)
        #expect(await outbox.pendingCount == 0)
        let calls = await transport.calls
        #expect(calls.map(\.path) == ["/v1/telegram/push", "/v1/wiki/route"])
    }

    @Test func stopsAtFirstFailureAndRetainsAction() async throws {
        let outbox = makeOutbox()
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        try await outbox.enqueue(path: "/v1/telegram/push", payload: TelegramPushPayload(text: "one"), now: now)
        try await outbox.enqueue(path: "/v1/telegram/push", payload: TelegramPushPayload(text: "two"), now: now)

        let failing = MockTransport(failuresRemaining: 1)
        let delivered = await outbox.drain(using: makeClient(transport: failing))
        #expect(delivered == 0)
        #expect(await outbox.pendingCount == 2)
        #expect(await outbox.pending.first?.attempts == 1)

        // Next drain succeeds and flushes both, in order.
        let second = await outbox.drain(using: makeClient(transport: failing))
        #expect(second == 2)
        #expect(await outbox.pendingCount == 0)
    }

    @Test func persistsAcrossReloads() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hermesnotes-outbox-\(UUID().uuidString)/outbox.json")
        let now = Date(timeIntervalSince1970: 1_750_000_000)

        let first = HermesOutbox(storageURL: url)
        try await first.enqueue(path: "/v1/wiki/route", payload: TelegramPushPayload(text: "keep me"), now: now)
        #expect(await first.pendingCount == 1)

        let reloaded = HermesOutbox(storageURL: url)
        #expect(await reloaded.pendingCount == 1)
        #expect(await reloaded.pending.first?.path == "/v1/wiki/route")
    }

    @Test func dropsPoisonedActionAfterMaxAttempts() async throws {
        let outbox = makeOutbox()
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        try await outbox.enqueue(path: "/v1/telegram/push", payload: TelegramPushPayload(text: "poison"), now: now)

        for _ in 0..<HermesOutbox.maxAttempts {
            let failing = MockTransport(failuresRemaining: 1)
            await outbox.drain(using: makeClient(transport: failing))
        }
        #expect(await outbox.pendingCount == 0)
    }
}
