import Foundation

final class DefaultLibraryRepository: LibraryRepository, @unchecked Sendable {
    private let apiClient: VodAPIClient
    private let lock = NSLock()
    private var source: VideoSource

    init(apiClient: VodAPIClient, source: VideoSource) {
        self.apiClient = apiClient
        self.source = source
    }

    func updateSource(_ source: VideoSource) {
        lock.lock()
        self.source = source
        lock.unlock()
    }

    func testSource(_ source: VideoSource) async throws -> SourceTestResult {
        try await apiClient.test(source: source)
    }

    func fetchCategories() async throws -> [VodCategory] {
        try await apiClient.fetchCategories(source: currentSource)
    }

    func fetchList(typeId: Int?, page: Int, keyword: String?, year: String?, area: String?) async throws -> VodListResponse {
        try await apiClient.fetchList(
            source: currentSource,
            typeId: typeId,
            page: page,
            keyword: keyword,
            year: year,
            area: area
        )
    }

    func fetchDetailedList(typeId: Int?, page: Int, keyword: String?, year: String?, area: String?) async throws -> VodListResponse {
        try await apiClient.fetchDetailedList(
            source: currentSource,
            typeId: typeId,
            page: page,
            keyword: keyword,
            year: year,
            area: area
        )
    }

    func search(keyword: String, page: Int) async throws -> VodListResponse {
        try await apiClient.search(source: currentSource, keyword: keyword, page: page)
    }

    func fetchDetail(id: Int) async throws -> VodItem {
        try await apiClient.fetchDetail(source: currentSource, id: id)
    }

    private var currentSource: VideoSource {
        lock.lock()
        defer { lock.unlock() }
        return source
    }
}
