import Foundation

enum AppEnvironment {
    @MainActor
    static func makeLibraryViewModel() -> LibraryViewModel {
        let httpClient = URLSessionHTTPClient(session: .shared)
        let apiClient = LzizyAPIClient(httpClient: httpClient)
        let repository = DefaultLibraryRepository(apiClient: apiClient)
        return LibraryViewModel(repository: repository)
    }
}
