import SwiftUI

struct MovieDetailView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var favorites: FavoritesStore

    @Binding var selectedPlaybackSourceID: PlaybackSource.ID?
    @Binding var selectedEpisode: Episode?
    let dismissToBrowser: () -> Void

    private var movie: VodItem? {
        library.detailMovie ?? library.selectedMovie
    }

    private var playbackSources: [PlaybackSource] {
        guard let movie else { return [] }
        return SourceParser.parsePlaybackSources(from: movie)
    }

    private var downloadEpisodes: [Episode] {
        guard let movie else { return [] }
        return SourceParser.parseDownloads(from: movie)
    }

    private var selectedSource: PlaybackSource? {
        playbackSources.first { $0.id == selectedPlaybackSourceID } ?? playbackSources.first
    }

    private var previousEpisode: Episode? {
        guard let selectedEpisode,
              let episodes = selectedSource?.episodes,
              let currentIndex = episodes.firstIndex(where: { $0.id == selectedEpisode.id }),
              currentIndex > episodes.startIndex else {
            return nil
        }

        return episodes[episodes.index(before: currentIndex)]
    }

    private var nextEpisode: Episode? {
        guard let selectedEpisode,
              let episodes = selectedSource?.episodes,
              let currentIndex = episodes.firstIndex(where: { $0.id == selectedEpisode.id }),
              episodes.indices.contains(currentIndex + 1) else {
            return nil
        }

        return episodes[currentIndex + 1]
    }

    var body: some View {
        Group {
            if let movie {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PlayerPageHeader(
                            movie: movie,
                            selectedEpisode: selectedEpisode,
                            dismissToBrowser: dismissToBrowser
                        )

                        PlayerPanel(
                            episode: selectedEpisode,
                            playlistEpisodes: selectedSource?.episodes ?? [],
                            previousEpisode: previousEpisode,
                            nextEpisode: nextEpisode,
                            playPreviousEpisode: playPreviousEpisode,
                            playNextEpisode: playNextEpisode,
                            didAdvanceToEpisode: { selectedEpisode = $0 }
                        )
                        .frame(minHeight: 420, idealHeight: 500)

                        DetailHeroSection(
                            movie: movie,
                            isLoadingDetail: library.isLoadingDetail,
                            isFavorite: favorites.isFavorite(movie, sourceID: library.activeVideoSourceID)
                        ) {
                            favorites.toggle(movie, source: library.activeVideoSource)
                        }

                        if !playbackSources.isEmpty {
                            playbackSection
                        }

                        if !downloadEpisodes.isEmpty {
                            downloadSection(movie)
                        }
                    }
                    .padding(22)
                }
                .background(detailBackdrop(for: movie))
            } else {
                EmptyDetailState()
            }
        }
    }

    private var playbackSection: some View {
        DetailSection(title: "播放列表", systemImage: "play.rectangle.on.rectangle") {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedEpisode?.title ?? "选择剧集")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(CinemaTheme.textPrimary)
                    Text(selectedSource?.name ?? "暂无播放源")
                        .font(.caption)
                        .foregroundStyle(CinemaTheme.textSecondary)
                }

                Spacer()

                if let previousEpisode {
                    Button {
                        playPreviousEpisode()
                    } label: {
                        Label("上一集", systemImage: "backward.end.fill")
                    }
                    .buttonStyle(.bordered)
                    .help("播放上一集：\(previousEpisode.title)")
                }

                if let nextEpisode {
                    Button {
                        playNextEpisode()
                    } label: {
                        Label("下一集", systemImage: "forward.end.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CinemaTheme.accent)
                    .help("播放下一集：\(nextEpisode.title)")
                }

                Picker("播放源", selection: Binding(
                    get: { selectedSource?.id },
                    set: { selectPlaybackSource(id: $0) }
                )) {
                    ForEach(playbackSources) { source in
                        Text(source.name).tag(source.id as PlaybackSource.ID?)
                    }
                }
                .labelsHidden()
                .frame(width: 168)
            }

            EpisodeGrid(
                episodes: selectedSource?.episodes ?? [],
                selectedEpisode: selectedEpisode,
                symbol: "play.circle"
            ) { episode in
                selectedEpisode = episode
            }
        }
    }

    private func downloadSection(_ movie: VodItem) -> some View {
        DetailSection(title: "下载", systemImage: "arrow.down.circle") {
            EpisodeGrid(episodes: downloadEpisodes, selectedEpisode: nil, symbol: "arrow.down.circle") { episode in
                downloads.download(episode, movieName: movie.vodName)
            }
        }
    }

    private func detailBackdrop(for movie: VodItem) -> some View {
        ZStack(alignment: .topTrailing) {
            CinemaTheme.appBackground
            RadialGradient(
                colors: [CinemaTheme.accent.opacity(favorites.isFavorite(movie, sourceID: library.activeVideoSourceID) ? 0.28 : 0.18), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 520
            )
            .allowsHitTesting(false)
        }
    }

    private func playPreviousEpisode() {
        guard let previousEpisode else { return }
        selectedEpisode = previousEpisode
    }

    private func playNextEpisode() {
        guard let nextEpisode else { return }
        selectedEpisode = nextEpisode
    }

    private func selectPlaybackSource(id: PlaybackSource.ID?) {
        selectedPlaybackSourceID = id
        selectedEpisode = playbackSources
            .first { $0.id == id }?
            .episodes
            .first
    }
}

private struct PlayerPageHeader: View {
    let movie: VodItem
    let selectedEpisode: Episode?
    let dismissToBrowser: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Button(action: dismissToBrowser) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 38, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(CinemaTheme.textPrimary)
            .background(CinemaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(CinemaTheme.separator, lineWidth: 1)
            }
            .help("返回浏览")

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.vodName)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(CinemaTheme.textPrimary)
                    .lineLimit(1)
                    .textSelection(.enabled)

                Text(selectedEpisode.map { "正在播放：\($0.title)" } ?? "选择一集开始播放")
                    .font(.callout)
                    .foregroundStyle(CinemaTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 8) {
                Badge(text: movie.vodRemarks ?? "待播放", color: CinemaTheme.accentHot)
                Badge(text: "评分 \(movie.scoreText)", color: CinemaTheme.gold)
            }
        }
    }
}

private struct DetailHeroSection: View {
    let movie: VodItem
    let isLoadingDetail: Bool
    let isFavorite: Bool
    let toggleFavorite: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            PosterView(url: movie.posterURL, width: 172, height: 244)

            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(movie.vodName)
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(CinemaTheme.textPrimary)
                            .lineLimit(2)
                            .textSelection(.enabled)

                        HStack(spacing: 8) {
                            Badge(text: movie.vodRemarks ?? "未知进度", color: CinemaTheme.accent)
                            Badge(text: "评分 \(movie.scoreText)", color: CinemaTheme.gold)
                            if let typeName = movie.typeName?.nilIfBlank {
                                Badge(text: typeName, color: CinemaTheme.blue)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        Button {
                            toggleFavorite()
                        } label: {
                            Label(isFavorite ? "已收藏" : "收藏", systemImage: isFavorite ? "heart.fill" : "heart")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isFavorite ? .pink : CinemaTheme.accent)
                        .help(isFavorite ? "取消收藏" : "加入收藏")

                        if isLoadingDetail {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }

                MetadataLine(movie: movie)

                Text(movie.summary)
                    .font(.body)
                    .foregroundStyle(CinemaTheme.textSecondary)
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .lineLimit(8)
            }
        }
        .padding(16)
        .background(CinemaTheme.glassGradient, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(CinemaTheme.separator, lineWidth: 1)
        }
    }
}

private struct MetadataLine: View {
    let movie: VodItem

    var body: some View {
        Text(parts.joined(separator: "  ·  "))
            .font(.callout)
            .foregroundStyle(CinemaTheme.textSecondary)
            .lineLimit(3)
            .textSelection(.enabled)
    }

    private var parts: [String] {
        [
            movie.vodYear,
            movie.vodArea,
            movie.vodLang,
            movie.vodClass,
            movie.vodDirector.map { "导演：\($0)" },
            movie.vodActor.map { "主演：\($0)" }
        ].compactMap { $0?.nilIfBlank }
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.bold))
                .foregroundStyle(CinemaTheme.textPrimary)
            content
        }
        .padding(16)
        .background(CinemaTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(CinemaTheme.separator, lineWidth: 1)
        }
    }
}

private struct EpisodeGrid: View {
    let episodes: [Episode]
    let selectedEpisode: Episode?
    var symbol: String
    let action: (Episode) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 104, maximum: 148), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(episodes) { episode in
                let isSelected = selectedEpisode?.id == episode.id

                Button {
                    action(episode)
                } label: {
                    Label(episode.title, systemImage: symbol)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSelected ? .white : CinemaTheme.textPrimary)
                .background(
                    isSelected ? AnyShapeStyle(CinemaTheme.redGradient) : AnyShapeStyle(CinemaTheme.elevatedBackground),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.white.opacity(0.12) : CinemaTheme.separator, lineWidth: 1)
                }
            }
        }
    }
}

private struct EmptyDetailState: View {
    var body: some View {
        ZStack {
            CinemaTheme.appBackground
            VStack(spacing: 14) {
                Image(systemName: "film.stack")
                    .font(.system(size: 52, weight: .light))
                Text("等待加载")
                    .font(.title2.bold())
                Text("选择一部影片后，这里会显示详情和播放器。")
                    .font(.callout)
                    .foregroundStyle(CinemaTheme.textSecondary)
            }
            .foregroundStyle(CinemaTheme.textPrimary)
        }
    }
}
