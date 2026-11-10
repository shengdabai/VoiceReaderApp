import Foundation

/// Resolves the EPUB package spine, rather than guessing order from filenames.
enum EpubReadingOrder {
    /// Archive access is injected so chapter extraction can be checked offline.
    static func paragraphs(container: Data?, fallbackPaths: [String],
                           read: (String) throws -> Data) throws -> [String] {
        func extract(_ paths: [String]) throws -> [String] {
            var chapterTexts: [String] = []
            for path in paths {
                do {
                    let data = try read(path)
                    guard let html = String(data: data, encoding: .utf8) else { continue }
                    chapterTexts.append(URLArticleExtractor.stripHTML(from: html))
                } catch TextParsingError.resourceLimitExceeded {
                    throw TextParsingError.resourceLimitExceeded
                } catch { continue }
            }
            return normalizeParagraphs(from: chapterTexts.joined(separator: "\n"))
        }
        // Damaged or missing package metadata keeps the legacy filename order, and so does a spine
        // whose chapters cannot be read at all (stale manifest, href case that differs from the ZIP).
        var paragraphs: [String] = []
        if let container {
            do {
                let spine = try chapterPaths(container: container, read: read)
                paragraphs = try extract(spine)
            } catch TextParsingError.resourceLimitExceeded {
                throw TextParsingError.resourceLimitExceeded
            } catch {} // Damaged metadata still falls back to filename order.
        }
        if paragraphs.isEmpty { paragraphs = try extract(fallbackPaths.sorted()) }
        guard !paragraphs.isEmpty else { throw TextParsingError.noExtractedText }
        return paragraphs
    }

    static func chapterPaths(container: Data, read: (String) throws -> Data) throws -> [String] {
        let rootfiles = try elements(container)["rootfile"] ?? []
        guard let package = rootfiles.first(where: {
            $0["media-type"] == "application/oebps-package+xml"
        })?["full-path"] else { throw TextParsingError.noExtractedText }
        let packagePath = try resolve(package, relativeTo: "container.xml")
        let metadata = try elements(read(packagePath))
        var manifest: [String: String] = [:]
        for item in metadata["item"] ?? [] {
            if let id = item["id"], let href = item["href"],
               ["application/xhtml+xml", "text/html"].contains(item["media-type"] ?? "") {
                manifest[id] = href
            }
        }
        var paths: [String] = []
        for item in metadata["itemref"] ?? [] where item["linear"] != "no" {
            guard let id = item["idref"], let href = manifest[id] else {
                continue
            }
            paths.append(try resolve(href, relativeTo: packagePath))
        }
        guard !paths.isEmpty else { throw TextParsingError.noExtractedText }
        return paths
    }

    private static func resolve(_ reference: String, relativeTo path: String) throws -> String {
        let base = URL(string: "https://epub.invalid/")!.appendingPathComponent(path)
        guard let url = URL(string: reference, relativeTo: base)?.absoluteURL,
              url.scheme == "https", url.host == "epub.invalid", url.user == nil,
              url.password == nil, url.query == nil else {
            throw TextParsingError.noExtractedText
        }
        return String(url.standardized.path.dropFirst())
    }

    private static func elements(_ data: Data) throws -> [String: [[String: String]]] {
        let collector = ElementCollector()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = collector
        guard parser.parse() else { throw TextParsingError.noExtractedText }
        return collector.elements
    }
}

/// Bounds both a single ZIP member and all decompressed bytes in one import.
/// Checking emitted chunks also covers entries with dishonest size metadata.
struct EpubReadBudget {
    let maximumEntryBytes: Int
    private var remainingBytes: Int

    init(maximumEntryBytes: Int = 16 * 1024 * 1024, maximumTotalBytes: Int = 64 * 1024 * 1024) {
        self.maximumEntryBytes = maximumEntryBytes
        self.remainingBytes = maximumTotalBytes
    }

    mutating func append(_ chunk: Data, to entry: inout Data) throws {
        guard chunk.count <= maximumEntryBytes - entry.count, chunk.count <= remainingBytes else {
            throw TextParsingError.resourceLimitExceeded
        }
        remainingBytes -= chunk.count
        entry.append(chunk)
    }
}

private final class ElementCollector: NSObject, XMLParserDelegate {
    var elements: [String: [[String: String]]] = [:]
    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        if ["rootfile", "item", "itemref"].contains(elementName) {
            elements[elementName, default: []].append(attributeDict)
        }
    }
}
