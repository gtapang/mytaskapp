import Foundation

/// Wire types for the Hermes orchestration API. Hermes remains the
/// higher-order backend: email/calendar importance, Telegram capture and
/// pushback, wiki routing, cross-system workflows. The app never blocks on
/// these calls.

/// An importance-scored context item surfaced by Hermes (email, calendar, or
/// synthesized summary), shown on Today and Calendar.
public struct HermesContextPayload: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: HermesContextKind
    public var title: String
    public var summary: String
    /// 0...1 inferred importance; Hermes combines rules and inference.
    public var importance: Double
    /// Name of the deterministic rule that fired, if any (e.g. "vip-sender").
    public var ruleHit: String?
    /// Opaque source metadata (message id, event id, deep link) kept verbatim
    /// for pushback and linking.
    public var sourceMetadata: [String: String]
    public var occursAt: Date?

    public init(
        id: String,
        kind: HermesContextKind,
        title: String,
        summary: String,
        importance: Double,
        ruleHit: String? = nil,
        sourceMetadata: [String: String] = [:],
        occursAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.summary = summary
        self.importance = importance
        self.ruleHit = ruleHit
        self.sourceMetadata = sourceMetadata
        self.occursAt = occursAt
    }
}

/// A capture that arrived through the Hermes Telegram bot, destined for Inbox.
public struct TelegramCapturePayload: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var text: String
    public var capturedAt: Date

    public init(id: String, text: String, capturedAt: Date) {
        self.id = id
        self.text = text
        self.capturedAt = capturedAt
    }
}

/// Routes a note into the Hermes markdown wiki workflow.
public struct WikiRoutePayload: Codable, Equatable, Sendable {
    public var noteID: UUID
    public var title: String
    /// Full mirror-format document (front matter + body) so Hermes receives
    /// the same representation that lives on disk.
    public var document: String
    public var tags: [String]

    public init(noteID: UUID, title: String, document: String, tags: [String]) {
        self.noteID = noteID
        self.title = title
        self.document = document
        self.tags = tags
    }
}

/// Pushes a structured response back out through Hermes Telegram.
public struct TelegramPushPayload: Codable, Equatable, Sendable {
    public var text: String
    /// When set, Hermes threads the message as a reply to an earlier capture.
    public var replyToCaptureID: String?

    public init(text: String, replyToCaptureID: String? = nil) {
        self.text = text
        self.replyToCaptureID = replyToCaptureID
    }
}
