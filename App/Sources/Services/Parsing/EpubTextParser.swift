import Foundation
import ZIPFoundation

struct EpubTextParser: TextParser {
    func parse(from fileURL: URL) throws -> [String] {
        guard let archive = Archive(url: fileURL, accessMode: .read) else {
            throw TextParsingError.noExtractedText
        }

        var budget = EpubReadBudget()
        func read(_ path: String) throws -> Data {
            guard let entry = archive[path] else { throw TextParsingError.noExtractedText }
            guard entry.uncompressedSize <= UInt64(budget.maximumEntryBytes) else {
                throw TextParsingError.resourceLimitExceeded
            }
            var data = Data()
            _ = try archive.extract(entry) { chunk in
                try budget.append(chunk, to: &data)
            }
            return data
        }
        let fallbackPaths = archive.map(\.path).filter {
            let path = $0.lowercased()
            return path.hasSuffix(".xhtml") || path.hasSuffix(".html") || path.hasSuffix(".htm")
        }
        var container: Data?
        do { container = try read("META-INF/container.xml") }
        catch TextParsingError.resourceLimitExceeded { throw TextParsingError.resourceLimitExceeded }
        catch {} // Missing or damaged metadata can still use filename order.
        return try EpubReadingOrder.paragraphs(
            container: container,
            fallbackPaths: fallbackPaths,
            read: read
        )
    }

}
