import Foundation

struct PlayerPreferences: Codable, Equatable {
    var skipIntervalSeconds: Double = 15
    var autoplayNextEpisode = true
}

struct DanmakuPreferences: Codable, Equatable {
    var isEnabled = false
    var fontSize: Double = 18
    var opacity: Double = 0.82
    var speed: Double = 1
    var displayArea: Double = 0.72
    var localMessages: [String] = []
}

struct CachePreferences: Codable, Equatable {
    var maxSizeGB: Double = 8
    var directLinksOnly = true
}

struct AppearancePreferences: Codable, Equatable {
    var compactMode = false
}

private struct StoredPreferences: Codable {
    var player = PlayerPreferences()
    var danmaku = DanmakuPreferences()
    var cache = CachePreferences()
    var appearance = AppearancePreferences()
}

@MainActor
final class UserPreferencesStore: ObservableObject {
    @Published var player = PlayerPreferences() {
        didSet { save() }
    }
    @Published var danmaku = DanmakuPreferences() {
        didSet { save() }
    }
    @Published var cache = CachePreferences() {
        didSet { save() }
    }
    @Published var appearance = AppearancePreferences() {
        didSet { save() }
    }

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var isLoading = false

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let directoryURL = baseURL.appendingPathComponent("Xvideo", isDirectory: true)
        fileURL = directoryURL.appendingPathComponent("preferences.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()

        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        load()
    }

    func importDanmakuText(_ text: String) {
        let messages = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        danmaku.localMessages = Array(messages.prefix(240))
        danmaku.isEnabled = !danmaku.localMessages.isEmpty
    }

    func resetDanmaku() {
        danmaku.localMessages = []
        danmaku.isEnabled = false
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? decoder.decode(StoredPreferences.self, from: data) else {
            return
        }

        isLoading = true
        player = stored.player
        danmaku = stored.danmaku
        cache = stored.cache
        appearance = stored.appearance
        isLoading = false
    }

    private func save() {
        guard !isLoading else { return }
        let stored = StoredPreferences(
            player: player,
            danmaku: danmaku,
            cache: cache,
            appearance: appearance
        )
        guard let data = try? encoder.encode(stored) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
