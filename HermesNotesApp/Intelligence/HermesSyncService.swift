import Foundation
import SwiftData
import HermesNotesCore

/// Owns the Hermes connection: configuration, opportunistic sync of important
/// context and Telegram captures into SwiftData, and the durable outbox for
/// writes. Never blocks the UI and never breaks offline use — a failed sync
/// just means Hermes context is stale.
@MainActor
@Observable
final class HermesSyncService {
    private(set) var lastSyncAt: Date?
    private(set) var lastError: String?
    private(set) var isSyncing = false
    private(set) var pendingOutboxCount = 0

    private let outbox: HermesOutbox

    init() {
        let outboxURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HermesNotes/outbox.json")
        outbox = HermesOutbox(storageURL: outboxURL)
    }

    // MARK: Configuration

    var isConfigured: Bool { client != nil }

    var baseURLString: String {
        get { UserDefaults.standard.string(forKey: "hermesBaseURL") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "hermesBaseURL") }
    }

    var bearerToken: String {
        get { UserDefaults.standard.string(forKey: "hermesToken") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "hermesToken") }
    }

    private var client: HermesClient? {
        guard let url = URL(string: baseURLString), !bearerToken.isEmpty else { return nil }
        return HermesClient(configuration: HermesConfiguration(baseURL: url, bearerToken: bearerToken))
    }

    // MARK: Sync (reads + outbox drain)

    func syncNow(context: ModelContext) async {
        guard let client, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let since = lastSyncAt
            let contextItems = try await client.importantContext(since: since)
            upsert(contextItems, into: context)

            let captures = try await client.telegramCaptures(since: since)
            ingest(captures, into: context)

            await outbox.drain(using: client)
            pendingOutboxCount = await outbox.pendingCount

            lastSyncAt = .now
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func upsert(_ payloads: [HermesContextPayload], into context: ModelContext) {
        for payload in payloads {
            let sourceID = payload.id
            let existing = try? context.fetch(
                FetchDescriptor<HermesContextItem>(predicate: #Predicate { $0.sourceID == sourceID })
            ).first
            if let existing {
                existing.update(from: payload)
            } else {
                context.insert(HermesContextItem(payload: payload))
            }
        }
    }

    private func ingest(_ captures: [TelegramCapturePayload], into context: ModelContext) {
        for capture in captures {
            let sourceID = capture.id
            let duplicate = (try? context.fetch(
                FetchDescriptor<InboxItem>(predicate: #Predicate { $0.sourceID == sourceID })
            ).first) != nil
            guard !duplicate else { continue }
            context.insert(InboxItem(
                source: .telegram,
                sourceID: capture.id,
                rawContent: capture.text,
                createdAt: capture.capturedAt
            ))
        }
    }

    // MARK: Writes (through the outbox)

    /// Routes a note into the Hermes markdown wiki workflow.
    func routeToWiki(_ snapshot: NoteSnapshot) async {
        let payload = WikiRoutePayload(
            noteID: snapshot.id,
            title: snapshot.title,
            document: NoteFileCodec.encode(snapshot),
            tags: snapshot.tags
        )
        await enqueue(path: "/v1/wiki/route", payload: payload)
    }

    /// Pushes a structured response back out through Hermes Telegram.
    func pushToTelegram(text: String, replyToCaptureID: String? = nil) async {
        let payload = TelegramPushPayload(text: text, replyToCaptureID: replyToCaptureID)
        await enqueue(path: "/v1/telegram/push", payload: payload)
    }

    private func enqueue<T: Encodable & Sendable>(path: String, payload: T) async {
        try? await outbox.enqueue(path: path, payload: payload, now: .now)
        pendingOutboxCount = await outbox.pendingCount
        // Opportunistic immediate drain; failures simply wait for next sync.
        if let client {
            await outbox.drain(using: client)
            pendingOutboxCount = await outbox.pendingCount
        }
    }
}
