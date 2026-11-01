import Foundation
import XCTest
@testable import VoiceReaderApp

final class MarkdownTextParserTests: XCTestCase {
    func testPreservesHeadingAndParagraphBoundaries() throws {
        XCTAssertEqual(try parse("# Heading\n\nFirst paragraph.\n\nSecond paragraph."), [
            "Heading", "First paragraph.", "Second paragraph."
        ])
    }

    func testKeepsInlineFormattingInOneParagraph() throws {
        XCTAssertEqual(try parse("A **bold** word, *emphasis* and [link](https://example.com)."), [
            "A bold word, emphasis and link."
        ])
    }

    func testKeepsSoftWrappedLinesTogether() throws {
        XCTAssertEqual(try parse("One paragraph\ncontinues here.\n\nA new paragraph."), [
            "One paragraph continues here.", "A new paragraph."
        ])
    }

    func testPreservesSeparateListItemsAndBlockQuotes() throws {
        XCTAssertEqual(try parse("- First item\n- Second **item**\n\n> Quoted paragraph."), [
            "First item", "Second item", "Quoted paragraph."
        ])
    }

    func testRejectsEmptyDocument() throws {
        XCTAssertThrowsError(try parse(" \n\n ")) { error in
            guard case TextParsingError.noExtractedText = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    private func parse(_ markdown: String) throws -> [String] {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("markdown-test-\(UUID()).md")
        defer { try? FileManager.default.removeItem(at: file) }
        try markdown.write(to: file, atomically: true, encoding: .utf8)
        return try MarkdownTextParser().parse(from: file)
    }
}
