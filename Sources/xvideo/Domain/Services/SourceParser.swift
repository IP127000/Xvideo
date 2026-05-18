import Foundation

enum SourceParser {
    static func parsePlaybackSources(from item: VodItem) -> [PlaybackSource] {
        let sourceNames = splitGroups(item.vodPlayFrom).map { readableSourceName($0) }
        let groups = splitGroups(item.vodPlayURL)

        return groups.enumerated().compactMap { index, group in
            let episodes = parseEpisodes(group)
            guard !episodes.isEmpty else { return nil }
            let name = sourceNames.indices.contains(index) ? sourceNames[index] : "播放源 \(index + 1)"
            return PlaybackSource(id: "\(index)-\(name)", name: name, episodes: episodes)
        }
    }

    static func parseDownloads(from item: VodItem) -> [Episode] {
        parseEpisodes(item.vodDownURL ?? "")
    }

    private static func splitGroups(_ raw: String?) -> [String] {
        guard let raw else { return [] }
        return raw.components(separatedBy: "$$$").filter { !$0.isEmpty }
    }

    private static func parseEpisodes(_ raw: String) -> [Episode] {
        raw.components(separatedBy: "#").compactMap { pair in
            let pieces = pair.components(separatedBy: "$")
            guard pieces.count >= 2 else { return nil }
            let title = pieces[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let urlString = pieces.dropFirst().joined(separator: "$")
            guard let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: encoded) else {
                return nil
            }
            return Episode(title: title.isEmpty ? "未命名" : title, url: url)
        }
    }

    private static func readableSourceName(_ raw: String) -> String {
        switch raw.lowercased() {
        case "lzm3u8":
            return "量子 M3U8"
        case "liangzi":
            return "量子在线"
        default:
            return raw
        }
    }
}
