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
                .frame(minWidth: 1180, minHeight: 760)
                .task {
                    await library.loadInitialData()
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
