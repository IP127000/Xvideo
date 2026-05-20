import Foundation

enum PlaybackURLResolver {
    static func resolve(_ url: URL) async -> URL {
        guard shouldResolve(url) else { return url }
        return (try? await resolve(url, depth: 0)) ?? url
    }

    private static func shouldResolve(_ url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        if ["m3u8", "mp4", "m4v", "mov"].contains(pathExtension) {
            return false
        }

        return url.path.contains("/share/") || pathExtension.isEmpty
    }

    private static func resolve(_ url: URL, depth: Int) async throws -> URL {
        guard depth < 3 else { return url }

        let html = try await fetchText(from: url)
        guard let candidate = playableCandidate(in: html, baseURL: url) else {
            return url
        }

        if shouldResolve(candidate), candidate != url {
            return try await resolve(candidate, depth: depth + 1)
        }

        return candidate
    }

    private static func fetchText(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(url.deletingLastPathComponent().absoluteString, forHTTPHeaderField: "Referer")

        let (data, _) = try await URLSession.shared.data(for: request)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func playableCandidate(in html: String, baseURL: URL) -> URL? {
        let normalizedHTML = html.replacingOccurrences(of: "\\/", with: "/")

        if let directM3U8 = firstMatch(
            in: normalizedHTML,
            pattern: #"https?://[^"'<>\s]+\.m3u8[^"'<>\s]*"#
        ), let url = URL(string: directM3U8) {
            return url
        }

        let candidatePatterns = [
            #""url"\s*:\s*"([^"]+)""#,
            #"url\s*:\s*['"]([^'"]+)['"]"#,
            #"(?:src|data-url)\s*=\s*['"]([^'"]+)['"]"#
        ]

        for pattern in candidatePatterns {
            for rawCandidate in matches(in: html, pattern: pattern) {
                let candidate = decodeCandidate(rawCandidate, html: html)
                guard let url = URL(string: candidate, relativeTo: baseURL)?.absoluteURL else {
                    continue
                }

                if isPlayable(url) || shouldResolve(url) {
                    return url
                }
            }
        }

        return nil
    }

    private static func isPlayable(_ url: URL) -> Bool {
        ["m3u8", "mp4", "m4v", "mov"].contains(url.pathExtension.lowercased())
    }

    private static func decodeCandidate(_ raw: String, html: String) -> String {
        var value = decodeJSONString(raw) ?? raw
        value = value.replacingOccurrences(of: "\\/", with: "/")

        if isBase64EncodedPlayerURL(html),
           let data = Data(base64Encoded: value),
           let decoded = String(data: data, encoding: .utf8) {
            value = decoded
        }

        return value.removingPercentEncoding ?? value
    }

    private static func isBase64EncodedPlayerURL(_ html: String) -> Bool {
        html.range(
            of: #""encrypt"\s*:\s*"?2"?"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func decodeJSONString(_ raw: String) -> String? {
        let escaped = raw.replacingOccurrences(of: #"""#, with: #"\""#)
        guard let data = "\"\(escaped)\"".data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(String.self, from: data)
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        matches(in: text, pattern: pattern, captureGroup: 0).first
    }

    private static func matches(in text: String, pattern: String, captureGroup: Int = 1) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { result in
            guard result.numberOfRanges > captureGroup,
                  let matchRange = Range(result.range(at: captureGroup), in: text) else {
                return nil
            }
            return String(text[matchRange])
        }
    }
}
