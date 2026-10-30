import Foundation
import XCTest
@testable import VoiceReaderApp

final class URLArticleExtractorTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ArticleFixtureProtocol.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        session = nil
        super.tearDown()
    }

    func testRemovesMultilineHiddenContent() async throws {
        let article = try await extract("hidden")
        XCTAssertEqual(article.title, "Article title")
        XCTAssertEqual(article.text, ArticleFixtureProtocol.firstParagraph)
    }

    func testPreservesBlockParagraphsAndLineBreaks() async throws {
        let article = try await extract("blocks")
        XCTAssertEqual(normalizeParagraphs(from: article.text), [
            "Heading", ArticleFixtureProtocol.firstParagraph, "Second paragraph", "Line two"
        ])
    }

    func testDoesNotInsertSpacesInsideInlineWords() async throws {
        let article = try await extract("inline")
        XCTAssertEqual(article.text, "A readable paragraph about international readers and 中文朗读。")
    }

    func testDecodesEntitiesInTitleAndBodyOnce() async throws {
        let article = try await extract("entities")
        XCTAssertEqual(article.title, "Tom & Jerry — 中文")
        XCTAssertEqual(article.text, "Quoted \"text\" and Grüße 中文 😀 <literal> &lt; &unknown; readable content.")
    }

    func testFallsBackToHostForEmptyTitle() async throws {
        let article = try await extract("empty-title")
        XCTAssertEqual(article.title, "article.tests.invalid")
    }

    func testInvalidNumericEntitiesRemainReadable() async throws {
        let article = try await extract("invalid-entities")
        XCTAssertEqual(article.title, "&#xD800; &#1114112; &#xFFFFFFFFFF;")
    }

    func testRejectsDocumentWithOnlyHiddenContent() async {
        do {
            _ = try await extract("hidden-only")
            XCTFail("Hidden metadata and script content must not count as article text")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .cannotParseResponse)
        }
    }

    func testRejectsShortArticle() async {
        do {
            _ = try await extract("short")
            XCTFail("Short responses must be rejected")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .cannotParseResponse)
        }
    }

    func testRejectsHTTPFailure() async {
        do {
            _ = try await extract("failure")
            XCTFail("HTTP failures must be rejected")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }
    }

    func testImportsArticleWithLongTitleWithoutExceedingFileNameLimit() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("article-import-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let importer = DocumentImporter(fileManager: ImportFixtureFileManager(documentsURL: directory),
                                        urlExtractor: URLArticleExtractor(session: session))
        let url = try XCTUnwrap(URL(string: "https://article.tests.invalid/long-title"))

        let imported = try await importer.importArticle(from: url)

        XCTAssertEqual(imported.title, ArticleFixtureProtocol.longTitle)
        XCTAssertEqual(imported.format, .txt)
        XCTAssertEqual(imported.localURL.deletingLastPathComponent(), directory.appendingPathComponent("Books", isDirectory: true))
        XCTAssertEqual(try String(contentsOf: imported.localURL, encoding: .utf8), ArticleFixtureProtocol.firstParagraph)
    }

    private func extract(_ fixture: String) async throws -> ArticleImport {
        let url = try XCTUnwrap(URL(string: "https://article.tests.invalid/\(fixture)"))
        let article = try await URLArticleExtractor(session: session).extractArticle(from: url)
        XCTAssertEqual(article.sourceURL, url)
        return article
    }
}

// Fixed in-memory responses: these tests never contact a web server or TTS API.
private final class ArticleFixtureProtocol: URLProtocol {
    static let firstParagraph = "This is the first readable paragraph for this article."
    static let longTitle = String(repeating: "Long article title 中文标题 ", count: 30) + "End"

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "article.tests.invalid"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let html: String
        switch url.lastPathComponent {
        case "hidden":
            html = """
            <head><title>Article title</title><meta name="description" content="metadata"></head>
            <!-- invisible comment -->
            <SCRIPT type="text/javascript">
            window.unreadable = 'DO NOT READ SCRIPT';
            </SCRIPT>
            <style>
            .hidden { display: none; }
            </style>
            <nav>
            Site navigation
            </nav>
            <p>\(Self.firstParagraph)</p>
            <footer>
            Footer links
            </footer>
            """
        case "blocks":
            html = "<h1>Heading</h1><p>\(Self.firstParagraph)</p><p>Second paragraph<br/>Line two</p>"
        case "inline":
            html = "<p>A readable paragraph about inter<strong>national</strong> readers and 中<em>文</em>朗读。</p>"
        case "entities":
            html = "<title>Tom &amp; Jerry &mdash; &#20013;&#x6587;</title><p>Quoted &quot;text&quot; and Gr&uuml;&szlig;e 中文 &#x1F600; &lt;literal&gt; &amp;lt; &unknown; readable content.</p>"
        case "empty-title":
            html = "<title> \n </title><p>\(Self.firstParagraph)</p>"
        case "invalid-entities":
            html = "<title>&#xD800; &#1114112; &#xFFFFFFFFFF;</title><p>\(Self.firstParagraph)</p>"
        case "hidden-only":
            html = "<head><title>\(Self.firstParagraph)</title></head><script>\n\(Self.firstParagraph)\n</script>"
        case "long-title":
            html = "<title>\(Self.longTitle)</title><p>\(Self.firstParagraph)</p>"
        default:
            html = "<p>Short</p>"
        }
        let response = HTTPURLResponse(url: url, statusCode: url.lastPathComponent == "failure" ? 500 : 200,
                                       httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/html; charset=utf-8"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(html.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class ImportFixtureFileManager: FileManager, @unchecked Sendable {
    let documentsURL: URL

    init(documentsURL: URL) {
        self.documentsURL = documentsURL
        super.init()
    }

    override func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        [documentsURL]
    }
}
