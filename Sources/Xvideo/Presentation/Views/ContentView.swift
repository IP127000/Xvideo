import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: LibraryViewModel

    @State private var searchDraft = ""
    @State private var selectedSection: LibrarySection = .home
    @State private var selectedPlaybackSourceID: PlaybackSource.ID?
    @State private var selectedEpisode: Episode?
    @State private var route: ContentRoute = .browse

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            CinemaTheme.appBackground
                .ignoresSafeArea()

            HSplitView {
                CinematicSidebarView(
                    searchDraft: $searchDraft,
                    selectedSection: $selectedSection
                )
                .frame(minWidth: 230, idealWidth: 252, maxWidth: 300)

                ZStack {
                    MediaBrowserView(
                        searchDraft: $searchDraft,
                        selectedSection: $selectedSection,
                        openMovie: openMovie,
                        openFavorite: openFavorite,
                        playMovie: { route = .watch }
                    )
                    .opacity(route == .browse ? 1 : 0)
                    .allowsHitTesting(route == .browse)

                    if route == .watch {
                        MovieDetailView(
                            selectedPlaybackSourceID: $selectedPlaybackSourceID,
                            selectedEpisode: $selectedEpisode,
                            dismissToBrowser: { route = .browse }
                        )
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .frame(minWidth: 780)
            }
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .bottomTrailing) {
            DownloadShelfView()
                .padding(18)
        }
        .onChange(of: library.selectedMovie?.id) { _, _ in
            selectPreferredPlayback(for: library.selectedMovie)
        }
        .onChange(of: library.detailMovie?.id) { _, _ in
            selectPreferredPlayback(for: library.detailMovie ?? library.selectedMovie)
        }
        .onChange(of: library.searchText) { _, newValue in
            searchDraft = newValue
        }
        .onChange(of: selectedSection) { _, _ in
            route = .browse
        }
        .animation(.easeInOut(duration: 0.22), value: route)
    }

    private func selectPreferredPlayback(for movie: VodItem?) {
        guard let movie else {
            selectedPlaybackSourceID = nil
            selectedEpisode = nil
            return
        }

        let sources = SourceParser.parsePlaybackSources(from: movie)
        let preferredSource = sources.first { $0.name.localizedCaseInsensitiveContains("M3U8") } ?? sources.first
        selectedPlaybackSourceID = preferredSource?.id
        selectedEpisode = preferredSource?.episodes.first
    }

    private func openMovie(_ movie: VodItem) {
        Task {
            await library.selectMovie(movie)
            route = .browse
        }
    }

    private func openFavorite(_ favorite: FavoriteMovie) {
        Task {
            await library.selectFavorite(favorite)
            route = .browse
        }
    }
}

enum LibrarySection: Hashable {
    case home
    case favorites
    case category(Int)
}

private enum ContentRoute {
    case browse
    case watch
}
