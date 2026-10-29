import Foundation

final class URLArticleExtractor {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func extractArticle(from url: URL) async throws -> ArticleImport {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let html = String(decoding: data, as: UTF8.self)
        let title = parseTitle(from: html) ?? url.host ?? "网页内容"
        let body = stripHTML(from: html)

        guard body.count > 30 else {
            throw URLError(.cannotParseResponse)
        }

        return ArticleImport(title: title, text: body, sourceURL: url)
    }

    private func parseTitle(from html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "<title[^>]*>(.*?)</title>", options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range), match.numberOfRanges > 1,
              let titleRange = Range(match.range(at: 1), in: html) else {
            return nil
        }

        let title = decodeHTMLEntities(in: String(html[titleRange]))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    private func stripHTML(from html: String) -> String {
        var text = html
        // Remove complete hidden blocks before stripping tags. Dot must also
        // match newlines, otherwise script/style contents become spoken text.
        for pattern in [
            "(?s)<!--.*?-->",
            "(?is)<(head|title|script|style|nav|footer)\\b[^>]*>.*?</\\1\\s*>"
        ] {
            text = text.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
        }

        // Collapse source formatting first, then introduce actual block breaks.
        text = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(
                of: "(?i)</?(?:p|div|section|article|main|aside|header|h[1-6]|li|ul|ol|blockquote|pre|tr|table|dl|dt|dd|figure|figcaption|br|hr)\\b[^>]*>",
                with: "\n", options: .regularExpression
            )
            .replacingOccurrences(of: "(?i)</?(?:td|th)\\b[^>]*>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Decode after removing tags, once only, so escaped text stays text.
        return decodeHTMLEntities(in: text)
            .components(separatedBy: .newlines)
            .map {
                $0.replacingOccurrences(of: "[\\t ]+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func decodeHTMLEntities(in text: String) -> String {
        let named = [
            "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
            "ndash": "–", "mdash": "—", "hellip": "…", "bull": "•", "middot": "·",
            "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”", "laquo": "«", "raquo": "»",
            "copy": "©", "reg": "®", "trade": "™", "euro": "€", "pound": "£", "yen": "¥",
            "auml": "ä", "ouml": "ö", "uuml": "ü", "Auml": "Ä", "Ouml": "Ö", "Uuml": "Ü", "szlig": "ß"
        ]
        guard let regex = try? NSRegularExpression(pattern: "&(#(?:[xX][0-9a-fA-F]+|[0-9]+)|[a-zA-Z][a-zA-Z0-9]+);") else {
            return text
        }
        let result = NSMutableString(string: text)
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
        for match in matches.reversed() {
            guard let range = Range(match.range(at: 1), in: text) else { continue }
            let entity = String(text[range])
            let replacement: String?
            if entity.hasPrefix("#") {
                let isHex = entity.lowercased().hasPrefix("#x")
                let digits = entity.dropFirst(isHex ? 2 : 1)
                replacement = UInt32(digits, radix: isHex ? 16 : 10)
                    .flatMap(UnicodeScalar.init)
                    .map(String.init)
            } else {
                replacement = named[entity]
            }
            if let replacement {
                result.replaceCharacters(in: match.range, with: replacement)
            }
        }

        return result as String
    }
}
