import SwiftUI

@main
struct XVideoApp: App {
    @StateObject private var library = AppEnvironment.makeLibraryViewModel()
    @StateObject private var downloads = DownloadManager()
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var watchProgress = WatchProgressStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .environmentObject(downloads)
                .environmentObject(favorites)
                .environmentObject(watchProgress)
                .task {
                    await library.loadInitialData()
                    library.startPeriodicRefresh()
                }
        }
    }
}
