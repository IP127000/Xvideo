#if os(iOS)
import SwiftUI
import UIKit

struct PhoneContentView: View {
    @Binding var searchDraft: String
    @Binding var selectedPlaybackSourceID: PlaybackSource.ID?
    @Binding var selectedEpisode: Episode?
    @Binding var pendingWatchProgress: WatchProgressItem?

    let openMovie: (VodItem) -> Void
    let openFavorite: (FavoriteMovie) -> Void
    let openProgress: (WatchProgressItem) -> Void
    let playFavorite: (FavoriteMovie) -> Void
    let playProgress: (WatchProgressItem) -> Void
    let playMovie: (VodItem) -> Void

    @State private var selectedTab: PhoneTab = .library

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            CinemaTheme.appBackground
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                phoneNavigation {
                    PhoneLibraryTab(selectedTab: $selectedTab)
                }
                .tabItem { Label("片库", systemImage: "film.stack") }
                .tag(PhoneTab.library)

                phoneNavigation {
                    PhoneSearchTab(searchDraft: $searchDraft)
                }
                .tabItem { Label("搜索", systemImage: "magnifyingglass") }
                .tag(PhoneTab.search)

                phoneNavigation {
                    PhoneFavoritesTab()
                }
                .tabItem { Label("收藏", systemImage: "heart") }
                .tag(PhoneTab.favorites)

                phoneNavigation {
                    PhoneContinueWatchingTab()
                }
                .tabItem { Label("继续", systemImage: "clock.arrow.circlepath") }
                .tag(PhoneTab.continueWatching)

                NavigationStack {
                    PhoneSourceManagerTab()
                        .navigationTitle("视频源")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem { Label("视频源", systemImage: "server.rack") }
                .tag(PhoneTab.sources)
            }
            .tint(CinemaTheme.accentHot)

            DownloadShelfView()
                .frame(maxWidth: 340)
                .padding(.horizontal, 12)
                .padding(.bottom, 58)
        }
    }

    private func phoneNavigation<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .phoneDestinations(
                    selectedPlaybackSourceID: $selectedPlaybackSourceID,
                    selectedEpisode: $selectedEpisode,
                    pendingWatchProgress: $pendingWatchProgress,
                    openMovie: openMovie,
                    openFavorite: openFavorite,
                    openProgress: openProgress
                )
        }
    }
}

private enum PhoneTab {
    case library
    case search
    case favorites
    case continueWatching
    case sources
}

private enum PhoneDestination: Hashable {
    case movie(VodItem)
    case favorite(FavoriteMovie)
    case progress(WatchProgressItem)

    var taskID: String {
        switch self {
        case .movie(let movie):
            return "movie-\(movie.id)"
        case .favorite(let favorite):
            return "favorite-\(favorite.id)"
        case .progress(let progress):
            return "progress-\(progress.id)-\(progress.updatedAt.timeIntervalSince1970)"
        }
    }
}

private extension View {
    func phoneDestinations(
        selectedPlaybackSourceID: Binding<PlaybackSource.ID?>,
        selectedEpisode: Binding<Episode?>,
        pendingWatchProgress: Binding<WatchProgressItem?>,
        openMovie: @escaping (VodItem) -> Void,
        openFavorite: @escaping (FavoriteMovie) -> Void,
        openProgress: @escaping (WatchProgressItem) -> Void
    ) -> some View {
        navigationDestination(for: PhoneDestination.self) { destination in
            PhoneMovieDestinationView(
                destination: destination,
                selectedPlaybackSourceID: selectedPlaybackSourceID,
                selectedEpisode: selectedEpisode,
                pendingWatchProgress: pendingWatchProgress,
                openMovie: openMovie,
                openFavorite: openFavorite,
                openProgress: openProgress
            )
        }
    }
}

private struct PhoneLibraryTab: View {
    @EnvironmentObject private var library: LibraryViewModel
    @Binding var selectedTab: PhoneTab

    var body: some View {
        PhoneScrollableScreen(title: "片库") {
            if !library.hasActiveVideoSource {
                PhoneEmptyState(
                    systemImage: "server.rack",
                    title: "还没有视频源",
                    message: "添加自己的采集接口后即可浏览片库。",
                    actionTitle: "添加视频源",
                    action: { selectedTab = .sources }
                )
            } else {
                categoryRail
                stateBanner
                movieList(
                    movies: library.movies,
                    loadMore: { movie in
                        Task { await library.loadBrowsableGridPageIfNeeded(current: movie) }
                    }
                )
            }
        }
        .refreshable {
            await library.refresh()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await library.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(library.isLoadingList || library.isRefreshingPreviewCache)
            }
        }
    }

    private var categoryRail: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryButton(title: "最新", isSelected: library.selectedCategory == nil) {
                        Task { await library.selectCategory(nil) }
                    }

                    ForEach(library.rootCategories) { category in
                        categoryButton(
                            title: category.typeName,
                            isSelected: library.selectedCategory?.typeId == category.typeId
                        ) {
                            Task { await library.selectCategory(category) }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            if !library.childCategories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(library.childCategories) { category in
                            categoryButton(
                                title: category.typeName,
                                isSelected: library.selectedCategory?.typeId == category.typeId
                            ) {
                                Task { await library.selectCategory(category) }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private var stateBanner: some View {
        if library.isLoadingList || library.isRefreshingPreviewCache || library.isSwitchingVideoSource {
            PhoneStatusBanner(text: library.isSwitchingVideoSource ? "正在切换视频源" : "正在加载片库", systemImage: "arrow.triangle.2.circlepath")
                .padding(.horizontal, 16)
        } else if let error = library.errorMessage {
            PhoneStatusBanner(text: error, systemImage: "exclamationmark.triangle", isError: true)
                .padding(.horizontal, 16)
        }
    }

    private func categoryButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .foregroundStyle(isSelected ? .white : CinemaTheme.textSecondary)
                .background(isSelected ? AnyShapeStyle(CinemaTheme.redGradient) : AnyShapeStyle(CinemaTheme.elevatedBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct PhoneSearchTab: View {
    @EnvironmentObject private var library: LibraryViewModel
    @Binding var searchDraft: String

    var body: some View {
        PhoneScrollableScreen(title: "搜索") {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(CinemaTheme.textTertiary)

                    TextField("关键词", text: $searchDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { runSearch() }
                        .foregroundStyle(CinemaTheme.textPrimary)

                    Button(action: runSearch) {
                        Image(systemName: "arrow.forward.circle.fill")
                            .font(.title3)
                    }
                    .disabled(searchDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(CinemaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))

                if library.isLoadingList {
                    PhoneStatusBanner(text: "正在搜索", systemImage: "magnifyingglass")
                } else if let error = library.errorMessage {
                    PhoneStatusBanner(text: error, systemImage: "exclamationmark.triangle", isError: true)
                }
            }
            .padding(.horizontal, 16)

            if library.movies.isEmpty && !library.isLoadingList {
                PhoneEmptyState(
                    systemImage: "film",
                    title: "暂无结果",
                    message: "输入片名、演员或关键词后搜索。",
                    actionTitle: nil,
                    action: nil
                )
                .padding(.top, 28)
            } else {
                movieList(
                    movies: library.movies,
                    loadMore: { movie in
                        Task { await library.loadNextPageIfNeeded(current: movie) }
                    }
                )
            }
        }
        .refreshable {
            guard !searchDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            library.searchText = searchDraft
            await library.search()
        }
    }

    private func runSearch() {
        library.searchText = searchDraft
        Task { await library.search() }
    }
}

private struct PhoneFavoritesTab: View {
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        PhoneScrollableScreen(title: "收藏") {
            if favorites.items.isEmpty {
                PhoneEmptyState(
                    systemImage: "heart",
                    title: "还没有收藏",
                    message: "在影片详情里点收藏后会出现在这里。",
                    actionTitle: nil,
                    action: nil
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(favorites.items) { favorite in
                        NavigationLink(value: PhoneDestination.favorite(favorite)) {
                            PhoneMovieRow(
                                movie: favorite.item,
                                subtitle: favorite.sourceName ?? "收藏",
                                badge: "收藏"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct PhoneContinueWatchingTab: View {
    @EnvironmentObject private var watchProgress: WatchProgressStore

    var body: some View {
        PhoneScrollableScreen(title: "继续观看") {
            if watchProgress.items.isEmpty {
                PhoneEmptyState(
                    systemImage: "clock.arrow.circlepath",
                    title: "暂无观看记录",
                    message: "播放后会自动记录最近进度。",
                    actionTitle: nil,
                    action: nil
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(watchProgress.items) { progress in
                        HStack(spacing: 8) {
                            NavigationLink(value: PhoneDestination.progress(progress)) {
                                PhoneMovieRow(
                                    movie: progress.item,
                                    subtitle: progress.positionLabel,
                                    badge: progress.playbackSourceName ?? "继续"
                                )
                            }
                            .buttonStyle(.plain)

                            Button(role: .destructive) {
                                watchProgress.remove(progress)
                            } label: {
                                Image(systemName: "trash")
                                    .frame(width: 36, height: 44)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red.opacity(0.82))
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct PhoneSourceManagerTab: View {
    @EnvironmentObject private var library: LibraryViewModel

    @State private var name = ""
    @State private var homepageURL = ""
    @State private var apiURL = ""
    @State private var format: VideoSourceFormat = .auto
    @State private var isWorking = false
    @State private var statusText: String?
    @State private var statusIsError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                savedSources
                addSourceForm
            }
            .padding(16)
        }
        .background(CinemaTheme.appBackground.ignoresSafeArea())
    }

    private var savedSources: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhoneSectionTitle(title: "已保存资源", systemImage: "server.rack")

            if library.videoSources.isEmpty {
                PhoneEmptyState(
                    systemImage: "plus.rectangle.on.folder",
                    title: "还没有保存的视频源",
                    message: "Xvideo 不内置数据源，请添加自己的采集接口。",
                    actionTitle: nil,
                    action: nil
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(library.videoSources) { source in
                        sourceRow(source)
                    }
                }
            }
        }
        .phonePanel()
    }

    private var addSourceForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhoneSectionTitle(title: "添加资源", systemImage: "plus.circle")

            PhoneTextField(title: "名称", text: $name)
            PhoneTextField(title: "网站地址（可选）", text: $homepageURL, keyboardType: .URL)
            PhoneTextField(title: "采集接口 URL", text: $apiURL, keyboardType: .URL)

            Picker("格式", selection: $format) {
                ForEach(VideoSourceFormat.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            if let statusText {
                PhoneStatusBanner(text: statusText, systemImage: statusIsError ? "exclamationmark.triangle" : "checkmark.seal", isError: statusIsError)
            }

            HStack(spacing: 10) {
                Button {
                    Task { await testSource() }
                } label: {
                    Label("测试", systemImage: "checkmark.seal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isWorking || apiURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    Task { await addSource() }
                } label: {
                    Label("启用", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(CinemaTheme.accent)
                .disabled(
                    isWorking ||
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    apiURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }

            if library.isSwitchingVideoSource || isWorking {
                PhoneStatusBanner(text: "正在验证或切换视频源", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .phonePanel()
    }

    private func sourceRow(_ source: VideoSource) -> some View {
        let isActive = source.id == library.activeVideoSourceID

        return HStack(spacing: 12) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "server.rack")
                .foregroundStyle(isActive ? CinemaTheme.accentHot : CinemaTheme.textSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(source.name)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(CinemaTheme.textPrimary)
                    .lineLimit(1)
                Text(source.apiURL.absoluteString)
                    .font(.caption)
                    .foregroundStyle(CinemaTheme.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            if isActive {
                Text("当前")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(CinemaTheme.accentHot)
            } else {
                Button {
                    Task { await library.selectVideoSource(source) }
                } label: {
                    Image(systemName: "play.circle")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(library.isSwitchingVideoSource)
            }

            if !source.isBuiltIn {
                Button(role: .destructive) {
                    Task { await library.deleteVideoSource(source) }
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(isActive ? CinemaTheme.accent.opacity(0.13) : CinemaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? CinemaTheme.accent.opacity(0.42) : CinemaTheme.separator, lineWidth: 1)
        }
    }

    private func testSource() async {
        await runSourceAction(clearFormOnSuccess: false) {
            try await library.testVideoSource(
                name: name.isEmpty ? "临时资源" : name,
                homepageURLString: homepageURL,
                apiURLString: apiURL,
                format: format
            )
        }
    }

    private func addSource() async {
        await runSourceAction(clearFormOnSuccess: true) {
            try await library.addVideoSource(
                name: name,
                homepageURLString: homepageURL,
                apiURLString: apiURL,
                format: format
            )
        }
    }

    private func runSourceAction(
        clearFormOnSuccess: Bool,
        action: () async throws -> SourceTestResult
    ) async {
        isWorking = true
        defer { isWorking = false }

        do {
            let result = try await action()
            statusIsError = false
            statusText = "连接成功：\(result.categoryCount) 个分类，\(result.itemCount) 条影片"
            if clearFormOnSuccess {
                name = ""
                homepageURL = ""
                apiURL = ""
                format = .auto
            }
        } catch {
            statusIsError = true
            statusText = error.localizedDescription
        }
    }
}

private struct PhoneMovieDestinationView: View {
    let destination: PhoneDestination
    @Binding var selectedPlaybackSourceID: PlaybackSource.ID?
    @Binding var selectedEpisode: Episode?
    @Binding var pendingWatchProgress: WatchProgressItem?

    let openMovie: (VodItem) -> Void
    let openFavorite: (FavoriteMovie) -> Void
    let openProgress: (WatchProgressItem) -> Void

    var body: some View {
        PhoneMovieDetailView(
            selectedPlaybackSourceID: $selectedPlaybackSourceID,
            selectedEpisode: $selectedEpisode
        )
        .task(id: destination.taskID) {
            openDestination()
        }
    }

    private func openDestination() {
        switch destination {
        case .movie(let movie):
            openMovie(movie)
        case .favorite(let favorite):
            openFavorite(favorite)
        case .progress(let progress):
            pendingWatchProgress = progress
            openProgress(progress)
        }
    }
}

private struct PhoneMovieDetailView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var watchProgress: WatchProgressStore

    @Binding var selectedPlaybackSourceID: PlaybackSource.ID?
    @Binding var selectedEpisode: Episode?

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
                    VStack(alignment: .leading, spacing: 16) {
                        playerBlock(movie)
                        summaryBlock(movie)
                        playbackBlock

                        if !downloadEpisodes.isEmpty {
                            downloadBlock(movie)
                        }
                    }
                    .padding(16)
                }
                .background(CinemaTheme.appBackground.ignoresSafeArea())
                .navigationTitle(movie.vodName)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ZStack {
                    CinemaTheme.appBackground.ignoresSafeArea()
                    ProgressView()
                        .tint(CinemaTheme.accentHot)
                }
                .navigationTitle("详情")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private func playerBlock(_ movie: VodItem) -> some View {
        PlayerPanel(
            movie: movie,
            source: library.activeVideoSource,
            episode: selectedEpisode,
            playbackSource: selectedSource,
            playlistEpisodes: selectedSource?.episodes ?? [],
            previousEpisode: previousEpisode,
            nextEpisode: nextEpisode,
            resumeProgress: watchProgress.progress(for: movie, sourceID: library.activeVideoSourceID),
            playPreviousEpisode: playPreviousEpisode,
            playNextEpisode: playNextEpisode,
            didAdvanceToEpisode: { selectedEpisode = $0 },
            didUpdateWatchProgress: recordWatchProgress
        )
        .frame(height: 220)
    }

    private func summaryBlock(_ movie: VodItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                PosterView(url: movie.posterURL, width: 112, height: 158)

                VStack(alignment: .leading, spacing: 10) {
                    Text(movie.vodName)
                        .font(.title2.weight(.black))
                        .foregroundStyle(CinemaTheme.textPrimary)
                        .lineLimit(3)

                    PhoneMetadataWrap(movie: movie)

                    Button {
                        favorites.toggle(movie, source: library.activeVideoSource)
                    } label: {
                        Label(
                            favorites.isFavorite(movie, sourceID: library.activeVideoSourceID) ? "已收藏" : "收藏",
                            systemImage: favorites.isFavorite(movie, sourceID: library.activeVideoSourceID) ? "heart.fill" : "heart"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(favorites.isFavorite(movie, sourceID: library.activeVideoSourceID) ? .pink : CinemaTheme.accent)

                    if library.isLoadingDetail {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }

            if let progress = watchProgress.progress(for: movie, sourceID: library.activeVideoSourceID) {
                PhoneStatusBanner(text: "上次看到 \(progress.positionLabel)", systemImage: "clock.arrow.circlepath")
            }

            Text(movie.summary)
                .font(.body)
                .foregroundStyle(CinemaTheme.textSecondary)
                .lineSpacing(4)
        }
        .phonePanel()
    }

    @ViewBuilder
    private var playbackBlock: some View {
        if playbackSources.isEmpty {
            PhoneEmptyState(
                systemImage: "play.slash",
                title: "暂无播放地址",
                message: "当前详情没有返回可播放剧集。",
                actionTitle: nil,
                action: nil
            )
            .phonePanel()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    PhoneSectionTitle(title: "播放列表", systemImage: "play.rectangle.on.rectangle")
                    Spacer()
                    Menu {
                        ForEach(playbackSources) { source in
                            Button(source.name) {
                                selectPlaybackSource(id: source.id)
                            }
                        }
                    } label: {
                        Label(selectedSource?.name ?? "播放源", systemImage: "rectangle.stack")
                            .font(.caption.weight(.semibold))
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        playPreviousEpisode()
                    } label: {
                        Label("上一集", systemImage: "backward.end.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(previousEpisode == nil)

                    Button {
                        playNextEpisode()
                    } label: {
                        Label("下一集", systemImage: "forward.end.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CinemaTheme.accent)
                    .disabled(nextEpisode == nil)
                }

                PhoneEpisodeGrid(
                    episodes: selectedSource?.episodes ?? [],
                    selectedEpisode: selectedEpisode,
                    symbol: "play.circle"
                ) { episode in
                    selectedEpisode = episode
                }
            }
            .phonePanel()
        }
    }

    private func downloadBlock(_ movie: VodItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PhoneSectionTitle(title: "下载", systemImage: "arrow.down.circle")
            PhoneEpisodeGrid(episodes: downloadEpisodes, selectedEpisode: nil, symbol: "arrow.down.circle") { episode in
                downloads.download(episode, movieName: movie.vodName)
            }
        }
        .phonePanel()
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

    private func recordWatchProgress(
        episode: Episode,
        positionSeconds: Double,
        durationSeconds: Double?
    ) {
        guard let movie else { return }
        watchProgress.record(
            item: movie,
            source: library.activeVideoSource,
            playbackSource: selectedSource,
            episode: episode,
            positionSeconds: positionSeconds,
            durationSeconds: durationSeconds
        )
    }
}

private struct PhoneScrollableScreen<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(.vertical, 16)
        }
        .background(CinemaTheme.appBackground.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

@ViewBuilder
@MainActor
private func movieList(
    movies: [VodItem],
    loadMore: @escaping (VodItem) -> Void
) -> some View {
    if movies.isEmpty {
        PhoneEmptyState(
            systemImage: "film",
            title: "暂无影片",
            message: "当前列表还没有可显示内容。",
            actionTitle: nil,
            action: nil
        )
        .padding(.horizontal, 16)
    } else {
        LazyVStack(spacing: 10) {
            ForEach(movies) { movie in
                NavigationLink(value: PhoneDestination.movie(movie)) {
                    PhoneMovieRow(
                        movie: movie,
                        subtitle: [movie.typeName, movie.vodYear, movie.vodArea].compactMap { $0?.nilIfBlank }.joined(separator: " · "),
                        badge: movie.vodRemarks?.nilIfBlank
                    )
                }
                .buttonStyle(.plain)
                .onAppear {
                    loadMore(movie)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct PhoneMovieRow: View {
    let movie: VodItem
    let subtitle: String
    let badge: String?

    var body: some View {
        HStack(spacing: 12) {
            PosterView(url: movie.posterURL, width: 72, height: 102)

            VStack(alignment: .leading, spacing: 7) {
                Text(movie.vodName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(CinemaTheme.textPrimary)
                    .lineLimit(2)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(CinemaTheme.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let badge {
                        PhoneMiniBadge(text: badge, color: CinemaTheme.accentHot)
                    }
                    PhoneMiniBadge(text: "评分 \(movie.scoreText)", color: CinemaTheme.gold)
                }
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(CinemaTheme.textTertiary)
        }
        .padding(10)
        .background(CinemaTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(CinemaTheme.separator, lineWidth: 1)
        }
    }
}

private struct PhoneEpisodeGrid: View {
    let episodes: [Episode]
    let selectedEpisode: Episode?
    let symbol: String
    let action: (Episode) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 82, maximum: 132), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(episodes) { episode in
                let isSelected = selectedEpisode?.id == episode.id

                Button {
                    action(episode)
                } label: {
                    Label(episode.title, systemImage: symbol)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
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

private struct PhoneMetadataWrap: View {
    let movie: VodItem

    var body: some View {
        ViewThatFits {
            HStack(spacing: 6) {
                badges
            }
            VStack(alignment: .leading, spacing: 6) {
                badges
            }
        }
    }

    @ViewBuilder
    private var badges: some View {
        if let remarks = movie.vodRemarks?.nilIfBlank {
            PhoneMiniBadge(text: remarks, color: CinemaTheme.accentHot)
        }
        PhoneMiniBadge(text: "评分 \(movie.scoreText)", color: CinemaTheme.gold)
        if let typeName = movie.typeName?.nilIfBlank {
            PhoneMiniBadge(text: typeName, color: CinemaTheme.blue)
        }
        if let year = movie.vodYear?.nilIfBlank {
            PhoneMiniBadge(text: year, color: CinemaTheme.teal)
        }
    }
}

private struct PhoneMiniBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: Capsule())
    }
}

private struct PhoneSectionTitle: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline.weight(.bold))
            .foregroundStyle(CinemaTheme.textPrimary)
    }
}

private struct PhoneStatusBanner: View {
    let text: String
    let systemImage: String
    var isError = false

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .foregroundStyle(isError ? Color.red.opacity(0.9) : CinemaTheme.textSecondary)
        .padding(10)
        .background((isError ? Color.red.opacity(0.12) : CinemaTheme.elevatedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PhoneEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(CinemaTheme.accentHot)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(CinemaTheme.textPrimary)
            Text(message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(CinemaTheme.textSecondary)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(CinemaTheme.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(CinemaTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(CinemaTheme.separator, lineWidth: 1)
        }
    }
}

private struct PhoneTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .foregroundStyle(CinemaTheme.textPrimary)
            .padding(.horizontal, 12)
            .frame(height: 46)
            .background(CinemaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
    }
}

private extension View {
    func phonePanel() -> some View {
        padding(14)
            .background(CinemaTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(CinemaTheme.separator, lineWidth: 1)
            }
    }
}
#endif
