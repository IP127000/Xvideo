import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var watchProgress: WatchProgressStore

    @State private var searchDraft = ""
    @State private var selectedPlaybackSourceID: PlaybackSource.ID?
    @State private var selectedEpisode: Episode?
    @State private var pendingWatchProgress: WatchProgressItem?

    var body: some View {
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
        }
    }

    private func openFavorite(_ favorite: FavoriteMovie) {
        Task {
            _ = await library.selectFavorite(favorite)
        }
    }

    private func playFavorite(_ favorite: FavoriteMovie) {
        openFavorite(favorite)
    }

    private func openProgress(_ progress: WatchProgressItem) {
        pendingWatchProgress = progress
        Task {
            if await library.selectWatchProgress(progress) {
                selectPlayback(from: progress, in: library.detailMovie ?? library.selectedMovie ?? progress.item)
            }
        }
    }

    private func playProgress(_ progress: WatchProgressItem) {
        openProgress(progress)
    }
}
