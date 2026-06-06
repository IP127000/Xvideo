import SwiftUI

@main
struct XVideoApp: App {
    @StateObject private var library = AppEnvironment.makeLibraryViewModel()
    @StateObject private var downloads = DownloadManager()
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var watchProgress = WatchProgressStore()
    @StateObject private var preferences = UserPreferencesStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .environmentObject(downloads)
                .environmentObject(favorites)
                .environmentObject(watchProgress)
                .environmentObject(preferences)
                .frame(minWidth: 1280, minHeight: 780)
                .task {
                    await library.loadInitialData()
                    library.startPeriodicRefresh()
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("刷新") {
                    Task { await library.refresh() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}
