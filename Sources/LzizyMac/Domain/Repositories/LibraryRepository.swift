import Foundation

protocol LibraryRepository: Sendable {
    func fetchCategories() async throws -> [VodCategory]
    func fetchList(typeId: Int?, page: Int, keyword: String?) async throws -> VodListResponse
    func fetchDetailedList(typeId: Int?, page: Int, keyword: String?) async throws -> VodListResponse
    func search(keyword: String, page: Int) async throws -> VodListResponse
    func fetchDetail(id: Int) async throws -> VodItem
}
