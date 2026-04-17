import XCTest
@testable import VoiceReaderApp

final class ParserFactoryTests: XCTestCase {
    func testParserSelectionByFormat() {
        let factory = ParserFactory()
        XCTAssertEqual(String(describing: type(of: factory.parser(for: .pdf))), "PDFTextParser")
        XCTAssertEqual(String(describing: type(of: factory.parser(for: .epub))), "EpubTextParser")
        XCTAssertEqual(String(describing: type(of: factory.parser(for: .markdown))), "MarkdownTextParser")
        XCTAssertEqual(String(describing: type(of: factory.parser(for: .txt))), "TXTTextParser")
    }
}
