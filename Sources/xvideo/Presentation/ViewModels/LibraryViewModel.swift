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
    @Published var isRefreshingPreviewCache = false
    @Published var isLoadingDetail = false
    @Published var errorMessage: String?
    @Published var page = 1
    @Published var pageCount = 1
    @Published var total = 0
    @Published var filterCategory: VodCategory?
    @Published var filterYear = ""
    @Published var filterArea = ""
    @Published private var posterFileURLs: [URL: URL] = [:]

    private enum ContentMode {
        case preview
        case onlineCategory
        case search
    }

    private struct PreviewPageResult {
        let categoryID: Int?
        let cachedPage: CachedLibraryPage
    }

    private let loadLibraryPage: LoadLibraryPageUseCase
    private let loadMovieDetail: LoadMovieDetailUseCase
    private let libraryCacheStore: LibraryPageCacheStore
    private let posterCacheStore: PosterCacheStore
    private let cacheLifetime: TimeInterval = 60 * 60
    private let previewItemLimit = 10
    private let previewFetchConcurrency = 8
    private static let periodicRefreshIntervalNanoseconds: UInt64 = 60 * 60 * 1_000_000_000

    private var contentMode: ContentMode = .preview
    private var detailCache: [Int: VodItem] = [:]
    private var previewCache: [LibraryCacheKey: CachedLibraryPage] = [:]
    private var onlinePageCache: [LibraryCacheKey: LibraryPage] = [:]
    private var detailRequestID = UUID()
    private var listRequestID = UUID()
    private var periodicRefreshTask: Task<Void, Never>?
    private var previewRefreshTask: Task<Void, Never>?
    private var isRebuildingPreviewCache = false

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
        previewRefreshTask?.cancel()
    }

    var rootCategories: [VodCategory] {
        categories
            .filter { $0.typePid == 0 && isDisplayCategory($0) }
            .sorted { $0.typeId < $1.typeId }
    }

    var childCategories: [VodCategory] {
        guard let selectedCategory else { return [] }

        let parentId = selectedCategory.typePid == 0
            ? selectedCategory.typeId
            : selectedCategory.typePid

        return categories
            .filter { $0.typePid == parentId && isDisplayCategory($0) }
            .sorted { $0.typeId < $1.typeId }
    }

    var currentTitle: String {
        if contentMode == .search || !normalizedSearchText.isEmpty {
            return "搜索结果"
        }
        if let selectedCategory {
            return selectedCategory.typeName
        }
        return "最新更新"
    }

    var isShowingPreview: Bool {
        contentMode == .preview
    }

    var canRequestMoreForCurrentSelection: Bool {
        normalizedSearchText.isEmpty
    }

    var isShowingFilterSearch: Bool {
        contentMode == .onlineCategory
    }

    var filterCategories: [VodCategory] {
        guard let selectedCategory else { return rootCategories }

        let parent: VodCategory
        if selectedCategory.typePid == 0 {
            parent = selectedCategory
        } else if let root = categories.first(where: { $0.typeId == selectedCategory.typePid }) {
            parent = root
        } else {
            parent = selectedCategory
        }

        return [parent] + visibleChildren(for: parent)
    }

    var filterYears: [String] {
        ["", "2026", "2025", "2024", "2023", "2022", "2021", "2020", "2019", "2018"]
    }

    var filterAreas: [String] {
        ["", "中国大陆", "香港", "台湾", "日本", "韩国", "美国", "英国", "泰国", "其他"]
    }

    func cachedPosterFileURL(for url: URL?) -> URL? {
        guard let url else { return nil }
        return posterFileURLs[url]
    }

    func cachePosters(for items: [VodItem]) async {
        guard !items.isEmpty else { return }

        let files = await posterCacheStore.cachePosters(for: items)
        guard !files.isEmpty else { return }
        posterFileURLs.merge(files) { current, _ in current }
    }

    func loadInitialData() async {
        guard movies.isEmpty else { return }

        await restoreLocalCache()
        await loadCategoriesIfNeeded()

        if let cachedPage = previewPage(for: selectedCategory) {
            await applyLibraryPage(cachedPage.page, reset: true)
        } else {
            isLoadingList = true
            await fetchAndStorePreview(category: selectedCategory, applyIfVisible: true)
            isLoadingList = false
        }

        if shouldRefreshPreviewCache {
            schedulePreviewCacheRefresh(applyVisiblePage: false)
        }
    }

    func refresh() async {
        if contentMode == .search || !normalizedSearchText.isEmpty {
            await search()
            return
        }

        if contentMode == .onlineCategory {
            await loadOnlineList(reset: true)
            return
        }

        await rebuildPreviewCache(applyVisiblePage: true)
    }

    func startPeriodicRefresh() {
        guard periodicRefreshTask == nil else { return }

        periodicRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.periodicRefreshIntervalNanoseconds)
                guard !Task.isCancelled else { return }
                await self?.rebuildPreviewCache(applyVisiblePage: false)
            }
        }
    }

    func selectCategory(_ category: VodCategory?) async {
        selectedCategory = category
        searchText = ""
        filterCategory = category
        filterYear = ""
        filterArea = ""
        contentMode = .preview
        errorMessage = nil
        listRequestID = UUID()

        if let cachedPage = previewPage(for: category) {
            await applyLibraryPage(cachedPage.page, reset: true)
            return
        }

        clearVisibleList()
        isLoadingList = true
        await fetchAndStorePreview(category: category, applyIfVisible: true)
        isLoadingList = false
    }

    func openFilterSearch(for category: VodCategory?) async {
        selectedCategory = category
        filterCategory = category
        filterYear = ""
        filterArea = ""
        searchText = ""
        contentMode = .onlineCategory
        await loadOnlineList(reset: true)
    }

    func updateFilterCategory(_ category: VodCategory?) async {
        filterCategory = category
        selectedCategory = category
        contentMode = .onlineCategory
        await loadOnlineList(reset: true)
    }

    func updateFilterYear(_ year: String) async {
        filterYear = year
        contentMode = .onlineCategory
        await loadOnlineList(reset: true)
    }

    func updateFilterArea(_ area: String) async {
        filterArea = area
        contentMode = .onlineCategory
        await loadOnlineList(reset: true)
    }

    func resetFilters() async {
        filterYear = ""
        filterArea = ""
        contentMode = .onlineCategory
        await loadOnlineList(reset: true)
    }

    func showFavorites(_ favorites: [FavoriteMovie]) async {
        searchText = ""
        selectedCategory = nil
        filterCategory = nil
        filterYear = ""
        filterArea = ""
        contentMode = .preview
        errorMessage = nil

        if let first = favorites.first {
            await selectMovie(first.item)
        } else {
            detailRequestID = UUID()
            selectedMovie = nil
            detailMovie = nil
        }
    }

    func search() async {
        selectedCategory = nil
        filterCategory = nil
        filterYear = ""
        filterArea = ""
        contentMode = .search
        await loadOnlineList(reset: true)
    }

    func loadNextPageIfNeeded(current item: VodItem) async {
        guard contentMode != .preview,
              item.id == movies.last?.id,
              page < pageCount,
              !isLoadingList else {
            return
        }

        await loadOnlineList(reset: false)
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

    private func loadOnlineList(reset: Bool) async {
        let targetPage = reset ? 1 : page + 1
        let categorySnapshot = contentMode == .onlineCategory ? filterCategory : selectedCategory
        let keywordSnapshot = normalizedSearchText
        let yearSnapshot = contentMode == .onlineCategory ? filterYear : ""
        let areaSnapshot = contentMode == .onlineCategory ? filterArea : ""
        let requestID = UUID()
        listRequestID = requestID

        isLoadingList = true
        errorMessage = nil

        if reset {
            clearVisibleList()
        }

        do {
            let loadedPage = try await loadLibraryPage.execute(
                selectedCategory: categorySnapshot,
                categories: categories,
                keyword: keywordSnapshot,
                page: targetPage,
                year: yearSnapshot,
                area: areaSnapshot
            )

            guard listRequestID == requestID else { return }

            let key = cacheKey(category: categorySnapshot, keyword: keywordSnapshot, page: targetPage)
            onlinePageCache[key] = loadedPage
            await applyLibraryPage(loadedPage, reset: reset)
            cachePostersInBackground(for: loadedPage.items)
        } catch {
            guard listRequestID == requestID else { return }
            guard !isCancellation(error) else {
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

    private func clearVisibleList() {
        detailRequestID = UUID()
        movies = []
        selectedMovie = nil
        detailMovie = nil
        page = 1
        pageCount = 1
        total = 0
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shouldRefreshPreviewCache: Bool {
        previewCache.isEmpty || isPreviewCacheExpired || hasMissingPreviewCache
    }

    private var isPreviewCacheExpired: Bool {
        guard let oldestCacheDate = previewCache.values.map(\.loadedAt).min() else {
            return true
        }

        return Date().timeIntervalSince(oldestCacheDate) >= cacheLifetime
    }

    private var hasMissingPreviewCache: Bool {
        requiredPreviewTargets().contains { category in
            previewCache[cacheKey(category: category, keyword: "", page: 1)] == nil
        }
    }

    private func restoreLocalCache() async {
        let snapshot = await libraryCacheStore.load()
        if !snapshot.categories.isEmpty {
            categories = snapshot.categories
        }

        previewCache = snapshot.pages.reduce(into: [LibraryCacheKey: CachedLibraryPage]()) { result, entry in
            let key = entry.key
            guard key.keyword.isEmpty, key.page == 1 else { return }

            let page = entry.value.page
            let previewPage = LibraryPage(
                items: Array(page.items.prefix(previewItemLimit)),
                page: 1,
                pageCount: page.pageCount,
                total: page.total,
                remoteCategories: page.remoteCategories
            )
            result[key] = CachedLibraryPage(
                page: previewPage,
                loadedAt: entry.value.loadedAt,
                isComplete: false
            )
        }
        posterFileURLs = await posterCacheStore.cachedFileURLs(for: cachedPosterURLs)
    }

    private func loadCategoriesIfNeeded() async {
        guard categories.isEmpty else { return }

        do {
            let loadedCategories = try await loadLibraryPage.fetchCategories()
            if !loadedCategories.isEmpty {
                categories = loadedCategories
            }
        } catch {
            guard !isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func schedulePreviewCacheRefresh(applyVisiblePage: Bool) {
        guard previewRefreshTask == nil else { return }

        previewRefreshTask = Task { [weak self] in
            await self?.rebuildPreviewCache(applyVisiblePage: applyVisiblePage)
            await MainActor.run {
                self?.previewRefreshTask = nil
            }
        }
    }

    private func rebuildPreviewCache(applyVisiblePage: Bool) async {
        guard !isRebuildingPreviewCache else { return }

        isRebuildingPreviewCache = true
        isRefreshingPreviewCache = true
        defer {
            isRebuildingPreviewCache = false
            isRefreshingPreviewCache = false
        }

        await loadCategoriesIfNeeded()

        let targets = networkPreviewTargets()
        guard !targets.isEmpty else { return }

        var remainingTargets = targets
        for attempt in 1...6 {
            await fetchPreviewBatch(remainingTargets, applyVisiblePage: applyVisiblePage)
            remainingTargets = missingPreviewTargets(from: targets)

            guard !remainingTargets.isEmpty, attempt < 6 else {
                break
            }

            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }

        persistPreviewCache()
    }

    private func fetchPreviewBatch(_ targets: [VodCategory?], applyVisiblePage: Bool) async {
        guard !targets.isEmpty else { return }

        var nextIndex = 0
        var completedCount = 0
        let categoriesSnapshot = categories
        let loadLibraryPage = loadLibraryPage
        let previewItemLimit = previewItemLimit

        await withTaskGroup(of: PreviewPageResult?.self) { group in
            func submitNext() {
                guard nextIndex < targets.count else { return }
                let category = targets[nextIndex]
                nextIndex += 1

                group.addTask {
                    do {
                        let page = try await loadLibraryPage.fetchPreview(
                            selectedCategory: category,
                            categories: categoriesSnapshot,
                            page: 1
                        )
                        let previewPage = LibraryPage(
                            items: Array(page.items.prefix(previewItemLimit)),
                            page: 1,
                            pageCount: page.pageCount,
                            total: page.total,
                            remoteCategories: page.remoteCategories
                        )
                        return PreviewPageResult(
                            categoryID: category?.typeId,
                            cachedPage: CachedLibraryPage(
                                page: previewPage,
                                loadedAt: Date(),
                                isComplete: false
                            )
                        )
                    } catch {
                        return nil
                    }
                }
            }

            for _ in 0..<min(previewFetchConcurrency, targets.count) {
                submitNext()
            }

            while let result = await group.next() {
                if let result {
                    await applyPreviewResult(result, applyVisiblePage: applyVisiblePage)
                    buildRootPreviewPagesFromChildren()
                    await applyVisibleRootPreviewIfNeeded(applyVisiblePage: applyVisiblePage)
                    completedCount += 1

                    if completedCount == 1 || completedCount.isMultiple(of: 6) {
                        persistPreviewCache()
                    }
                }
                submitNext()
            }
        }
    }

    private func fetchAndStorePreview(category: VodCategory?, applyIfVisible: Bool) async {
        do {
            let page = try await loadLibraryPage.fetchPreview(
                selectedCategory: category,
                categories: categories,
                page: 1
            )
            let previewPage = LibraryPage(
                items: Array(page.items.prefix(previewItemLimit)),
                page: 1,
                pageCount: page.pageCount,
                total: page.total,
                remoteCategories: page.remoteCategories
            )
            let result = PreviewPageResult(
                categoryID: category?.typeId,
                cachedPage: CachedLibraryPage(
                    page: previewPage,
                    loadedAt: Date(),
                    isComplete: false
                )
            )
            await applyPreviewResult(result, applyVisiblePage: applyIfVisible)
            buildRootPreviewPagesFromChildren()
            await applyVisibleRootPreviewIfNeeded(applyVisiblePage: applyIfVisible)
            persistPreviewCache()
        } catch {
            guard !isCancellation(error) else { return }
            if applyIfVisible {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func applyPreviewResult(_ result: PreviewPageResult, applyVisiblePage: Bool) async {
        let key = LibraryCacheKey(categoryID: result.categoryID, keyword: "", page: 1)
        previewCache[key] = result.cachedPage

        if shouldUseRemoteCategories(result.cachedPage.page.remoteCategories),
           let remoteCategories = result.cachedPage.page.remoteCategories {
            categories = remoteCategories
        }

        cachePostersInBackground(for: result.cachedPage.page.items)

        guard applyVisiblePage,
              contentMode == .preview,
              normalizedSearchText.isEmpty,
              selectedCategory?.typeId == result.categoryID else {
            return
        }

        await applyLibraryPage(result.cachedPage.page, reset: true)
    }

    private func requiredPreviewTargets() -> [VodCategory?] {
        [nil] + displayCategories().map { Optional($0) }
    }

    private func networkPreviewTargets() -> [VodCategory?] {
        let targets = displayCategories().filter { category in
            category.typePid != 0 || visibleChildren(for: category).isEmpty
        }

        return [nil] + targets.map { Optional($0) }
    }

    private func displayCategories() -> [VodCategory] {
        let visibleRootIDs = Set(rootCategories.map(\.typeId))
        return categories
            .filter { category in
                isDisplayCategory(category) &&
                    (category.typePid == 0 || visibleRootIDs.contains(category.typePid))
            }
            .sorted { lhs, rhs in
                if lhs.typePid != rhs.typePid {
                    return lhs.typePid < rhs.typePid
                }
                return lhs.typeId < rhs.typeId
            }
    }

    private func visibleChildren(for category: VodCategory) -> [VodCategory] {
        categories
            .filter { $0.typePid == category.typeId && isDisplayCategory($0) }
            .sorted { $0.typeId < $1.typeId }
    }

    private func buildRootPreviewPagesFromChildren() {
        for rootCategory in rootCategories {
            let children = visibleChildren(for: rootCategory)
            guard !children.isEmpty else { continue }

            let childPages = children.compactMap { previewPage(for: $0) }
            guard !childPages.isEmpty else { continue }

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
                items: Array(items.prefix(previewItemLimit)),
                page: 1,
                pageCount: childPages.map(\.page.pageCount).max() ?? 1,
                total: childPages.map(\.page.total).reduce(0, +),
                remoteCategories: categories
            )
            previewCache[cacheKey(category: rootCategory, keyword: "", page: 1)] = CachedLibraryPage(
                page: page,
                loadedAt: childPages.map(\.loadedAt).min() ?? Date(),
                isComplete: false
            )
        }
    }

    private func applyVisibleRootPreviewIfNeeded(applyVisiblePage: Bool) async {
        guard applyVisiblePage,
              contentMode == .preview,
              normalizedSearchText.isEmpty,
              let selectedCategory,
              selectedCategory.typePid == 0,
              let cachedPage = previewPage(for: selectedCategory) else {
            return
        }

        await applyLibraryPage(cachedPage.page, reset: true)
    }

    private func missingPreviewTargets(from targets: [VodCategory?]) -> [VodCategory?] {
        targets.filter { category in
            previewPage(for: category) == nil
        }
    }

    private func previewPage(for category: VodCategory?) -> CachedLibraryPage? {
        previewCache[cacheKey(category: category, keyword: "", page: 1)]
    }

    private func cacheKey(category: VodCategory?, keyword: String, page: Int) -> LibraryCacheKey {
        LibraryCacheKey(
            categoryID: category?.typeId,
            keyword: keyword.trimmingCharacters(in: .whitespacesAndNewlines),
            page: page
        )
    }

    private func persistPreviewCache() {
        let categoriesSnapshot = categories
        let pagesSnapshot = previewCache
        Task {
            await libraryCacheStore.save(categories: categoriesSnapshot, pages: pagesSnapshot)
        }
    }

    private func cachePostersInBackground(for items: [VodItem]) {
        guard !items.isEmpty else { return }

        let posterCacheStore = posterCacheStore
        Task { [weak self] in
            let files = await posterCacheStore.cachePosters(for: items)
            guard !files.isEmpty else { return }

            await MainActor.run {
                self?.posterFileURLs.merge(files) { current, _ in current }
            }
        }
    }

    private var cachedItems: [VodItem] {
        previewCache.values.flatMap(\.page.items) +
            onlinePageCache.values.flatMap(\.items) +
            Array(detailCache.values)
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

    private func isDisplayCategory(_ category: VodCategory) -> Bool {
        category.typeName != "演员" && category.typeName != "新闻资讯"
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
