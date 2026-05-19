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

    private let loadLibraryPage: LoadLibraryPageUseCase
    private let loadMovieDetail: LoadMovieDetailUseCase

    init(
        loadLibraryPage: LoadLibraryPageUseCase,
        loadMovieDetail: LoadMovieDetailUseCase
    ) {
        self.loadLibraryPage = loadLibraryPage
        self.loadMovieDetail = loadMovieDetail
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
            detailMovie = try await loadMovieDetail.execute(
                item: item,
                cachedItem: movieFromCache(matching: item)
            )
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
            let libraryPage = try await loadLibraryPage.execute(
                selectedCategory: selectedCategory,
                categories: categories,
                keyword: searchText,
                page: targetPage
            )

            if shouldUseRemoteCategories(libraryPage.remoteCategories),
               let remoteCategories = libraryPage.remoteCategories {
                categories = remoteCategories
            }

            page = libraryPage.page
            pageCount = libraryPage.pageCount
            total = libraryPage.total

            if reset {
                movies = libraryPage.items
                if let first = libraryPage.items.first {
                    await selectMovie(first)
                } else {
                    selectedMovie = nil
                    detailMovie = nil
                }
            } else {
                movies.append(contentsOf: libraryPage.items)
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
