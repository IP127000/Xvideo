import Foundation

struct LoadMovieDetailUseCase: Sendable {
    private let repository: any LibraryRepository

    init(repository: any LibraryRepository) {
        self.repository = repository
    }

    func execute(item: VodItem, cachedItem: VodItem?) async throws -> VodItem {
        if let cachedItem, cachedItem.vodPlayURL?.nilIfBlank != nil {
            return cachedItem
        }

        return try await repository.fetchDetail(id: item.vodId)
    }
}
