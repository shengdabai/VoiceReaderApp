import Foundation

final class URLArticleExtractor {
    func extractArticle(from url: URL) async throws -> ArticleImport {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
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

        return html[titleRange]
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripHTML(from html: String) -> String {
        var text = html
        let patterns = [
            "<script[^>]*>.*?</script>",
            "<style[^>]*>.*?</style>",
            "<nav[^>]*>.*?</nav>",
            "<footer[^>]*>.*?</footer>",
            "<[^>]+>"
        ]

        // .dotMatchesLineSeparators ensures multi-line <script>/<style> blocks
        // are stripped instead of leaking code into the read text. This option
        // is only available on NSRegularExpression, not String.CompareOptions.
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: " ")
        }

        text = text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
