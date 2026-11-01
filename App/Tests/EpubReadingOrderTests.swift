import XCTest
@testable import VoiceReaderApp

final class EpubReadingOrderTests: XCTestCase {
    func testChapterMarkupPreservesParagraphsAndEntitiesWithoutScripts() {
        let text = URLArticleExtractor.stripHTML(from: "<p>One &amp; two</p><script>hidden()</script><p>Gr&uuml;&szlig;e</p>")
        XCTAssertEqual(text, "One & two\nGrüße")
    }

    private let container = Data("""
    <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles>
    <rootfile full-path="OPS/package.opf" media-type="application/oebps-package+xml"/>
    </rootfiles></container>
    """.utf8)

    func testSpineOrderWinsOverFilenamesAndSkipsAuxiliaryPages() throws {
        let package = """
        <package xmlns="http://www.idpf.org/2007/opf"><manifest>
        <item id="last" href="a.xhtml" media-type="application/xhtml+xml"/>
        <item id="first" href="../Text/z%20chapter.xhtml#start" media-type="application/xhtml+xml"/>
        <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml"/>
        </manifest><spine><itemref idref="first"/><itemref idref="nav" linear="no"/>
        <itemref idref="last"/></spine></package>
        """
        let paths = try EpubReadingOrder.chapterPaths(container: container) { path in
            XCTAssertEqual(path, "OPS/package.opf")
            return Data(package.utf8)
        }
        XCTAssertEqual(paths, ["Text/z chapter.xhtml", "OPS/a.xhtml"])
    }

    func testSVGSpineCoverIsSkippedWhileHTMLChaptersRemainInSpineOrder() throws {
        let package = """
        <package><manifest>
        <item id="cover" href="cover.svg" media-type="image/svg+xml"/>
        <item id="first" href="z.xhtml" media-type="application/xhtml+xml"/>
        <item id="last" href="a.html" media-type="text/html"/>
        </manifest><spine><itemref idref="cover"/><itemref idref="first"/>
        <itemref idref="last"/></spine></package>
        """
        let files = ["OPS/package.opf": package, "OPS/z.xhtml": "<p>First</p>",
                     "OPS/a.html": "<p>Last</p>"]
        let paragraphs = try EpubReadingOrder.paragraphs(
            container: container, fallbackPaths: ["OPS/a.html", "OPS/z.xhtml"]
        ) { path in
            XCTAssertNotEqual(path, "OPS/cover.svg", "SVG entries must not be read as HTML")
            return try self.read(path, from: files)
        }
        XCTAssertEqual(paragraphs, ["First", "Last"])
    }

    func testMissingChapterDoesNotDiscardReadableChaptersOrTheirSpineOrder() throws {
        let package = """
        <package><manifest>
        <item id="first" href="z.xhtml" media-type="application/xhtml+xml"/>
        <item id="missing" href="missing.xhtml" media-type="application/xhtml+xml"/>
        <item id="last" href="a.xhtml" media-type="application/xhtml+xml"/>
        </manifest><spine><itemref idref="first"/><itemref idref="missing"/>
        <itemref idref="last"/></spine></package>
        """
        let files = ["OPS/package.opf": package, "OPS/z.xhtml": "<p>First</p>",
                     "OPS/a.xhtml": "<p>Last</p>"]
        let paragraphs = try EpubReadingOrder.paragraphs(
            container: container, fallbackPaths: ["OPS/a.xhtml", "OPS/z.xhtml"]
        ) { try self.read($0, from: files) }
        XCTAssertEqual(paragraphs, ["First", "Last"])
    }

    func testUnparsablePackageFallsBackToFilenameOrder() throws {
        let files = ["OPS/package.opf": "<package><manifest>",
                     "OPS/a.xhtml": "<p>First</p>", "OPS/z.htm": "<p>Last</p>"]
        let paragraphs = try EpubReadingOrder.paragraphs(
            container: container, fallbackPaths: ["OPS/z.htm", "OPS/a.xhtml"]
        ) { try self.read($0, from: files) }
        XCTAssertEqual(paragraphs, ["First", "Last"])
    }

    func testUnreadableSpineFallsBackToFilenameOrder() throws {
        // The manifest says Text/Chapter1.xhtml but the archive stores text/chapter1.xhtml.
        let package = """
        <package xmlns="http://www.idpf.org/2007/opf"><manifest>
        <item id="c1" href="Text/Chapter1.xhtml" media-type="application/xhtml+xml"/>
        </manifest><spine><itemref idref="c1"/></spine></package>
        """
        let paragraphs = try EpubReadingOrder.paragraphs(
            container: container, fallbackPaths: ["OPS/text/chapter1.xhtml"]
        ) { path in
            switch path {
            case "META-INF/container.xml": return container
            case "OPS/package.opf": return Data(package.utf8)
            case "OPS/text/chapter1.xhtml": return Data("<p>Chapter one</p>".utf8)
            default: throw TextParsingError.noExtractedText
            }
        }
        XCTAssertEqual(paragraphs, ["Chapter one"])
    }

    func testRejectsBookWhenNoChapterTextCanBeExtracted() {
        for files in [[String: String](), ["a.xhtml": "<script>hidden()</script><p> </p>"]] {
            XCTAssertThrowsError(try EpubReadingOrder.paragraphs(
                container: nil, fallbackPaths: ["a.xhtml"]
            ) { try self.read($0, from: files) }) { error in
                guard case TextParsingError.noExtractedText = error else {
                    return XCTFail("Expected noExtractedText, got \(error)")
                }
            }
        }
    }

    private func read(_ path: String, from files: [String: String]) throws -> Data {
        guard let text = files[path] else { throw CocoaError(.fileNoSuchFile) }
        return Data(text.utf8)
    }

    func testMissingOrMalformedMetadataIsRejected() {
        for package in ["<package>", "<package><spine><itemref idref='missing'/></spine></package>",
                        "<package><manifest/></package>"] {
            XCTAssertThrowsError(try EpubReadingOrder.chapterPaths(container: container) { _ in Data(package.utf8) })
        }
        XCTAssertThrowsError(try EpubReadingOrder.chapterPaths(container: Data("<container/>".utf8)) { _ in
            XCTFail("Missing rootfile must not read a package")
            return Data()
        })
    }

    func testExternalChapterReferenceIsRejectedWithoutFetching() {
        let package = """
        <package><manifest><item id="a" href="https://example.invalid/chapter.xhtml"
        media-type="application/xhtml+xml"/></manifest><spine><itemref idref="a"/></spine></package>
        """
        XCTAssertThrowsError(try EpubReadingOrder.chapterPaths(container: container) { _ in Data(package.utf8) })
    }
}
