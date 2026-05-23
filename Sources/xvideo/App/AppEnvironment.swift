import Foundation

enum AppEnvironment {
    @MainActor
    static func makeLibraryViewModel() -> LibraryViewModel {
        let httpClient = URLSessionHTTPClient(session: .shared)
        let apiClient = LzizyAPIClient(httpClient: httpClient)
        let repository = DefaultLibraryRepository(apiClient: apiClient)
        let loadLibraryPage = LoadLibraryPageUseCase(repository: repository)
        let loadMovieDetail = LoadMovieDetailUseCase(repository: repository)
        let libraryCacheStore = LibraryPageCacheStore()
        return LibraryViewModel(
            loadLibraryPage: loadLibraryPage,
            loadMovieDetail: loadMovieDetail,
            libraryCacheStore: libraryCacheStore
        )
    }
}
