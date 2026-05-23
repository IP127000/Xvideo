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
    @Published private var posterFileURLs: [URL: URL] = [:]

    private let loadLibraryPage: LoadLibraryPageUseCase
    private let loadMovieDetail: LoadMovieDetailUseCase
    private let libraryCacheStore: LibraryPageCacheStore
    private let posterCacheStore: PosterCacheStore
    private let cacheLifetime: TimeInterval = 60 * 60
    private let aggregateDisplayLimit = 60
    private let previewItemLimit = 10
    private static let periodicRefreshIntervalNanoseconds: UInt64 = 60 * 60 * 1_000_000_000
    private var detailCache: [Int: VodItem] = [:]
    private var listCache: [LibraryCacheKey: CachedLibraryPage] = [:]
    private var detailRequestID = UUID()
    private var listRequestID = UUID()
    private var periodicRefreshTask: Task<Void, Never>?
    private var cacheRefreshTask: Task<Void, Never>?
    private var isRebuildingLocalCache = false

    init(
        loadLibraryPage: LoadLibraryPageUseCase,
        loadMovieDetail: LoadMovieDetailUseCase,
        libraryCacheStore: LibraryPageCacheStore,
        posterCacheStore: PosterCacheStore
    ) {
        self.loadLibraryPage = loadLibraryPage
        self.loadMovieDetail = loadMovieDetail
        self.libraryCacheStore = libraryCacheStore
        self.posterCacheStore = posterCacheStore
    }

    deinit {
        periodicRefreshTask?.cancel()
        cacheRefreshTask?.cancel()
    }

    var rootCategories: [VodCategory] {
        categories.filter { $0.typePid == 0 && $0.typeName != "演员" && $0.typeName != "新闻资讯" }
    }

    var childCategories: [VodCategory] {
        guard let selectedCategory else { return [] }

        let parentId = selectedCategory.typePid == 0
            ? selectedCategory.typeId
            : selectedCategory.typePid

        return categories
            .filter { $0.typePid == parentId }
            .sorted { $0.typeId < $1.typeId }
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

    func cachedPosterFileURL(for url: URL?) -> URL? {
        guard let url else { return nil }
        return posterFileURLs[url]
    }

    func loadInitialData() async {
        guard movies.isEmpty else { return }
        await restoreLocalCache()
        let shouldRefreshLocalCache = listCache.isEmpty || isLocalCacheExpired

        if let cachedPage = cachedPage(
            category: selectedCategory,
            keyword: normalizedSearchText,
            page: 1
        ) {
            await applyLibraryPage(cachedPage.page, reset: true)
        } else {
            await loadList(reset: true, allowRemoteFetch: true, requireCompleteCache: false, reportErrors: false)
        }

        if shouldRefreshLocalCache {
            scheduleLocalCacheRefresh(applyVisiblePage: false)
        }
    }

    func refresh() async {
        if normalizedSearchText.isEmpty {
            await rebuildLocalCache(applyVisiblePage: true)
        } else {
            await loadList(reset: true, allowRemoteFetch: true, requireCompleteCache: true, reportErrors: true)
        }
    }

    func startPeriodicRefresh() {
        guard periodicRefreshTask == nil else { return }

        periodicRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.periodicRefreshIntervalNanoseconds)
                guard !Task.isCancelled else { return }
                await self?.rebuildLocalCache(applyVisiblePage: false)
            }
        }
    }

    func selectCategory(_ category: VodCategory?) async {
        selectedCategory = category
        searchText = ""
        await loadList(reset: true, allowRemoteFetch: true, requireCompleteCache: true, reportErrors: false)
    }

    func search() async {
        selectedCategory = nil
        await loadList(reset: true, allowRemoteFetch: true, requireCompleteCache: true, reportErrors: true)
    }

    func loadNextPageIfNeeded(current item: VodItem) async {
        guard item.id == movies.last?.id, page < pageCount, !isLoadingList else { return }
        await loadList(reset: false, allowRemoteFetch: true, requireCompleteCache: true, reportErrors: true)
    }

    func selectMovie(_ item: VodItem) async {
        let cachedListItem = movieFromCache(matching: item) ?? item
        selectedMovie = cachedListItem
        detailMovie = nil
        isLoadingDetail = true
        errorMessage = nil

        let requestID = UUID()
        detailRequestID = requestID

        if let cachedDetail = detailCache[item.id] {
            detailMovie = cachedDetail
            isLoadingDetail = false
            return
        }

        do {
            let loadedDetail = try await loadMovieDetail.execute(
                item: item,
                cachedItem: cachedListItem
            )
            guard detailRequestID == requestID else { return }
            detailCache[item.id] = loadedDetail
            detailMovie = loadedDetail
        } catch {
            guard detailRequestID == requestID else { return }
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

    private func loadList(reset: Bool, allowRemoteFetch: Bool, requireCompleteCache: Bool, reportErrors: Bool) async {
        let targetPage = reset ? 1 : page + 1
        let categorySnapshot = selectedCategory
        let keywordSnapshot = normalizedSearchText
        let key = cacheKey(category: categorySnapshot, keyword: keywordSnapshot, page: targetPage)
        let requestID = UUID()
        listRequestID = requestID

        isLoadingList = true
        errorMessage = nil

        let existingCachedPage = cachedPage(category: categorySnapshot, keyword: keywordSnapshot, page: targetPage)
        if let cachedPage = existingCachedPage {
            await applyLibraryPage(cachedPage.page, reset: reset)

            if !requireCompleteCache || cachedPage.isComplete {
                isLoadingList = false
                return
            }
        }

        if reset && existingCachedPage == nil {
            detailRequestID = UUID()
            movies = []
            selectedMovie = nil
            detailMovie = nil
        }

        guard allowRemoteFetch else {
            errorMessage = "正在准备本地缓存，请稍后再试。"
            isLoadingList = false
            scheduleLocalCacheRefresh(applyVisiblePage: true)
            return
        }

        do {
            let loadedPage = try await loadLibraryPage.execute(
                selectedCategory: categorySnapshot,
                categories: categories,
                keyword: keywordSnapshot,
                page: targetPage
            )
            let libraryPage = await prepareDisplayPage(loadedPage, limit: nil)

            guard listRequestID == requestID else { return }
            listCache[key] = CachedLibraryPage(page: libraryPage, loadedAt: Date(), isComplete: true)
            await applyLibraryPage(libraryPage, reset: reset)
            persistLocalCache()
        } catch {
            guard listRequestID == requestID else { return }
            guard !isCancellation(error) else {
                isLoadingList = false
                return
            }
            if !reportErrors || (existingCachedPage != nil && keywordSnapshot.isEmpty) {
                isLoadingList = false
                return
            }
            errorMessage = error.localizedDescription
        }

        isLoadingList = false
    }

    private func applyLibraryPage(_ libraryPage: LibraryPage, reset: Bool) async {
        if shouldUseRemoteCategories(libraryPage.remoteCategories),
           let remoteCategories = libraryPage.remoteCategories {
            categories = remoteCategories
        }

        page = libraryPage.page
        pageCount = libraryPage.pageCount
        total = libraryPage.total

        if reset {
            movies = libraryPage.items
            isLoadingList = false
            if let first = libraryPage.items.first {
                await selectMovie(first)
            } else {
                selectedMovie = nil
                detailMovie = nil
            }
        } else {
            movies.append(contentsOf: libraryPage.items)
        }
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isLocalCacheExpired: Bool {
        guard let oldestCacheDate = listCache.values.map(\.loadedAt).min() else {
            return true
        }

        return Date().timeIntervalSince(oldestCacheDate) >= cacheLifetime
    }

    private var hasMissingDisplayCache: Bool {
        cachedItems.contains { item in
            item.vodPlayURL?.nilIfBlank == nil ||
            item.vodContent?.nilIfBlank == nil ||
            missingCachedPoster(for: item)
        }
    }

    private func missingCachedPoster(for item: VodItem) -> Bool {
        guard let posterURL = item.posterURL else { return false }
        return posterFileURLs[posterURL] == nil
    }

    private func restoreLocalCache() async {
        let snapshot = await libraryCacheStore.load()
        if !snapshot.categories.isEmpty {
            categories = snapshot.categories
        }
        listCache = snapshot.pages
        posterFileURLs = await posterCacheStore.cachedFileURLs(for: cachedPosterURLs)
    }

    private func scheduleLocalCacheRefresh(applyVisiblePage: Bool) {
        guard cacheRefreshTask == nil else { return }

        cacheRefreshTask = Task { [weak self] in
            await self?.rebuildLocalCache(applyVisiblePage: applyVisiblePage)
            await MainActor.run {
                self?.cacheRefreshTask = nil
            }
        }
    }

    private func rebuildLocalCache(applyVisiblePage: Bool) async {
        guard !isRebuildingLocalCache else { return }

        isRebuildingLocalCache = true
        defer { isRebuildingLocalCache = false }

        let visibleCategory = selectedCategory
        let visibleKeyword = normalizedSearchText

        do {
            let loadedLatestPage = try await loadLibraryPage.execute(
                selectedCategory: nil,
                categories: categories,
                keyword: "",
                page: 1
            )
            let latestPage = await prepareDisplayPage(loadedLatestPage, limit: previewItemLimit)

            var updatedCache = listCache
            updatedCache[cacheKey(category: nil, keyword: "", page: 1)] = CachedLibraryPage(
                page: latestPage,
                loadedAt: Date(),
                isComplete: false
            )

            if shouldUseRemoteCategories(latestPage.remoteCategories),
               let remoteCategories = latestPage.remoteCategories {
                categories = remoteCategories
            }
            listCache = updatedCache
            persistLocalCache()

            if applyVisiblePage,
               visibleCategory == nil,
               visibleKeyword.isEmpty,
               selectedCategory == nil,
               normalizedSearchText.isEmpty {
                listCache = updatedCache
                await applyLibraryPage(latestPage, reset: true)
            }

            let categoriesToPrime = categoriesForLocalPreload()
            await preloadPreviewCategoryPages(categoriesToPrime)
            buildParentCategoryPages()
            await refreshCompleteCachedPages()
            buildParentCategoryPages()
            persistLocalCache()

            if applyVisiblePage,
               selectedCategory == visibleCategory,
               normalizedSearchText == visibleKeyword,
               let cachedPage = cachedPage(category: visibleCategory, keyword: visibleKeyword, page: 1) {
                await applyLibraryPage(cachedPage.page, reset: true)
            }
        } catch {
            guard !isCancellation(error) else { return }
            if listCache.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func preloadPreviewCategoryPages(_ categoriesToPrime: [VodCategory]) async {
        await withTaskGroup(of: CategoryPageResult?.self) { group in
            for category in categoriesToPrime {
                group.addTask { [loadLibraryPage, categories, previewItemLimit] in
                    do {
                        let page = try await loadLibraryPage.execute(
                            selectedCategory: category,
                            categories: categories,
                            keyword: "",
                            page: 1
                        )
                        let previewPage = LibraryPage(
                            items: Array(page.items.prefix(previewItemLimit)),
                            page: page.page,
                            pageCount: page.pageCount,
                            total: page.total,
                            remoteCategories: page.remoteCategories
                        )
                        let key = LibraryCacheKey(categoryID: category.typeId, keyword: "", page: 1)
                        return CategoryPageResult(
                            key: key,
                            cachedPage: CachedLibraryPage(page: previewPage, loadedAt: Date(), isComplete: false)
                        )
                    } catch {
                        return nil
                    }
                }
            }

            var completedCount = 0
            for await result in group {
                guard let result else { continue }
                listCache[result.key] = result.cachedPage
                await cachePosters(for: result.cachedPage.page.items)
                if normalizedSearchText.isEmpty,
                   selectedCategory?.typeId == result.key.categoryID,
                   result.key.page == 1 {
                    await applyLibraryPage(result.cachedPage.page, reset: true)
                }
                completedCount += 1

                if completedCount == 1 || completedCount.isMultiple(of: 6) {
                    buildParentCategoryPages()
                    persistLocalCache()
                }
            }
        }
    }

    private struct CategoryPageResult {
        let key: LibraryCacheKey
        let cachedPage: CachedLibraryPage
    }

    private func fetchCategoryPages(
        _ categoriesToPrime: [VodCategory],
        limit: Int?,
        isComplete: Bool
    ) async -> [CategoryPageResult] {
        let rawResults = await withTaskGroup(of: CategoryPageResult?.self) { group in
            for category in categoriesToPrime {
                group.addTask { [loadLibraryPage, categories] in
                    do {
                        let page = try await loadLibraryPage.execute(
                            selectedCategory: category,
                            categories: categories,
                            keyword: "",
                            page: 1
                        )
                        let key = LibraryCacheKey(categoryID: category.typeId, keyword: "", page: 1)
                        return CategoryPageResult(
                            key: key,
                            cachedPage: CachedLibraryPage(page: page, loadedAt: Date(), isComplete: false)
                        )
                    } catch {
                        return nil
                    }
                }
            }

            var results: [CategoryPageResult] = []
            for await result in group {
                if let result {
                    results.append(result)
                }
            }
            return results
        }

        var preparedResults: [CategoryPageResult] = []
        for result in rawResults {
            let preparedPage = await prepareDisplayPage(result.cachedPage.page, limit: limit)
            preparedResults.append(CategoryPageResult(
                key: result.key,
                cachedPage: CachedLibraryPage(
                    page: preparedPage,
                    loadedAt: result.cachedPage.loadedAt,
                    isComplete: isComplete
                )
            ))
        }
        return preparedResults
    }

    private func categoriesForLocalPreload() -> [VodCategory] {
        let parentIDs = Set(categories.map(\.typePid))
        return categories
            .filter { category in
                category.typeName != "演员" &&
                category.typeName != "新闻资讯" &&
                (category.typePid != 0 || !parentIDs.contains(category.typeId))
            }
            .sorted { $0.typeId < $1.typeId }
    }

    private func cachedPage(category: VodCategory?, keyword: String, page: Int) -> CachedLibraryPage? {
        let key = cacheKey(category: category, keyword: keyword, page: page)
        if let cachedPage = listCache[key] {
            return cachedPage
        }

        guard keyword.isEmpty,
              page == 1,
              let category,
              category.typePid == 0 else {
            return nil
        }

        return makeParentCategoryPage(for: category)
    }

    private func buildParentCategoryPages() {
        for category in rootCategories {
            guard let parentPage = makeParentCategoryPage(for: category) else { continue }
            listCache[cacheKey(category: category, keyword: "", page: 1)] = parentPage
        }
    }

    private func makeParentCategoryPage(for category: VodCategory) -> CachedLibraryPage? {
        let childIDs = Set(categories.filter { $0.typePid == category.typeId }.map(\.typeId))
        guard !childIDs.isEmpty else { return nil }

        let childPages = listCache.compactMap { key, cachedPage -> CachedLibraryPage? in
            guard key.keyword.isEmpty, key.page == 1, let categoryID = key.categoryID, childIDs.contains(categoryID) else {
                return nil
            }
            return cachedPage
        }
        guard !childPages.isEmpty else { return nil }

        var seen = Set<Int>()
        let items = childPages
            .flatMap(\.page.items)
            .filter { item in
                guard !seen.contains(item.id) else { return false }
                seen.insert(item.id)
                return true
            }
            .sorted { ($0.vodTime ?? "") > ($1.vodTime ?? "") }

        let page = LibraryPage(
            items: Array(items.prefix(aggregateDisplayLimit)),
            page: 1,
            pageCount: childPages.map(\.page.pageCount).max() ?? 1,
            total: childPages.map(\.page.total).reduce(0, +),
            remoteCategories: categories
        )
        return CachedLibraryPage(
            page: page,
            loadedAt: childPages.map(\.loadedAt).min() ?? Date(),
            isComplete: childPages.allSatisfy(\.isComplete)
        )
    }

    private func cacheKey(category: VodCategory?, keyword: String, page: Int) -> LibraryCacheKey {
        LibraryCacheKey(
            categoryID: category?.typeId,
            keyword: keyword.trimmingCharacters(in: .whitespacesAndNewlines),
            page: page
        )
    }

    private func persistLocalCache() {
        let categoriesSnapshot = categories
        let pagesSnapshot = listCache
        Task {
            await libraryCacheStore.save(categories: categoriesSnapshot, pages: pagesSnapshot)
        }
    }

    private func prepareDisplayPage(_ libraryPage: LibraryPage, limit: Int?) async -> LibraryPage {
        let visibleItems = limit.map { Array(libraryPage.items.prefix($0)) } ?? libraryPage.items
        let items = await hydrateDetails(for: visibleItems)
        await cachePosters(for: items)

        return LibraryPage(
            items: items,
            page: libraryPage.page,
            pageCount: libraryPage.pageCount,
            total: libraryPage.total,
            remoteCategories: libraryPage.remoteCategories
        )
    }

    private func refreshCompleteCachedPages() async {
        let completeCategoryIDs = listCache.compactMap { key, cachedPage -> Int? in
            guard cachedPage.isComplete,
                  key.keyword.isEmpty,
                  key.page == 1,
                  let categoryID = key.categoryID else {
                return nil
            }
            return categoryID
        }

        let categoriesToRefresh = categories.filter { completeCategoryIDs.contains($0.typeId) }
        let refreshedPages = await fetchCategoryPages(categoriesToRefresh, limit: nil, isComplete: true)
        for result in refreshedPages {
            listCache[result.key] = result.cachedPage
        }
    }

    private func hydrateDetails(for items: [VodItem]) async -> [VodItem] {
        let cachedItems = items.map { item in
            detailCache[item.id] ?? movieFromCache(matching: item) ?? item
        }
        let itemsNeedingDetails = cachedItems.filter { item in
            item.vodPlayURL?.nilIfBlank == nil || item.vodContent?.nilIfBlank == nil
        }

        guard !itemsNeedingDetails.isEmpty else {
            return cachedItems
        }

        let details = await fetchDetails(for: itemsNeedingDetails)
        guard !details.isEmpty else {
            return cachedItems
        }

        for detail in details.values {
            detailCache[detail.id] = detail
        }

        return cachedItems.map { details[$0.id] ?? $0 }
    }

    private func fetchDetails(for items: [VodItem]) async -> [Int: VodItem] {
        var details: [Int: VodItem] = [:]

        for batchStart in stride(from: 0, to: items.count, by: 8) {
            let batch = Array(items[batchStart..<min(batchStart + 8, items.count)])
            let batchDetails = await withTaskGroup(of: VodItem?.self) { group in
                for item in batch {
                    group.addTask { [loadMovieDetail] in
                        try? await loadMovieDetail.execute(item: item, cachedItem: item)
                    }
                }

                var loadedItems: [VodItem] = []
                for await item in group {
                    if let item {
                        loadedItems.append(item)
                    }
                }
                return loadedItems
            }

            for detail in batchDetails {
                details[detail.id] = detail
            }
        }

        return details
    }

    private func cachePosters(for items: [VodItem]) async {
        let files = await posterCacheStore.cachePosters(for: items)
        guard !files.isEmpty else { return }
        posterFileURLs.merge(files) { current, _ in current }
    }

    private var cachedItems: [VodItem] {
        listCache.values.flatMap(\.page.items)
    }

    private var cachedPosterURLs: [URL] {
        cachedItems.compactMap(\.posterURL)
    }

    private func shouldUseRemoteCategories(_ remoteCategories: [VodCategory]?) -> Bool {
        guard let remoteCategories, !remoteCategories.isEmpty else {
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
        if let currentItem = movies.first(where: { $0.id == item.id && $0.vodPic?.nilIfBlank != nil }) {
            return currentItem
        }

        return cachedItems.first { $0.id == item.id && $0.vodPic?.nilIfBlank != nil }
    }
}
