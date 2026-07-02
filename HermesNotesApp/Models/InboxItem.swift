import Foundation
import SwiftData
import HermesNotesCore

/// A captured thought awaiting processing. Capture never demands metadata;
/// classification is an on-device suggestion attached after the fact.
@Model
final class InboxItem {
    @Attribute(.unique) var id: UUID
    var sourceRaw: String
    /// Stable identifier from the source system (e.g. Telegram capture id)
    /// used to deduplicate repeated syncs.
    var sourceID: String?
    var rawContent: String
    var createdAt: Date
    var isProcessed: Bool
    var resultingNoteID: UUID?
    var resultingTaskID: UUID?
    var suggestedKindRaw: String

    init(
        id: UUID = UUID(),
        source: InboxSource,
        sourceID: String? = nil,
        rawContent: String,
        createdAt: Date = .now,
        isProcessed: Bool = false,
        suggestedKind: SuggestedItemKind = .unknown
    ) {
        self.id = id
        self.sourceRaw = source.rawValue
        self.sourceID = sourceID
        self.rawContent = rawContent
        self.createdAt = createdAt
        self.isProcessed = isProcessed
        self.resultingNoteID = nil
        self.resultingTaskID = nil
        self.suggestedKindRaw = suggestedKind.rawValue
    }

    var source: InboxSource {
        get { InboxSource(rawValue: sourceRaw) ?? .localCapture }
        set { sourceRaw = newValue.rawValue }
    }

    var suggestedKind: SuggestedItemKind {
        get { SuggestedItemKind(rawValue: suggestedKindRaw) ?? .unknown }
        set { suggestedKindRaw = newValue.rawValue }
    }
}

/// Important context surfaced by Hermes (email, calendar, summary), shown on
/// Today and Calendar. Rows are upserted by `sourceID` on each sync.
@Model
final class HermesContextItem {
    @Attribute(.unique) var sourceID: String
    var kindRaw: String
    var title: String
    var summary: String
    var importance: Double
    var ruleHit: String?
    /// JSON-encoded source metadata kept verbatim for pushback and linking.
    var sourceMetadataJSON: String
    var occursAt: Date?
    var fetchedAt: Date
    var linkedNoteID: UUID?
    var linkedTaskID: UUID?
    var isDismissed: Bool

    init(payload: HermesContextPayload, fetchedAt: Date = .now) {
        self.sourceID = payload.id
        self.kindRaw = payload.kind.rawValue
        self.title = payload.title
        self.summary = payload.summary
        self.importance = payload.importance
        self.ruleHit = payload.ruleHit
        if let data = try? JSONEncoder().encode(payload.sourceMetadata),
           let json = String(data: data, encoding: .utf8) {
            self.sourceMetadataJSON = json
        } else {
            self.sourceMetadataJSON = "{}"
        }
        self.occursAt = payload.occursAt
        self.fetchedAt = fetchedAt
        self.linkedNoteID = nil
        self.linkedTaskID = nil
        self.isDismissed = false
    }

    var kind: HermesContextKind {
        get { HermesContextKind(rawValue: kindRaw) ?? .summary }
        set { kindRaw = newValue.rawValue }
    }

    func update(from payload: HermesContextPayload, fetchedAt: Date = .now) {
        title = payload.title
        summary = payload.summary
        importance = payload.importance
        ruleHit = payload.ruleHit
        occursAt = payload.occursAt
        self.fetchedAt = fetchedAt
    }
}
