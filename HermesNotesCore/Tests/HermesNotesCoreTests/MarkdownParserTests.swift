import Testing
@testable import HermesNotesCore

@Suite struct MarkdownParserTests {
    @Test func parsesHeadingsListsAndParagraphs() {
        let md = """
        # Title

        Some intro text
        continued on a second line.

        ## Section
        - first
        * second
        1. one
        2. two

        > a quiet quote

        ---
        """
        let blocks = MarkdownParser.parse(md)
        #expect(blocks == [
            .heading(level: 1, text: "Title"),
            .paragraph(text: "Some intro text continued on a second line."),
            .heading(level: 2, text: "Section"),
            .bulletItem(text: "first"),
            .bulletItem(text: "second"),
            .orderedItem(number: 1, text: "one"),
            .orderedItem(number: 2, text: "two"),
            .quote(text: "a quiet quote"),
            .horizontalRule,
        ])
    }

    @Test func parsesTaskItems() {
        let blocks = MarkdownParser.parse("- [ ] call the bank\n- [x] send draft")
        #expect(blocks == [
            .taskItem(done: false, text: "call the bank"),
            .taskItem(done: true, text: "send draft"),
        ])
    }

    @Test func parsesCodeFences() {
        let blocks = MarkdownParser.parse("```swift\nlet x = 1\n```")
        #expect(blocks == [.codeBlock(language: "swift", code: "let x = 1")])
    }

    @Test func keepsUnterminatedCodeFence() {
        let blocks = MarkdownParser.parse("```\nabc")
        #expect(blocks == [.codeBlock(language: nil, code: "abc")])
    }

    @Test func plainTextPreviewSkipsHeadingMarkersAndInlineStyles() {
        let preview = MarkdownParser.plainTextPreview("# Big Title\n\nThis is **bold** and `code`.")
        #expect(preview == "Big Title")
        let bodyPreview = MarkdownParser.plainTextPreview("This is **bold** and `code`.")
        #expect(bodyPreview == "This is bold and code.")
    }

    @Test func hashesWithoutSpaceOrDeepLevelStayParagraphs() {
        let blocks = MarkdownParser.parse("####### seven hashes")
        #expect(blocks == [.paragraph(text: "####### seven hashes")])
    }
}
