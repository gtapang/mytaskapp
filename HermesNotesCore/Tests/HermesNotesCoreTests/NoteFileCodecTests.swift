import Foundation
import Testing
@testable import HermesNotesCore

@Suite struct FrontMatterTests {
    @Test func roundTripsAllValueKinds() {
        let fields: [(String, FrontMatter.Value)] = [
            ("title", .string("Plan: v1, launch [draft]")),
            ("pinned", .bool(true)),
            ("archived", .bool(false)),
            ("tags", .array(["deep-work", "ph d", "a,b"])),
            ("empty", .array([])),
        ]
        let doc = FrontMatter.serialize(fields) + "\n\nBody text."
        let (parsed, body) = FrontMatter.parse(document: doc)
        #expect(body == "Body text.")
        #expect(parsed?["title"] == .string("Plan: v1, launch [draft]"))
        #expect(parsed?["pinned"] == .bool(true))
        #expect(parsed?["archived"] == .bool(false))
        #expect(parsed?["tags"] == .array(["deep-work", "ph d", "a,b"]))
        #expect(parsed?["empty"] == .array([]))
    }

    @Test func documentWithoutFrontMatterPassesThrough() {
        let (fields, body) = FrontMatter.parse(document: "just a note")
        #expect(fields == nil)
        #expect(body == "just a note")
    }
}

@Suite struct NoteFileCodecTests {
    @Test func roundTripsFullNote() throws {
        let created = Date(timeIntervalSince1970: 1_750_000_000)
        let note = NoteSnapshot(
            title: "Meeting notes: Q3 planning",
            markdown: "# Agenda\n\n- budget\n- hiring\n\n- [ ] send recap",
            createdAt: created,
            updatedAt: created.addingTimeInterval(3600),
            tags: ["work", "planning"],
            folder: "Work",
            notebook: "2026",
            project: "Roadmap",
            isPinned: true,
            isArchived: false,
            linkedTaskIDs: [UUID(), UUID()],
            reminderAt: created.addingTimeInterval(86_400)
        )
        let encoded = NoteFileCodec.encode(note)
        let decoded = try #require(NoteFileCodec.decode(encoded))
        #expect(decoded == note)
    }

    @Test func roundTripsMinimalNote() throws {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let note = NoteSnapshot(title: "Untitled", markdown: "", createdAt: now, updatedAt: now)
        let decoded = try #require(NoteFileCodec.decode(NoteFileCodec.encode(note)))
        #expect(decoded == note)
    }

    @Test func rejectsDocumentWithoutIdentity() {
        #expect(NoteFileCodec.decode("---\ntitle: x\n---\n\nbody") == nil)
        #expect(NoteFileCodec.decode("plain markdown, no front matter") == nil)
    }
}
