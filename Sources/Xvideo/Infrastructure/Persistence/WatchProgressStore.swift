import Foundation

struct WatchProgressItem: Codable, Identifiable, Hashable {
    let item: VodItem
    let sourceID: VideoSource.ID?
    let sourceName: String?
    let playbackSourceID: PlaybackSource.ID?
    let playbackSourceName: String?
    let episodeTitle: String
    let episodeURL: URL
    let positionSeconds: Double
    let durationSeconds: Double?
    let updatedAt: Date

    var id: String {
        "\(sourceID?.uuidString ?? "legacy")-\(item.id)"
    }

    var progressFraction: Double? {
        guard let durationSeconds,
              durationSeconds.isFinite,
              durationSeconds > 0,
              positionSeconds.isFinite,
              positionSeconds > 0 else {
            return nil
        }
        return min(max(positionSeconds / durationSeconds, 0), 1)
    }

    var positionLabel: String {
        guard positionSeconds.isFinite, positionSeconds >= 5 else {
            return episodeTitle
        }
        return "\(episodeTitle) · \(Self.formatTime(positionSeconds))"
    }

    func matches(_ candidate: VodItem?, sourceID candidateSourceID: VideoSource.ID?) -> Bool {
        guard let candidate, item.id == candidate.id else { return false }
        guard let sourceID else { return true }
        guard let candidateSourceID else { return false }
        return sourceID == candidateSourceID
    }

    private static func formatTime(_ seconds: Double) -> String {
        let total = max(Int(seconds), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainingSeconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

@MainActor
final class WatchProgressStore: ObservableObject {
    @Published private(set) var items: [WatchProgressItem] = []

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let maximumItemCount = 80

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let directoryURL = baseURL.appendingPathComponent("Xvideo", isDirectory: true)
        fileURL = directoryURL.appendingPathComponent("watch-progress.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        load()
    }

    func progress(for item: VodItem?, sourceID: VideoSource.ID?) -> WatchProgressItem? {
        items.first { $0.matches(item, sourceID: sourceID) }
    }

    func record(
        item: VodItem,
        source: VideoSource?,
        playbackSource: PlaybackSource?,
        episode: Episode,
        positionSeconds: Double,
        durationSeconds: Double?
    ) {
        let normalizedPosition = normalizedPosition(positionSeconds, durationSeconds: durationSeconds)
        let normalizedDuration = durationSeconds.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }

        let progress = WatchProgressItem(
            item: item,
            sourceID: source?.id,
            sourceName: source?.name,
            playbackSourceID: playbackSource?.id,
            playbackSourceName: playbackSource?.name,
            episodeTitle: episode.title,
            episodeURL: episode.url,
            positionSeconds: normalizedPosition,
            durationSeconds: normalizedDuration,
            updatedAt: Date()
        )

        items.removeAll { $0.id == progress.id }
        items.insert(progress, at: 0)
        if items.count > maximumItemCount {
            items.removeLast(items.count - maximumItemCount)
        }
        save()
    }

    func remove(_ item: WatchProgressItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    private func normalizedPosition(_ positionSeconds: Double, durationSeconds: Double?) -> Double {
        guard positionSeconds.isFinite, positionSeconds > 0 else { return 0 }

        if let durationSeconds,
           durationSeconds.isFinite,
           durationSeconds > 0,
           durationSeconds - positionSeconds < 20 {
            return 0
        }

        return positionSeconds
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        items = (try? decoder.decode([WatchProgressItem].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
