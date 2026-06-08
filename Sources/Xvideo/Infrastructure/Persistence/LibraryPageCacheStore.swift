import Foundation

struct LibraryCacheKey: Codable, Hashable {
    let categoryID: Int?
    let keyword: String
    let page: Int
}

struct CachedLibraryPage: Codable {
    let page: LibraryPage
    let loadedAt: Date
    let isComplete: Bool

    init(page: LibraryPage, loadedAt: Date, isComplete: Bool) {
        self.page = page
        self.loadedAt = loadedAt
        self.isComplete = isComplete
    }

    private enum CodingKeys: String, CodingKey {
        case page
        case loadedAt
        case isComplete
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        page = try container.decode(LibraryPage.self, forKey: .page)
        loadedAt = try container.decode(Date.self, forKey: .loadedAt)
        isComplete = try container.decodeIfPresent(Bool.self, forKey: .isComplete) ?? true
    }
}

struct LibraryCacheSnapshot {
    let categories: [VodCategory]
    let pages: [LibraryCacheKey: CachedLibraryPage]
}

actor LibraryPageCacheStore {
    private struct CacheRecord: Codable {
        let key: LibraryCacheKey
        let page: CachedLibraryPage
    }

    private struct CacheFile: Codable {
        let categories: [VodCategory]
        let records: [CacheRecord]
    }

    private let directoryURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let baseURL = AppStorageDirectory.applicationSupport(fileManager: fileManager)
        let directoryURL = baseURL.appendingPathComponent("Xvideo", isDirectory: true)
        self.directoryURL = directoryURL

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func load(sourceID: VideoSource.ID) -> LibraryCacheSnapshot {
        let fileURL = cacheFileURL(for: sourceID)
        let readableURL = FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : legacyFallbackURL(for: sourceID)

        guard let data = try? Data(contentsOf: readableURL),
              let cacheFile = try? decoder.decode(CacheFile.self, from: data) else {
            return LibraryCacheSnapshot(categories: [], pages: [:])
        }

        let pages = cacheFile.records.reduce(into: [LibraryCacheKey: CachedLibraryPage]()) { result, record in
            result[record.key] = record.page
        }
        return LibraryCacheSnapshot(categories: cacheFile.categories, pages: pages)
    }

    func save(sourceID: VideoSource.ID, categories: [VodCategory], pages: [LibraryCacheKey: CachedLibraryPage]) {
        let records = pages
            .map { CacheRecord(key: $0.key, page: $0.value) }
            .sorted { lhs, rhs in
                if lhs.key.keyword != rhs.key.keyword {
                    return lhs.key.keyword < rhs.key.keyword
                }
                if lhs.key.page != rhs.key.page {
                    return lhs.key.page < rhs.key.page
                }
                return (lhs.key.categoryID ?? -1) < (rhs.key.categoryID ?? -1)
            }
        let cacheFile = CacheFile(categories: categories, records: records)

        guard let data = try? encoder.encode(cacheFile) else { return }
        try? data.write(to: cacheFileURL(for: sourceID), options: [.atomic])
    }

    private func cacheFileURL(for sourceID: VideoSource.ID) -> URL {
        directoryURL.appendingPathComponent("library-cache-\(sourceID.uuidString).json")
    }

    private func legacyFallbackURL(for sourceID: VideoSource.ID) -> URL {
        cacheFileURL(for: sourceID)
    }
}
