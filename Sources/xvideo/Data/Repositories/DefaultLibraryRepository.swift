import Foundation

struct DefaultLibraryRepository: LibraryRepository, Sendable {
    private let apiClient: LzizyAPIClient

    init(apiClient: LzizyAPIClient) {
        self.apiClient = apiClient
    }

    func fetchCategories() async throws -> [VodCategory] {
        try await apiClient.fetchCategories()
    }

    func fetchList(typeId: Int?, page: Int, keyword: String?, year: String?, area: String?) async throws -> VodListResponse {
        try await apiClient.fetchList(typeId: typeId, page: page, keyword: keyword, year: year, area: area)
    }

    func fetchDetailedList(typeId: Int?, page: Int, keyword: String?, year: String?, area: String?) async throws -> VodListResponse {
        try await apiClient.fetchDetailedList(typeId: typeId, page: page, keyword: keyword, year: year, area: area)
    }

    func search(keyword: String, page: Int) async throws -> VodListResponse {
        try await apiClient.search(keyword: keyword, page: page)
    }

    func fetchDetail(id: Int) async throws -> VodItem {
        try await apiClient.fetchDetail(id: id)
    }
}
