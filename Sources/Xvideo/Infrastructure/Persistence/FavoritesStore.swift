import Foundation

struct FavoriteMovie: Codable, Identifiable, Hashable {
    let item: VodItem
    let addedAt: Date

    var id: Int { item.id }
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

    func isFavorite(_ item: VodItem?) -> Bool {
        guard let item else { return false }
        return items.contains { $0.id == item.id }
    }

    func toggle(_ item: VodItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
        } else {
            items.insert(FavoriteMovie(item: item, addedAt: Date()), at: 0)
        }

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
