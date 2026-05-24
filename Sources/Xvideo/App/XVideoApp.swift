import SwiftUI

@main
struct XVideoApp: App {
    @StateObject private var library = AppEnvironment.makeLibraryViewModel()
    @StateObject private var downloads = DownloadManager()
    @StateObject private var favorites = FavoritesStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .environmentObject(downloads)
                .environmentObject(favorites)
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
