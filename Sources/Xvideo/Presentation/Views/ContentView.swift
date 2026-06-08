import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var watchProgress: WatchProgressStore

    @State private var searchDraft = ""
    @State private var selectedSection: LibrarySection = .home
    @State private var selectedPlaybackSourceID: PlaybackSource.ID?
    @State private var selectedEpisode: Episode?
    @State private var pendingWatchProgress: WatchProgressItem?
    @State private var route: ContentRoute = .browse

    var body: some View {
        #if os(iOS)
        PhoneContentView(
            searchDraft: $searchDraft,
            selectedPlaybackSourceID: $selectedPlaybackSourceID,
            selectedEpisode: $selectedEpisode,
            pendingWatchProgress: $pendingWatchProgress,
            openMovie: openMovie,
            openFavorite: openFavorite,
            openProgress: openProgress,
            playFavorite: playFavorite,
            playProgress: playProgress,
            playMovie: playMovie
        )
        .preferredColorScheme(.dark)
        .onChange(of: library.selectedMovie?.id) { _, _ in
            selectPreferredPlayback(for: library.selectedMovie)
        }
        .onChange(of: library.detailMovie?.id) { _, _ in
            selectPreferredPlayback(for: library.detailMovie ?? library.selectedMovie)
        }
        .onChange(of: library.searchText) { _, newValue in
            searchDraft = newValue
        }
        #else
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
                        openProgress: openProgress,
                        playFavorite: playFavorite,
                        playProgress: playProgress,
                        playMovie: playMovie
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
        #endif
    }

    private func selectPreferredPlayback(for movie: VodItem?) {
        guard let movie else {
            selectedPlaybackSourceID = nil
            selectedEpisode = nil
            return
        }

        if let pendingWatchProgress,
           pendingWatchProgress.matches(movie, sourceID: library.activeVideoSourceID) {
            selectPlayback(from: pendingWatchProgress, in: movie)
            return
        }

        if let progress = watchProgress.progress(for: movie, sourceID: library.activeVideoSourceID) {
            selectPlayback(from: progress, in: movie)
            return
        }

        let sources = SourceParser.parsePlaybackSources(from: movie)
        let preferredSource = sources.first { $0.name.localizedCaseInsensitiveContains("M3U8") } ?? sources.first
        selectedPlaybackSourceID = preferredSource?.id
        selectedEpisode = preferredSource?.episodes.first
    }

    private func selectPlayback(from progress: WatchProgressItem, in movie: VodItem) {
        let sources = SourceParser.parsePlaybackSources(from: movie)
        let source = sources.first { $0.id == progress.playbackSourceID }
            ?? sources.first { source in
                source.episodes.contains { $0.url == progress.episodeURL }
            }
            ?? sources.first
        let episode = source?.episodes.first { $0.url == progress.episodeURL }
            ?? source?.episodes.first

        selectedPlaybackSourceID = source?.id
        selectedEpisode = episode
        pendingWatchProgress = nil
    }

    private func openMovie(_ movie: VodItem) {
        Task {
            await library.selectMovie(movie)
        }
    }

    private func playMovie(_ movie: VodItem) {
        Task {
            await library.selectMovie(movie)
            route = .watch
        }
    }

    private func openFavorite(_ favorite: FavoriteMovie) {
        Task {
            if await library.selectFavorite(favorite) {
                route = .watch
            }
        }
    }

    private func playFavorite(_ favorite: FavoriteMovie) {
        Task {
            if await library.selectFavorite(favorite) {
                route = .watch
            }
        }
    }

    private func openProgress(_ progress: WatchProgressItem) {
        pendingWatchProgress = progress
        Task {
            if await library.selectWatchProgress(progress) {
                route = .watch
                selectPlayback(from: progress, in: library.detailMovie ?? library.selectedMovie ?? progress.item)
            }
        }
    }

    private func playProgress(_ progress: WatchProgressItem) {
        openProgress(progress)
    }
}

enum LibrarySection: Hashable {
    case home
    case favorites
    case continueWatching
    case category(Int)
}

private enum ContentRoute {
    case browse
    case watch
}
