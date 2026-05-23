import Foundation

struct LoadLibraryPageUseCase: Sendable {
    private let repository: any LibraryRepository
    private let aggregateDisplayLimit = 60

    init(repository: any LibraryRepository) {
        self.repository = repository
    }

    func fetchCategories() async throws -> [VodCategory] {
        try await repository.fetchCategories()
    }

    func fetchPreview(
        selectedCategory: VodCategory?,
        categories: [VodCategory],
        page: Int
    ) async throws -> LibraryPage {
        let availableCategories: [VodCategory]
        if categories.isEmpty {
            availableCategories = try await repository.fetchCategories()
        } else {
            availableCategories = categories
        }

        let aggregateCategories = categoriesToLoad(for: selectedCategory, in: availableCategories)
        if aggregateCategories.count > 1 {
            return try await loadAggregatePreviewPage(categories: Array(aggregateCategories.dropFirst()), page: page)
        }

        let response = try await repository.fetchDetailedList(
            typeId: selectedCategory?.typeId,
            page: page,
            keyword: nil
        )

        if !response.list.isEmpty {
            let remoteCategories = response.class?.isEmpty == false ? response.class : availableCategories
            return LibraryPage(
                items: response.list,
                page: response.page ?? page,
                pageCount: response.pagecount ?? 1,
                total: response.total ?? response.list.count,
                remoteCategories: remoteCategories
            )
        }

        let fallbackResponse = try await repository.fetchList(
            typeId: selectedCategory?.typeId,
            page: page,
            keyword: nil
        )

        if !fallbackResponse.list.isEmpty {
            let remoteCategories = fallbackResponse.class?.isEmpty == false ? fallbackResponse.class : availableCategories
            return LibraryPage(
                items: fallbackResponse.list,
                page: fallbackResponse.page ?? page,
                pageCount: fallbackResponse.pagecount ?? 1,
                total: fallbackResponse.total ?? fallbackResponse.list.count,
                remoteCategories: remoteCategories
            )
        }

        if aggregateCategories.count > 1 {
            return try await loadAggregatePreviewPage(categories: Array(aggregateCategories.dropFirst()), page: page)
        }

        return LibraryPage(response: fallbackResponse, fallbackPage: page)
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

        let aggregateCategories = categoriesToLoad(for: selectedCategory, in: availableCategories)
        if aggregateCategories.count > 1 {
            return try await loadAggregatePage(categories: Array(aggregateCategories.dropFirst()), page: page)
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
            if !fallback.list.isEmpty {
                return LibraryPage(response: fallback, fallbackPage: page)
            }

            if aggregateCategories.count > 1 {
                return try await loadAggregatePage(categories: Array(aggregateCategories.dropFirst()), page: page)
            }

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

    private func loadAggregatePreviewPage(categories: [VodCategory], page: Int) async throws -> LibraryPage {
        let responses = await withTaskGroup(of: VodListResponse?.self) { group in
            for category in categories {
                group.addTask {
                    do {
                        let response = try await repository.fetchDetailedList(
                            typeId: category.typeId,
                            page: page,
                            keyword: nil
                        )

                        if !response.list.isEmpty {
                            return response
                        }

                        return try await repository.fetchList(
                            typeId: category.typeId,
                            page: page,
                            keyword: nil
                        )
                    } catch {
                        return nil
                    }
                }
            }

            var responses: [VodListResponse] = []
            for await response in group {
                guard let response else { continue }
                responses.append(response)
            }
            return responses
        }

        guard !responses.isEmpty else {
            throw APIError.badResponse
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
        let visibleItems = Array(merged.prefix(aggregateDisplayLimit))

        return LibraryPage(
            items: visibleItems,
            page: page,
            pageCount: responses.compactMap(\.pagecount).max() ?? 1,
            total: responses.compactMap(\.total).reduce(0, +)
        )
    }

    private func loadAggregatePage(categories: [VodCategory], page: Int) async throws -> LibraryPage {
        let responses = await withTaskGroup(of: VodListResponse?.self) { group in
            for category in categories {
                group.addTask {
                    do {
                        let response = try await repository.fetchDetailedList(
                            typeId: category.typeId,
                            page: page,
                            keyword: nil
                        )

                        if !response.list.isEmpty {
                            return response
                        }

                        return try await repository.fetchList(
                            typeId: category.typeId,
                            page: page,
                            keyword: nil
                        )
                    } catch {
                        return nil
                    }
                }
            }

            var responses: [VodListResponse] = []
            for await response in group {
                guard let response else { continue }
                responses.append(response)
            }
            return responses
        }

        guard !responses.isEmpty else {
            throw APIError.badResponse
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
        let visibleItems = Array(merged.prefix(aggregateDisplayLimit))

        return LibraryPage(
            items: visibleItems,
            page: page,
            pageCount: responses.compactMap(\.pagecount).max() ?? 1,
            total: responses.compactMap(\.total).reduce(0, +)
        )
    }
}
