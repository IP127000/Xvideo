import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var categories: [VodCategory] = []
    @Published var selectedCategory: VodCategory?
    @Published var movies: [VodItem] = []
    @Published var selectedMovie: VodItem?
    @Published var detailMovie: VodItem?
    @Published var searchText = ""
    @Published var isLoadingList = false
    @Published var isLoadingDetail = false
    @Published var errorMessage: String?
    @Published var page = 1
    @Published var pageCount = 1
    @Published var total = 0

    private let repository: any LibraryRepository

    init(repository: any LibraryRepository) {
        self.repository = repository
    }

    var rootCategories: [VodCategory] {
        categories.filter { $0.typePid == 0 && $0.typeName != "演员" && $0.typeName != "新闻资讯" }
    }

    var childCategories: [VodCategory] {
        guard let selectedCategory else { return [] }
        return categories.filter { $0.typePid == selectedCategory.typeId }
    }

    var currentTitle: String {
        if let selectedCategory {
            return selectedCategory.typeName
        }
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "搜索结果"
        }
        return "最新更新"
    }

    func loadInitialData() async {
        guard movies.isEmpty else { return }
        await loadList(reset: true)
    }

    func refresh() async {
        await loadList(reset: true)
    }

    func selectCategory(_ category: VodCategory?) async {
        selectedCategory = category
        searchText = ""
        await loadList(reset: true)
    }

    func search() async {
        selectedCategory = nil
        await loadList(reset: true)
    }

    func loadNextPageIfNeeded(current item: VodItem) async {
        guard item.id == movies.last?.id, page < pageCount, !isLoadingList else { return }
        await loadList(reset: false)
    }

    func selectMovie(_ item: VodItem) async {
        selectedMovie = movieFromCache(matching: item) ?? item
        detailMovie = nil
        isLoadingDetail = true
        errorMessage = nil

        do {
            if let cached = movieFromCache(matching: item), cached.vodPlayURL != nil {
                detailMovie = cached
            } else {
                detailMovie = try await repository.fetchDetail(id: item.vodId)
            }
        } catch {
            guard !isCancellation(error) else {
                detailMovie = item
                isLoadingDetail = false
                return
            }
            errorMessage = error.localizedDescription
            detailMovie = item
        }

        isLoadingDetail = false
    }

    private func loadList(reset: Bool) async {
        isLoadingList = true
        errorMessage = nil
        if reset {
            movies = []
            selectedMovie = nil
            detailMovie = nil
        }

        let targetPage = reset ? 1 : page + 1
        do {
            let effectiveResponse = try await loadResponse(page: targetPage)

            if shouldUseRemoteCategories(from: effectiveResponse),
               let remoteCategories = effectiveResponse.class,
               !remoteCategories.isEmpty {
                categories = remoteCategories
            } else if categories.isEmpty {
                let remoteCategories = try await repository.fetchCategories()
                if !remoteCategories.isEmpty {
                    categories = remoteCategories
                }
            }

            page = effectiveResponse.page ?? targetPage
            pageCount = effectiveResponse.pagecount ?? 1
            total = effectiveResponse.total ?? effectiveResponse.list.count

            if reset {
                movies = effectiveResponse.list
                if let first = effectiveResponse.list.first {
                    await selectMovie(first)
                } else {
                    selectedMovie = nil
                    detailMovie = nil
                }
            } else {
                movies.append(contentsOf: effectiveResponse.list)
            }
        } catch {
            guard !isCancellation(error) else {
                isLoadingList = false
                return
            }
            errorMessage = error.localizedDescription
        }

        isLoadingList = false
    }

    private func loadResponse(page targetPage: Int) async throws -> VodListResponse {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !keyword.isEmpty {
            return try await repository.search(keyword: keyword, page: targetPage)
        }

        if categories.isEmpty {
            let remoteCategories = try await repository.fetchCategories()
            if !remoteCategories.isEmpty {
                categories = remoteCategories
            }
        }

        let aggregateCategories = categoriesToLoad(for: selectedCategory)
        if aggregateCategories.count > 1 {
            return try await loadAggregateResponse(categories: aggregateCategories, page: targetPage)
        }

        let response = try await repository.fetchDetailedList(
            typeId: selectedCategory?.typeId,
            page: targetPage,
            keyword: nil
        )

        if response.list.isEmpty {
            return try await repository.fetchList(
                typeId: selectedCategory?.typeId,
                page: targetPage,
                keyword: nil
            )
        }

        return response
    }

    private func categoriesToLoad(for category: VodCategory?) -> [VodCategory] {
        guard let category else { return [] }

        let children = categories
            .filter { $0.typePid == category.typeId }
            .sorted { $0.typeId < $1.typeId }

        guard !children.isEmpty else {
            return [category]
        }

        return [category] + children
    }

    private func loadAggregateResponse(categories: [VodCategory], page targetPage: Int) async throws -> VodListResponse {
        var responses: [VodListResponse] = []

        for category in categories {
            let response = try await repository.fetchDetailedList(typeId: category.typeId, page: targetPage, keyword: nil)
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
            .sorted {
                ($0.vodTime ?? "") > ($1.vodTime ?? "")
            }

        let pageCount = responses.compactMap(\.pagecount).max() ?? 1
        let total = responses.compactMap(\.total).reduce(0, +)

        return VodListResponse(
            page: targetPage,
            pagecount: pageCount,
            total: total,
            list: merged
        )
    }

    private func shouldUseRemoteCategories(from response: VodListResponse) -> Bool {
        guard let remoteCategories = response.class, !remoteCategories.isEmpty else {
            return false
        }

        let hasRootCategory = remoteCategories.contains { $0.typePid == 0 }
        return hasRootCategory || categories.isEmpty
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private func movieFromCache(matching item: VodItem) -> VodItem? {
        movies.first { $0.id == item.id && $0.vodPic?.nilIfBlank != nil }
    }
}
