import Foundation

struct LoadLibraryPageUseCase: Sendable {
    private let repository: any LibraryRepository

    init(repository: any LibraryRepository) {
        self.repository = repository
    }

    func execute(
        selectedCategory: VodCategory?,
        categories: [VodCategory],
        keyword: String,
        page: Int
    ) async throws -> LibraryPage {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedKeyword.isEmpty {
            let response = try await repository.search(keyword: trimmedKeyword, page: page)
            return LibraryPage(response: response, fallbackPage: page)
        }

        let availableCategories: [VodCategory]
        if categories.isEmpty {
            availableCategories = try await repository.fetchCategories()
        } else {
            availableCategories = categories
        }

        let categoriesToLoad = categoriesToLoad(for: selectedCategory, in: availableCategories)
        if categoriesToLoad.count > 1 {
            return try await loadAggregatePage(categories: categoriesToLoad, page: page)
        }

        let response = try await repository.fetchDetailedList(
            typeId: selectedCategory?.typeId,
            page: page,
            keyword: nil
        )

        if response.list.isEmpty {
            let fallback = try await repository.fetchList(
                typeId: selectedCategory?.typeId,
                page: page,
                keyword: nil
            )
            return LibraryPage(response: fallback, fallbackPage: page)
        }

        let remoteCategories = response.class?.isEmpty == false ? response.class : availableCategories
        return LibraryPage(
            items: response.list,
            page: response.page ?? page,
            pageCount: response.pagecount ?? 1,
            total: response.total ?? response.list.count,
            remoteCategories: remoteCategories
        )
    }

    private func categoriesToLoad(for category: VodCategory?, in categories: [VodCategory]) -> [VodCategory] {
        guard let category else { return [] }

        let children = categories
            .filter { $0.typePid == category.typeId }
            .sorted { $0.typeId < $1.typeId }

        guard !children.isEmpty else {
            return [category]
        }

        return [category] + children
    }

    private func loadAggregatePage(categories: [VodCategory], page: Int) async throws -> LibraryPage {
        var responses: [VodListResponse] = []

        for category in categories {
            let response = try await repository.fetchDetailedList(
                typeId: category.typeId,
                page: page,
                keyword: nil
            )
            responses.append(response)
        }

        var seen = Set<Int>()
        let merged = responses
            .flatMap(\.list)
            .filter { item in
                guard !seen.contains(item.id) else { return false }
                seen.insert(item.id)
                return true
            }
            .sorted { ($0.vodTime ?? "") > ($1.vodTime ?? "") }

        return LibraryPage(
            items: merged,
            page: page,
            pageCount: responses.compactMap(\.pagecount).max() ?? 1,
            total: responses.compactMap(\.total).reduce(0, +)
        )
    }
}
