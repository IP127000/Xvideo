import Foundation

private struct LibraryCacheKey: Hashable {
    let categoryID: Int?
    let keyword: String
    let page: Int
}

private struct CachedLibraryPage {
    let page: LibraryPage
    let loadedAt: Date
}

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

    private let loadLibraryPage: LoadLibraryPageUseCase
    private let loadMovieDetail: LoadMovieDetailUseCase
    private let cacheLifetime: TimeInterval = 60 * 60
    private static let periodicRefreshIntervalNanoseconds: UInt64 = 60 * 60 * 1_000_000_000
    private var detailCache: [Int: VodItem] = [:]
    private var listCache: [LibraryCacheKey: CachedLibraryPage] = [:]
    private var detailRequestID = UUID()
    private var listRequestID = UUID()
    private var periodicRefreshTask: Task<Void, Never>?

    init(
        loadLibraryPage: LoadLibraryPageUseCase,
        loadMovieDetail: LoadMovieDetailUseCase
    ) {
        self.loadLibraryPage = loadLibraryPage
        self.loadMovieDetail = loadMovieDetail
    }

    deinit {
        periodicRefreshTask?.cancel()
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

    func loadInitialData() async {
        guard movies.isEmpty else { return }
        await loadList(reset: true, forceRefresh: true)
    }

    func refresh() async {
        await loadList(reset: true, forceRefresh: true)
    }

    func startPeriodicRefresh() {
        guard periodicRefreshTask == nil else { return }

        periodicRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.periodicRefreshIntervalNanoseconds)
                guard !Task.isCancelled else { return }
                await self?.refreshVisibleCacheInBackground()
            }
        }
    }

    func selectCategory(_ category: VodCategory?) async {
        selectedCategory = category
        searchText = ""
        await loadList(reset: true, forceRefresh: false)
    }

    func search() async {
        selectedCategory = nil
        await loadList(reset: true, forceRefresh: false)
    }

    func loadNextPageIfNeeded(current item: VodItem) async {
        guard item.id == movies.last?.id, page < pageCount, !isLoadingList else { return }
        await loadList(reset: false, forceRefresh: false)
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

    private func loadList(reset: Bool, forceRefresh: Bool) async {
        let targetPage = reset ? 1 : page + 1
        let categorySnapshot = selectedCategory
        let keywordSnapshot = normalizedSearchText
        let key = LibraryCacheKey(
            categoryID: categorySnapshot?.typeId,
            keyword: keywordSnapshot,
            page: targetPage
        )
        let requestID = UUID()
        listRequestID = requestID

        isLoadingList = true
        errorMessage = nil

        if !forceRefresh, let cachedPage = listCache[key], isFresh(cachedPage) {
            await applyLibraryPage(cachedPage.page, reset: reset)
            isLoadingList = false
            return
        }

        if reset {
            detailRequestID = UUID()
            if !forceRefresh, let cachedPage = listCache[key] {
                await applyLibraryPage(cachedPage.page, reset: true)
                isLoadingList = true
            } else {
                movies = []
                selectedMovie = nil
                detailMovie = nil
            }
        }

        do {
            let libraryPage = try await loadLibraryPage.execute(
                selectedCategory: categorySnapshot,
                categories: categories,
                keyword: keywordSnapshot,
                page: targetPage
            )

            guard listRequestID == requestID else { return }
            listCache[key] = CachedLibraryPage(page: libraryPage, loadedAt: Date())
            await applyLibraryPage(libraryPage, reset: reset)
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

    private func refreshVisibleCacheInBackground() async {
        guard !isLoadingList else { return }

        let categorySnapshot = selectedCategory
        let keywordSnapshot = normalizedSearchText
        let key = LibraryCacheKey(
            categoryID: categorySnapshot?.typeId,
            keyword: keywordSnapshot,
            page: 1
        )

        do {
            let libraryPage = try await loadLibraryPage.execute(
                selectedCategory: categorySnapshot,
                categories: categories,
                keyword: keywordSnapshot,
                page: 1
            )
            listCache[key] = CachedLibraryPage(page: libraryPage, loadedAt: Date())

            if shouldUseRemoteCategories(libraryPage.remoteCategories),
               let remoteCategories = libraryPage.remoteCategories {
                categories = remoteCategories
            }
        } catch {
            guard !isCancellation(error) else { return }
        }
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isFresh(_ cachedPage: CachedLibraryPage) -> Bool {
        Date().timeIntervalSince(cachedPage.loadedAt) < cacheLifetime
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
        movies.first { $0.id == item.id && $0.vodPic?.nilIfBlank != nil }
    }
}
