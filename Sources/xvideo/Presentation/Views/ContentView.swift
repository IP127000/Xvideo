import AVKit
import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var downloads: DownloadManager

    @State private var searchDraft = ""
    @State private var selectedSection: LibrarySection = .home
    @State private var selectedPlaybackSourceID: PlaybackSource.ID?
    @State private var selectedEpisode: Episode?

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedSection: $selectedSection)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } content: {
            Group {
                switch selectedSection {
                case .favorites:
                    FavoritesView()
                case .home, .category:
                    MovieListView(searchDraft: $searchDraft)
                }
            }
            .navigationSplitViewColumnWidth(min: 360, ideal: 430)
        } detail: {
            DetailView(
                selectedPlaybackSourceID: $selectedPlaybackSourceID,
                selectedEpisode: $selectedEpisode
            )
        }
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

private enum LibrarySection: Hashable {
    case home
    case favorites
    case category(Int)
}

private struct SidebarView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var favorites: FavoritesStore
    @Binding var selectedSection: LibrarySection

    var body: some View {
        List(selection: Binding(
            get: { selectedSection },
            set: { newValue in
                guard let newValue else { return }
                selectedSection = newValue

                switch newValue {
                case .home:
                    Task { await library.selectCategory(nil) }
                case .favorites:
                    break
                case .category(let id):
                    let category = library.categories.first { $0.id == id }
                    Task { await library.selectCategory(category) }
                }
            }
        )) {
            Section("媒体库") {
                Label("最新更新", systemImage: "sparkles")
                    .tag(LibrarySection.home)

                Label("我的收藏", systemImage: "heart")
                    .tag(LibrarySection.favorites)
            }

            Section("分类") {
                ForEach(library.rootCategories) { category in
                    Label(category.typeName, systemImage: iconName(for: category.typeName))
                        .tag(LibrarySection.category(category.id))
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("xvideo")
                    .font(.headline)
                Text("\(library.total) 条资源 · \(favorites.items.count) 个收藏")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.bar)
        }
    }

    private func iconName(for name: String) -> String {
        if name.contains("电影") { return "film" }
        if name.contains("连续") || name.contains("短剧") { return "tv" }
        if name.contains("动漫") { return "sparkles.tv" }
        if name.contains("综艺") { return "person.2.wave.2" }
        if name.contains("体育") { return "sportscourt" }
        return "rectangle.stack"
    }
}

private struct MovieListView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @Binding var searchDraft: String

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(library.currentTitle)
                        .font(.title2.bold())
                    Spacer()
                    if library.isLoadingList {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索影片或演员", text: $searchDraft)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            library.searchText = searchDraft
                            Task { await library.search() }
                        }
                    if !searchDraft.isEmpty {
                        Button {
                            searchDraft = ""
                            library.searchText = ""
                            Task { await library.refresh() }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

                if !library.childCategories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(library.childCategories) { category in
                                Button(category.typeName) {
                                    Task { await library.selectCategory(category) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
            .padding()

            Divider()

            List(library.movies, selection: Binding(
                get: { library.selectedMovie?.id },
                set: { newValue in
                    guard let item = library.movies.first(where: { $0.id == newValue }) else { return }
                    Task { await library.selectMovie(item) }
                }
            )) { item in
                MovieRow(item: item)
                    .tag(item.id)
                    .task {
                        await library.loadNextPageIfNeeded(current: item)
                    }
            }
            .listStyle(.plain)
        }
        .alert("无法加载", isPresented: Binding(
            get: { library.errorMessage != nil },
            set: { if !$0 { library.errorMessage = nil } }
        )) {
            Button("好") { library.errorMessage = nil }
        } message: {
            Text(library.errorMessage ?? "")
        }
    }
}

private struct FavoritesView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var favorites: FavoritesStore

    private let columns = [
        GridItem(.adaptive(minimum: 132, maximum: 170), spacing: 14)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("我的收藏", systemImage: "heart.fill")
                        .font(.title2.bold())
                    Spacer()
                    Text("\(favorites.items.count) 部")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Text("最近收藏优先显示")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            if favorites.items.isEmpty {
                ContentUnavailableView("暂无收藏", systemImage: "heart", description: Text("收藏内容会显示在这里。"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(favorites.items) { favorite in
                            FavoriteCard(favorite: favorite) {
                                Task { await library.selectMovie(favorite.item) }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

private struct FavoriteCard: View {
    @EnvironmentObject private var favorites: FavoritesStore

    let favorite: FavoriteMovie
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                PosterView(url: favorite.item.posterURL, width: 132, height: 186)
                    .frame(maxWidth: .infinity)

                Text(favorite.item.vodName)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    if let remarks = favorite.item.vodRemarks?.nilIfBlank {
                        Text(remarks)
                    }
                    if let year = favorite.item.vodYear?.nilIfBlank {
                        Text(year)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("取消收藏", role: .destructive) {
                favorites.toggle(favorite.item)
            }
        }
    }
}

private struct MovieRow: View {
    @EnvironmentObject private var favorites: FavoritesStore
    let item: VodItem

    var body: some View {
        HStack(spacing: 12) {
            PosterView(url: item.posterURL, width: 58, height: 82)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.vodName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let remarks = item.vodRemarks?.nilIfBlank {
                        Badge(text: remarks)
                    }
                    if let typeName = item.typeName?.nilIfBlank {
                        Text(typeName)
                    }
                    if let year = item.vodYear?.nilIfBlank {
                        Text(year)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(item.vodTime ?? "")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if favorites.isFavorite(item) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                    .help("已收藏")
            }
        }
        .padding(.vertical, 6)
    }
}

private struct DetailView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var favorites: FavoritesStore
    @Binding var selectedPlaybackSourceID: PlaybackSource.ID?
    @Binding var selectedEpisode: Episode?

    var movie: VodItem? {
        library.detailMovie ?? library.selectedMovie
    }

    var playbackSources: [PlaybackSource] {
        guard let movie else { return [] }
        return SourceParser.parsePlaybackSources(from: movie)
    }

    var downloadEpisodes: [Episode] {
        guard let movie else { return [] }
        return SourceParser.parseDownloads(from: movie)
    }

    var selectedSource: PlaybackSource? {
        playbackSources.first { $0.id == selectedPlaybackSourceID } ?? playbackSources.first
    }

    var nextEpisode: Episode? {
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
                    VStack(alignment: .leading, spacing: 22) {
                        PlayerPanel(
                            episode: selectedEpisode,
                            nextEpisode: nextEpisode,
                            playNextEpisode: playNextEpisode
                        )
                            .frame(height: 360)

                        HStack(alignment: .top, spacing: 20) {
                            PosterView(url: movie.posterURL, width: 160, height: 226)

                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(movie.vodName)
                                        .font(.largeTitle.bold())
                                        .lineLimit(2)
                                    Spacer()
                                    Button {
                                        favorites.toggle(movie)
                                    } label: {
                                        Label(
                                            favorites.isFavorite(movie) ? "已收藏" : "收藏",
                                            systemImage: favorites.isFavorite(movie) ? "heart.fill" : "heart"
                                        )
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(favorites.isFavorite(movie) ? .pink : .accentColor)
                                    .help(favorites.isFavorite(movie) ? "取消收藏" : "加入收藏")

                                    if library.isLoadingDetail {
                                        ProgressView()
                                    }
                                }

                                HStack(spacing: 8) {
                                    Badge(text: movie.vodRemarks ?? "未知进度")
                                    Badge(text: "评分 \(movie.scoreText)")
                                    if let typeName = movie.typeName?.nilIfBlank {
                                        Badge(text: typeName)
                                    }
                                }

                                metadataLine(movie)

                                Text(movie.summary)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(4)
                                    .textSelection(.enabled)
                            }
                        }

                        if !playbackSources.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("播放")
                                        .font(.title3.bold())
                                    Spacer()
                                    Picker("播放源", selection: Binding(
                                        get: { selectedSource?.id },
                                        set: { selectPlaybackSource(id: $0) }
                                    )) {
                                        ForEach(playbackSources) { source in
                                            Text(source.name).tag(source.id as PlaybackSource.ID?)
                                        }
                                    }
                                    .frame(width: 160)
                                }

                                EpisodeGrid(episodes: selectedSource?.episodes ?? []) { episode in
                                    selectedEpisode = episode
                                }
                            }
                        }

                        if !downloadEpisodes.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("下载")
                                    .font(.title3.bold())
                                EpisodeGrid(episodes: downloadEpisodes, symbol: "arrow.down.circle") { episode in
                                    downloads.download(episode, movieName: movie.vodName)
                                }
                            }
                        }
                    }
                    .padding(24)
                }
            } else {
                ContentUnavailableView("等待加载", systemImage: "film.stack")
            }
        }
    }

    private func metadataLine(_ movie: VodItem) -> some View {
        let parts = [
            movie.vodYear,
            movie.vodArea,
            movie.vodLang,
            movie.vodClass,
            movie.vodDirector.map { "导演：\($0)" },
            movie.vodActor.map { "主演：\($0)" }
        ].compactMap { $0?.nilIfBlank }

        return Text(parts.joined(separator: "  ·  "))
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(3)
            .textSelection(.enabled)
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

private struct PlayerPanel: View {
    let episode: Episode?
    let nextEpisode: Episode?
    let playNextEpisode: () -> Void

    @State private var player = AVPlayer()
    @State private var currentURL: URL?
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.black)

            if let episode {
                Group {
                    if usesWebPlayer(episode.url) {
                        MacWebVideoPlayer(url: episode.url)
                    } else {
                        MacVideoPlayer(player: player)
                    }
                }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .topLeading) {
                        Text(episode.title)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.62), in: Capsule())
                            .padding(12)
                    }
                    .overlay(alignment: .topTrailing) {
                        HStack(spacing: 8) {
                            Button {
                                playNextEpisode()
                            } label: {
                                Image(systemName: "forward.end.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(width: 34, height: 34)
                                    .contentShape(Rectangle())
                            }
                            .disabled(nextEpisode == nil)
                            .opacity(nextEpisode == nil ? 0.45 : 1)
                            .accessibilityLabel("播放下一集")
                            .help(nextEpisode.map { "播放下一集：\($0.title)" } ?? "没有下一集")

                            Button {
                                if usesWebPlayer(episode.url) {
                                    FullscreenWebPlayerWindow.show(url: episode.url, title: episode.title)
                                } else {
                                    FullscreenPlayerWindow.show(player: player, title: episode.title)
                                }
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(width: 34, height: 34)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("打开播放窗口")
                            .help("打开播放窗口")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
                        .padding(12)
                    }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "play.rectangle")
                        .font(.system(size: 42))
                    Text("选择一集开始播放")
                        .font(.headline)
                }
                .foregroundStyle(.white.opacity(0.82))
            }
        }
        .onAppear {
            updatePlayerIfNeeded()
        }
        .onChange(of: episode?.url) { _, _ in
            updatePlayerIfNeeded()
        }
        .onDisappear {
            loadTask?.cancel()
            player.replaceCurrentItem(with: nil)
        }
    }

    private func updatePlayerIfNeeded() {
        guard currentURL != episode?.url else { return }
        currentURL = episode?.url
        loadTask?.cancel()

        guard let url = episode?.url else {
            player.replaceCurrentItem(with: nil)
            return
        }

        guard !usesWebPlayer(url) else {
            player.replaceCurrentItem(with: nil)
            return
        }

        player.replaceCurrentItem(with: nil)
        loadTask = Task {
            let playableURL = await PlaybackURLResolver.resolve(url)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard currentURL == url else { return }
                player.replaceCurrentItem(with: AVPlayerItem(url: playableURL))
            }
        }
    }

    private func usesWebPlayer(_ url: URL) -> Bool {
        url.path.contains("/share/")
    }
}

private struct MacVideoPlayer: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: ()) {
        nsView.player = nil
    }
}

private struct MacWebVideoPlayer: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: Self.makeConfiguration())
        webView.allowsBackForwardNavigationGestures = false
        webView.setValue(false, forKey: "drawsBackground")
        webView.load(Self.request(for: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard nsView.url != url else { return }
        nsView.load(Self.request(for: url))
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: ()) {
        nsView.stopLoading()
        nsView.loadHTMLString("", baseURL: nil)
    }

    static func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        return configuration
    }

    static func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 35
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(url.deletingLastPathComponent().absoluteString, forHTTPHeaderField: "Referer")
        return request
    }
}

@MainActor
private final class FullscreenPlayerWindow: NSObject, NSWindowDelegate {
    private static var current: FullscreenPlayerWindow?

    private let playerView: AVPlayerView
    private var window: NSWindow?

    private init(player: AVPlayer, title: String) {
        playerView = AVPlayerView()
        super.init()

        playerView.player = player
        playerView.controlsStyle = .floating
        playerView.videoGravity = .resizeAspect

        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 720)
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = playerView
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrame(screenFrame, display: true)
        self.window = window
    }

    static func show(player: AVPlayer, title: String) {
        current?.close()

        let controller = FullscreenPlayerWindow(player: player, title: title)
        current = controller
        controller.show()
    }

    private func show() {
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
    }

    private func close() {
        window?.delegate = nil
        playerView.player = nil
        window?.close()
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        playerView.player = nil
        window?.delegate = nil
        window = nil
        Self.current = nil
    }
}

@MainActor
private final class FullscreenWebPlayerWindow: NSObject, NSWindowDelegate {
    private static var current: FullscreenWebPlayerWindow?

    private let webView: WKWebView
    private var window: NSWindow?

    private init(url: URL, title: String) {
        webView = WKWebView(frame: .zero, configuration: MacWebVideoPlayer.makeConfiguration())
        super.init()

        webView.allowsBackForwardNavigationGestures = false
        webView.setValue(false, forKey: "drawsBackground")
        webView.load(MacWebVideoPlayer.request(for: url))

        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 720)
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = webView
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrame(screenFrame, display: true)
        self.window = window
    }

    static func show(url: URL, title: String) {
        current?.close()

        let controller = FullscreenWebPlayerWindow(url: url, title: title)
        current = controller
        controller.show()
    }

    private func show() {
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
    }

    private func close() {
        window?.delegate = nil
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        window?.close()
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        window?.delegate = nil
        window = nil
        Self.current = nil
    }
}

private struct EpisodeGrid: View {
    let episodes: [Episode]
    var symbol = "play.circle"
    let action: (Episode) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 96, maximum: 128), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(episodes) { episode in
                Button {
                    action(episode)
                } label: {
                    Label(episode.title, systemImage: symbol)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

private struct DownloadShelfView: View {
    @EnvironmentObject private var downloads: DownloadManager

    var body: some View {
        if !downloads.tasks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("下载", systemImage: "arrow.down.circle")
                        .font(.headline)
                    Spacer()
                }

                ForEach(downloads.tasks.prefix(3)) { task in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(task.title)
                                .lineLimit(1)
                            Spacer()
                            if task.status == .finished {
                                Button("显示") {
                                    downloads.reveal(task)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        ProgressView(value: task.progress)
                        Text(task.status.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .frame(width: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 18, y: 8)
        }
    }
}

private struct PosterView: View {
    @EnvironmentObject private var library: LibraryViewModel

    let url: URL?
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Group {
            if let localURL = library.cachedPosterFileURL(for: url),
               let image = NSImage(contentsOf: localURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(Color(nsColor: .controlBackgroundColor))
                    Image(systemName: "film")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.5), lineWidth: 1)
        }
    }
}

private struct Badge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
            .foregroundStyle(Color.accentColor)
    }
}
