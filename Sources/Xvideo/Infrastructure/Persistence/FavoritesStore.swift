import Foundation

struct FavoriteMovie: Codable, Identifiable, Hashable {
    let item: VodItem
    let addedAt: Date
    let sourceID: VideoSource.ID?
    let sourceName: String?

    var id: String {
        "\(sourceID?.uuidString ?? "legacy")-\(item.id)"
    }

    init(item: VodItem, addedAt: Date, source: VideoSource?) {
        self.item = item
        self.addedAt = addedAt
        sourceID = source?.id
        sourceName = source?.name
    }

    func matches(_ candidate: VodItem, sourceID candidateSourceID: VideoSource.ID?) -> Bool {
        guard item.id == candidate.id else { return false }
        guard let sourceID else { return true }
        guard let candidateSourceID else { return false }
        return sourceID == candidateSourceID
    }
}

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var items: [FavoriteMovie] = []

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let directoryURL = baseURL.appendingPathComponent("Xvideo", isDirectory: true)
        fileURL = directoryURL.appendingPathComponent("favorites.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        load()
    }

    func isFavorite(_ item: VodItem?, sourceID: VideoSource.ID?) -> Bool {
        guard let item else { return false }
        return items.contains { $0.matches(item, sourceID: sourceID) }
    }

    func toggle(_ item: VodItem, source: VideoSource?) {
        if let index = items.firstIndex(where: { $0.matches(item, sourceID: source?.id) }) {
            items.remove(at: index)
        } else {
            items.insert(FavoriteMovie(item: item, addedAt: Date(), source: source), at: 0)
        }

        save()
    }

    func replace(with newItems: [FavoriteMovie]) {
        items = newItems
        save()
    }

    func removeAll() {
        items = []
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        items = (try? decoder.decode([FavoriteMovie].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
