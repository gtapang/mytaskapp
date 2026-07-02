import Foundation
import HermesNotesCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// A task suggestion extracted from note text; the user confirms before
/// anything becomes a real `TaskItem`.
struct ExtractedTaskSuggestion: Identifiable, Equatable, Sendable {
    let id = UUID()
    var title: String
    var priority: TaskPriority
    /// Natural-language due hint as written in the note ("Friday", "next
    /// week"); the user resolves it to a real date when accepting.
    var dueHint: String?
}

/// On-device intelligence surface. Everything here is fast, local, and
/// optional — the app is fully usable when `isAvailable` is false, and
/// Hermes-side reasoning is a separate layer entirely.
protocol NoteIntelligence: Sendable {
    var isAvailable: Bool { get }
    func summarize(_ noteText: String) async throws -> String
    func suggestTags(for noteText: String, existing: [String]) async throws -> [String]
    func extractTasks(from noteText: String) async throws -> [ExtractedTaskSuggestion]
    func classify(inboxText: String) async throws -> SuggestedItemKind
    func dayStartBriefing(for digest: DayStartDigest) async -> String
}

enum IntelligenceFactory {
    static func make() -> any NoteIntelligence {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            if SystemLanguageModel.default.availability == .available {
                return FoundationModelsIntelligence()
            }
        }
        #endif
        return UnavailableIntelligence()
    }
}

/// Deterministic fallback: no fabricated intelligence, just honest defaults
/// and the rule-based day-start summary from the core.
struct UnavailableIntelligence: NoteIntelligence {
    var isAvailable: Bool { false }

    func summarize(_ noteText: String) async throws -> String {
        MarkdownParser.plainTextPreview(noteText, maxLength: 200)
    }

    func suggestTags(for noteText: String, existing: [String]) async throws -> [String] { [] }

    func extractTasks(from noteText: String) async throws -> [ExtractedTaskSuggestion] {
        // Unchecked markdown task items are extractable without any model.
        MarkdownParser.parse(noteText).compactMap { block in
            if case .taskItem(false, let text) = block {
                return ExtractedTaskSuggestion(title: text, priority: .none, dueHint: nil)
            }
            return nil
        }
    }

    func classify(inboxText: String) async throws -> SuggestedItemKind { .unknown }

    func dayStartBriefing(for digest: DayStartDigest) async -> String {
        DayStart.fallbackSummary(for: digest)
    }
}

#if canImport(FoundationModels)

// MARK: - Typed model outputs

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct NoteSummaryOutput {
    @Guide(description: "A calm 1-2 sentence summary of the note in plain language.")
    var summary: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct TagSuggestionsOutput {
    @Guide(description: "Up to 4 short lowercase topic tags for the note. Prefer reusing existing tags when they fit.")
    var tags: [String]
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct ExtractedTasksOutput {
    @Generable
    struct Item {
        @Guide(description: "Actionable task phrased as an imperative, under 12 words.")
        var title: String
        @Guide(description: "Priority: one of none, low, medium, high.")
        var priority: String
        @Guide(description: "Due hint copied verbatim from the note if one exists, e.g. 'by Friday'. Omit if none.")
        var dueHint: String?
    }
    @Guide(description: "Concrete action items stated or clearly implied by the note. Empty if there are none.")
    var tasks: [Item]
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct InboxClassificationOutput {
    @Guide(description: "What this captured text should become: one of note, task, note_and_task, reference.")
    var kind: String
}

// MARK: - Foundation Models implementation

@available(iOS 26.0, macOS 26.0, *)
struct FoundationModelsIntelligence: NoteIntelligence {
    var isAvailable: Bool { true }

    private func session(_ instructions: String) -> LanguageModelSession {
        LanguageModelSession(instructions: instructions)
    }

    func summarize(_ noteText: String) async throws -> String {
        let session = session("You summarize personal notes. Be brief, factual, and calm. Never invent content.")
        let response = try await session.respond(
            to: "Summarize this note:\n\n\(noteText)",
            generating: NoteSummaryOutput.self
        )
        return response.content.summary
    }

    func suggestTags(for noteText: String, existing: [String]) async throws -> [String] {
        let session = session("You suggest organizational tags for personal notes. Tags are short, lowercase, and reusable.")
        let existingList = existing.isEmpty ? "none yet" : existing.joined(separator: ", ")
        let response = try await session.respond(
            to: "Existing tags: \(existingList)\n\nSuggest tags for this note:\n\n\(noteText)",
            generating: TagSuggestionsOutput.self
        )
        return response.content.tags
            .map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func extractTasks(from noteText: String) async throws -> [ExtractedTaskSuggestion] {
        let session = session("You extract actionable tasks from personal notes. Only extract real actions; never pad the list.")
        let response = try await session.respond(
            to: "Extract tasks from this note:\n\n\(noteText)",
            generating: ExtractedTasksOutput.self
        )
        return response.content.tasks.map {
            ExtractedTaskSuggestion(
                title: $0.title,
                priority: TaskPriority(rawValue: $0.priority) ?? .none,
                dueHint: $0.dueHint
            )
        }
    }

    func classify(inboxText: String) async throws -> SuggestedItemKind {
        let session = session("You classify quick captures for an inbox. A 'task' is actionable; a 'note' is a thought worth keeping; 'reference' is a link or fact.")
        let response = try await session.respond(
            to: "Classify this capture:\n\n\(inboxText)",
            generating: InboxClassificationOutput.self
        )
        return SuggestedItemKind(rawValue: response.content.kind) ?? .unknown
    }

    func dayStartBriefing(for digest: DayStartDigest) async -> String {
        do {
            let session = session("You write a calm two-sentence morning briefing. Factual, warm, no exclamation marks, no advice.")
            let response = try await session.respond(
                to: DayStart.prompt(for: digest),
                generating: NoteSummaryOutput.self
            )
            return response.content.summary
        } catch {
            return DayStart.fallbackSummary(for: digest)
        }
    }
}

#endif
