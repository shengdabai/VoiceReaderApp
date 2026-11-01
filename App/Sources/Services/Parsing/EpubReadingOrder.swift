import Foundation

/// Resolves the EPUB package spine, rather than guessing order from filenames.
enum EpubReadingOrder {
    /// Archive access is injected so chapter extraction can be checked offline.
    static func paragraphs(container: Data?, fallbackPaths: [String],
                           read: (String) throws -> Data) throws -> [String] {
        func extract(_ paths: [String]) -> [String] {
            var chapterTexts: [String] = []
            for path in paths {
                guard let data = try? read(path),
                      let html = String(data: data, encoding: .utf8) else { continue }
                chapterTexts.append(URLArticleExtractor.stripHTML(from: html))
            }
            return normalizeParagraphs(from: chapterTexts.joined(separator: "\n"))
        }
        // Damaged or missing package metadata keeps the legacy filename order, and so does a spine
        // whose chapters cannot be read at all (stale manifest, href case that differs from the ZIP).
        var paragraphs: [String] = []
        if let container, let spine = try? chapterPaths(container: container, read: read) {
            paragraphs = extract(spine)
        }
        if paragraphs.isEmpty { paragraphs = extract(fallbackPaths.sorted()) }
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
