import Foundation

enum AppEnvironment {
    @MainActor
    static func makeLibraryViewModel() -> LibraryViewModel {
        let httpClient = URLSessionHTTPClient(session: .shared)
        let sourceStore = VideoSourceStore()
        let sourceSnapshot = sourceStore.load()
        let apiClient = VodAPIClient(httpClient: httpClient)
        let repository = DefaultLibraryRepository(apiClient: apiClient, source: sourceSnapshot.activeSource)
        let loadLibraryPage = LoadLibraryPageUseCase(repository: repository)
        let loadMovieDetail = LoadMovieDetailUseCase(repository: repository)
        let libraryCacheStore = LibraryPageCacheStore()
        let posterCacheStore = PosterCacheStore()
        return LibraryViewModel(
            loadLibraryPage: loadLibraryPage,
            loadMovieDetail: loadMovieDetail,
            libraryCacheStore: libraryCacheStore,
            posterCacheStore: posterCacheStore,
            sourceStore: sourceStore,
            sourceSnapshot: sourceSnapshot,
            repository: repository
        )
    }
}
