import Foundation
import ZIPFoundation

struct EpubTextParser: TextParser {
    func parse(from fileURL: URL) throws -> [String] {
        guard let archive = Archive(url: fileURL, accessMode: .read) else {
            throw TextParsingError.noExtractedText
        }

        func read(_ path: String) throws -> Data {
            guard let entry = archive[path] else { throw TextParsingError.noExtractedText }
            var data = Data()
            _ = try archive.extract(entry) { chunk in
                data.append(chunk)
            }
            return data
        }
        let fallbackPaths = archive.map(\.path).filter {
            let path = $0.lowercased()
            return path.hasSuffix(".xhtml") || path.hasSuffix(".html") || path.hasSuffix(".htm")
        }
        return try EpubReadingOrder.paragraphs(
            container: try? read("META-INF/container.xml"),
            fallbackPaths: fallbackPaths,
            read: read
        )
    }

}
