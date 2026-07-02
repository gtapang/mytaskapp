import Foundation

/// A Hermes write that must eventually happen. Persisted as JSON on disk so
/// actions queued offline survive relaunch — this is what keeps Hermes
/// integration compatible with the local-first promise.
public struct OutboxAction: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    /// API path the action replays against, e.g. "/v1/wiki/route".
    public var path: String
    public var body: Data
    public var createdAt: Date
    public var attempts: Int

    public init(id: UUID = UUID(), path: String, body: Data, createdAt: Date, attempts: Int = 0) {
        self.id = id
        self.path = path
        self.body = body
        self.createdAt = createdAt
        self.attempts = attempts
    }
}

/// Durable FIFO queue for Hermes writes. Enqueue is always local and instant;
/// `drain` is called opportunistically (app foreground, after a successful
/// sync, after enqueueing while online) and stops at the first failure so
/// ordering is preserved and offline periods cost nothing.
public actor HermesOutbox {
    public static let maxAttempts = 8

    private let storageURL: URL
    private var actions: [OutboxAction]

    public init(storageURL: URL) {
        self.storageURL = storageURL
        self.actions = Self.load(from: storageURL)
    }

    public var pendingCount: Int { actions.count }
    public var pending: [OutboxAction] { actions }

    public func enqueue(path: String, body: Data, now: Date) {
        actions.append(OutboxAction(path: path, body: body, createdAt: now))
        persist()
    }

    public func enqueue<T: Encodable>(path: String, payload: T, now: Date) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        enqueue(path: path, body: try encoder.encode(payload), now: now)
    }

    /// Replays pending actions in order. Returns the number delivered.
    /// Stops at the first failure; the failed action's attempt count is
    /// incremented and it is dropped once it exceeds `maxAttempts` (a
    /// poisoned action must not block the queue forever).
    @discardableResult
    public func drain(using client: HermesClient) async -> Int {
        var delivered = 0
        while let next = actions.first {
            do {
                try await client.post(path: next.path, body: next.body)
                actions.removeFirst()
                delivered += 1
            } catch {
                actions[0].attempts += 1
                if actions[0].attempts >= Self.maxAttempts {
                    actions.removeFirst()
                }
                break
            }
        }
        persist()
        return delivered
    }

    // MARK: Persistence

    private func persist() {
        do {
            let data = try JSONEncoder().encode(actions)
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Persistence failure must never take down capture flows; the
            // queue stays correct in memory for this run.
        }
    }

    private static func load(from url: URL) -> [OutboxAction] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([OutboxAction].self, from: data)) ?? []
    }
}
