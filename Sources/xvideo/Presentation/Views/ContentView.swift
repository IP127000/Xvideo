import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: LibraryViewModel

    @State private var searchDraft = ""
    @State private var selectedSection: LibrarySection = .home
    @State private var selectedPlaybackSourceID: PlaybackSource.ID?
    @State private var selectedEpisode: Episode?

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

                MediaBrowserView(
                    searchDraft: $searchDraft,
                    selectedSection: $selectedSection
                )
                .frame(minWidth: 390, idealWidth: 460, maxWidth: 560)

                MovieDetailView(
                    selectedPlaybackSourceID: $selectedPlaybackSourceID,
                    selectedEpisode: $selectedEpisode
                )
                .frame(minWidth: 620)
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
}

enum LibrarySection: Hashable {
    case home
    case favorites
    case category(Int)
}
