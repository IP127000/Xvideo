import AVKit
import SwiftUI
import WebKit

struct PlayerPanel: View {
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var preferences: UserPreferencesStore

    let movie: VodItem
    let source: VideoSource?
    let episode: Episode?
    let playbackSource: PlaybackSource?
    let playlistEpisodes: [Episode]
    let previousEpisode: Episode?
    let nextEpisode: Episode?
    let resumeProgress: WatchProgressItem?
    let playPreviousEpisode: () -> Void
    let playNextEpisode: () -> Void
    let didAdvanceToEpisode: (Episode) -> Void
    let didUpdateWatchProgress: (Episode, TimeInterval, TimeInterval?) -> Void

    @StateObject private var queuePlayer = QueuePlaybackController()
    @State private var currentURL: URL?
    @StateObject private var navigationState = PlaybackNavigationState()
    @State private var progressTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.black)

            if let episode {
                Group {
                    if usesWebPlayer(episode.url) {
                        MacWebVideoPlayer(url: episode.url)
                    } else {
                        MacVideoPlayer(
                            player: queuePlayer.player,
                            skipBackward: skipBackwardFromPlayer,
                            skipForward: skipForwardFromPlayer
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(playerTopBar(episode: episode), alignment: .top)
                .overlay {
                    DanmakuOverlayView(preferences: preferences.danmaku)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "play.rectangle")
                        .font(.system(size: 46, weight: .light))
                    Text("选择一集开始播放")
                        .font(.headline)
                }
                .foregroundStyle(.white.opacity(0.82))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.36), radius: 26, x: 0, y: 16)
        .onAppear {
            syncNavigationState()
            configureQueuePlayer()
            recordCurrentProgress()
            updatePlayerIfNeeded()
        }
        .onChange(of: episode?.url) { _, _ in
            syncNavigationState()
            recordCurrentProgress()
            updatePlayerIfNeeded()
        }
        .onChange(of: previousEpisode?.id) { _, _ in
            syncNavigationState()
        }
        .onChange(of: nextEpisode?.id) { _, _ in
            syncNavigationState()
        }
        .onDisappear {
            recordCurrentProgress()
            queuePlayer.stop()
        }
        .onReceive(progressTimer) { _ in
            recordCurrentProgress()
        }
    }

    private func playerTopBar(episode: Episode) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.caption)
                Text(episode.title)
                    .font(.caption.bold())
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.black.opacity(0.62), in: Capsule())

            Spacer()

            HStack(spacing: 8) {
                Button {
                    playPreviousEpisode()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .disabled(previousEpisode == nil)
                .opacity(previousEpisode == nil ? 0.45 : 1)
                .accessibilityLabel("播放上一集")
                .help(previousEpisode.map { "播放上一集：\($0.title)" } ?? "没有上一集")
                .instantTooltip(previousEpisode.map { "上一集：\($0.title)" } ?? "没有上一集")

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
                .instantTooltip(nextEpisode.map { "下一集：\($0.title)" } ?? "没有下一集")

                Button {
                    preferences.danmaku.isEnabled.toggle()
                } label: {
                    Image(systemName: preferences.danmaku.isEnabled ? "text.bubble.fill" : "text.bubble")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("切换弹幕")
                .help(preferences.danmaku.isEnabled ? "关闭弹幕" : "开启弹幕")
                .instantTooltip(preferences.danmaku.isEnabled ? "关闭弹幕" : "开启弹幕")

                Button {
                    downloads.download(episode, movieName: movie.vodName)
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .disabled(!downloads.canCache(episode.url))
                .opacity(downloads.canCache(episode.url) ? 1 : 0.45)
                .accessibilityLabel("缓存当前剧集")
                .help(downloads.canCache(episode.url) ? "缓存当前剧集" : "当前仅支持直链资源缓存")
                .instantTooltip(downloads.canCache(episode.url) ? "缓存当前剧集" : "仅支持直链缓存")

                Button {
                    syncNavigationState()
                    if usesWebPlayer(episode.url) {
                        FullscreenWebPlayerWindow.show(navigationState: navigationState)
                    } else {
                        FullscreenPlayerWindow.show(player: queuePlayer.player, navigationState: navigationState)
                    }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("打开播放窗口")
                .help("打开播放窗口")
                .instantTooltip("打开播放窗口")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
    }

    private func syncNavigationState() {
        navigationState.currentEpisode = episode
        navigationState.playlistEpisodes = playlistEpisodes
        navigationState.previousEpisode = previousEpisode
        navigationState.nextEpisode = nextEpisode
        navigationState.playPreviousEpisode = playPreviousEpisode
        navigationState.playNextEpisode = playNextEpisode
        navigationState.skipBackward = skipBackwardFromPlayer
        navigationState.skipForward = skipForwardFromPlayer
        navigationState.danmakuPreferences = preferences.danmaku
    }

    private func configureQueuePlayer() {
        queuePlayer.didAdvanceToEpisode = { advancedEpisode in
            currentURL = advancedEpisode.url
            didAdvanceToEpisode(advancedEpisode)
        }
    }

    private func updatePlayerIfNeeded() {
        guard currentURL != episode?.url else { return }
        currentURL = episode?.url

        guard let episode else {
            queuePlayer.stop()
            return
        }

        guard !usesWebPlayer(episode.url) else {
            queuePlayer.stop()
            return
        }

        queuePlayer.load(
            episode: episode,
            playlistEpisodes: preferences.player.autoplayNextEpisode ? playlistEpisodes : [episode],
            resumePosition: resumePosition(for: episode)
        )
    }

    private func recordCurrentProgress() {
        guard let episode else { return }

        if usesWebPlayer(episode.url) {
            didUpdateWatchProgress(episode, resumePosition(for: episode), nil)
            return
        }

        guard queuePlayer.currentEpisode?.id == episode.id else {
            didUpdateWatchProgress(episode, resumePosition(for: episode), nil)
            return
        }

        let currentSeconds = queuePlayer.currentTimeSeconds
        didUpdateWatchProgress(episode, currentSeconds, queuePlayer.currentDurationSeconds)
    }

    private func resumePosition(for episode: Episode) -> TimeInterval {
        guard let resumeProgress,
              resumeProgress.episodeURL == episode.url,
              resumeProgress.positionSeconds.isFinite,
              resumeProgress.positionSeconds > 5 else {
            return 0
        }
        return resumeProgress.positionSeconds
    }

    private func skipBackwardFromPlayer() {
        skipPlayback(by: -preferences.player.skipIntervalSeconds)
    }

    private func skipForwardFromPlayer() {
        skipPlayback(by: preferences.player.skipIntervalSeconds)
    }

    private func skipPlayback(by seconds: TimeInterval) {
        guard let episode, !usesWebPlayer(episode.url) else { return }
        queuePlayer.seek(by: seconds)
    }

    private func usesWebPlayer(_ url: URL) -> Bool {
        usesWebPlayerURL(url)
    }
}

private struct InstantTooltipModifier: ViewModifier {
    let text: String
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = hovering
            }
            .overlay(alignment: .bottom) {
                if isHovering {
                    Text(text)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.white.opacity(0.14), lineWidth: 1)
                        }
                        .offset(y: 28)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeOut(duration: 0.08), value: isHovering)
    }
}

private extension View {
    func instantTooltip(_ text: String) -> some View {
        modifier(InstantTooltipModifier(text: text))
    }
}

private func usesWebPlayerURL(_ url: URL) -> Bool {
    url.path.contains("/share/")
}

@MainActor
private final class QueuePlaybackController: ObservableObject {
    let player = AVQueuePlayer()

    @Published private(set) var currentEpisode: Episode?

    var didAdvanceToEpisode: (Episode) -> Void = { _ in }

    private let lookaheadCount = 2
    private var currentEpisodeURL: URL?
    private var itemEpisodes: [ObjectIdentifier: Episode] = [:]
    private var loadedEpisodeURLs = Set<URL>()
    private var loadingEpisodeURLs = Set<URL>()
    private var queuedEpisodes: [Episode] = []
    private var currentItemObservation: NSKeyValueObservation?
    private var loadTask: Task<Void, Never>?
    private var generation = 0

    init() {
        currentItemObservation = player.observe(\.currentItem, options: [.new]) { [weak self] observedPlayer, _ in
            let item = observedPlayer.currentItem
            Task { @MainActor [weak self] in
                self?.handleCurrentItemChange(item)
            }
        }
    }

    var currentTimeSeconds: TimeInterval {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : 0
    }

    var currentDurationSeconds: TimeInterval? {
        guard let seconds = player.currentItem?.duration.seconds,
              seconds.isFinite,
              seconds > 0 else {
            return nil
        }
        return seconds
    }

    func load(
        episode: Episode,
        playlistEpisodes: [Episode],
        resumePosition: TimeInterval = 0
    ) {
        let playableEpisodes = playableQueue(from: episode, in: playlistEpisodes)

        if currentEpisodeURL == episode.url, !player.items().isEmpty {
            queuedEpisodes = playableEpisodes
            ensureLookahead(after: episode)
            return
        }

        generation += 1
        loadTask?.cancel()

        let shouldResume = player.rate > 0 || player.timeControlStatus == .playing
        currentEpisodeURL = episode.url
        currentEpisode = episode
        queuedEpisodes = playableEpisodes
        itemEpisodes.removeAll()
        loadedEpisodeURLs.removeAll()
        loadingEpisodeURLs.removeAll()
        player.removeAllItems()

        let activeGeneration = generation
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.appendItems(startingAt: 0, count: self.lookaheadCount, generation: activeGeneration)

            if resumePosition > 5, activeGeneration == self.generation {
                self.seek(to: resumePosition)
            }

            if shouldResume, activeGeneration == self.generation {
                self.player.play()
            }
        }
    }

    func stop() {
        generation += 1
        loadTask?.cancel()
        currentEpisodeURL = nil
        currentEpisode = nil
        queuedEpisodes.removeAll()
        itemEpisodes.removeAll()
        loadedEpisodeURLs.removeAll()
        loadingEpisodeURLs.removeAll()
        player.pause()
        player.removeAllItems()
    }

    func seek(by seconds: TimeInterval) {
        let currentTime = player.currentTime()
        let currentSeconds = currentTime.seconds
        guard currentSeconds.isFinite else { return }

        var targetSeconds = max(currentSeconds + seconds, 0)
        if let durationSeconds = player.currentItem?.duration.seconds,
           durationSeconds.isFinite,
           durationSeconds > 0 {
            targetSeconds = min(targetSeconds, durationSeconds)
        }

        let timescale = currentTime.timescale == 0 ? 600 : currentTime.timescale
        let targetTime = CMTime(seconds: targetSeconds, preferredTimescale: timescale)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func seek(to seconds: TimeInterval) {
        guard seconds.isFinite, seconds > 0 else { return }
        let timescale = player.currentTime().timescale == 0 ? 600 : player.currentTime().timescale
        let targetTime = CMTime(seconds: seconds, preferredTimescale: timescale)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func playableQueue(from episode: Episode, in playlistEpisodes: [Episode]) -> [Episode] {
        let nonWebEpisodes = playlistEpisodes.filter { !usesWebPlayerURL($0.url) }
        guard let selectedIndex = nonWebEpisodes.firstIndex(where: { $0.id == episode.id }) else {
            return [episode]
        }

        return Array(nonWebEpisodes[selectedIndex...])
    }

    private func handleCurrentItemChange(_ item: AVPlayerItem?) {
        guard let item,
              let episode = itemEpisodes[ObjectIdentifier(item)] else {
            return
        }

        ensureLookahead(after: episode)

        guard currentEpisodeURL != episode.url else { return }
        currentEpisodeURL = episode.url
        currentEpisode = episode
        didAdvanceToEpisode(episode)
    }

    private func ensureLookahead(after episode: Episode) {
        guard let currentIndex = queuedEpisodes.firstIndex(where: { $0.id == episode.id }) else {
            return
        }

        let activeGeneration = generation
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.appendItems(
                startingAt: currentIndex + 1,
                count: self.lookaheadCount,
                generation: activeGeneration
            )
        }
    }

    private func appendItems(startingAt startIndex: Int, count: Int, generation activeGeneration: Int) async {
        guard startIndex < queuedEpisodes.endIndex else { return }

        let endIndex = min(queuedEpisodes.endIndex, startIndex + count)
        for index in startIndex..<endIndex {
            guard activeGeneration == generation, !Task.isCancelled else { return }

            let episode = queuedEpisodes[index]
            guard !loadedEpisodeURLs.contains(episode.url),
                  !loadingEpisodeURLs.contains(episode.url) else {
                continue
            }

            loadingEpisodeURLs.insert(episode.url)
            let playableURL = await PlaybackURLResolver.resolve(episode.url)
            loadingEpisodeURLs.remove(episode.url)

            guard activeGeneration == generation, !Task.isCancelled else { return }

            let item = AVPlayerItem(url: playableURL)
            itemEpisodes[ObjectIdentifier(item)] = episode
            loadedEpisodeURLs.insert(episode.url)

            if player.canInsert(item, after: nil) {
                player.insert(item, after: nil)
            }
        }
    }
}

private struct MacVideoPlayer: NSViewRepresentable {
    let player: AVPlayer
    let skipBackward: () -> Void
    let skipForward: () -> Void

    func makeCoordinator() -> NativeTransportSeekActions {
        NativeTransportSeekActions()
    }

    func makeNSView(context: Context) -> SeekAwarePlayerView {
        let view = SeekAwarePlayerView()
        view.player = player
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        view.nativeSeekActions = context.coordinator
        context.coordinator.configure(
            skipBackward: skipBackward,
            skipForward: skipForward
        )
        return view
    }

    func updateNSView(_ nsView: SeekAwarePlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
        nsView.nativeSeekActions = context.coordinator
        context.coordinator.configure(
            skipBackward: skipBackward,
            skipForward: skipForward
        )
    }

    static func dismantleNSView(_ nsView: SeekAwarePlayerView, coordinator: NativeTransportSeekActions) {
        nsView.player = nil
        nsView.nativeSeekActions = nil
    }
}

@MainActor
private final class NativeTransportSeekActions: NSObject {
    private var skipBackward: () -> Void = {}
    private var skipForward: () -> Void = {}

    func configure(
        skipBackward: @escaping () -> Void,
        skipForward: @escaping () -> Void
    ) {
        self.skipBackward = skipBackward
        self.skipForward = skipForward
    }

    func performBackwardSeek() {
        skipBackward()
    }

    func performForwardSeek() {
        skipForward()
    }
}

private final class SeekAwarePlayerView: AVPlayerView {
    weak var nativeSeekActions: NativeTransportSeekActions?

    private var transportTrackingArea: NSTrackingArea?
    private let instantTooltipLabel = InstantTooltipTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureInstantTooltipLabel()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureInstantTooltipLabel()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if nativeTransportControl(at: point) != nil {
            return self
        }

        return super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        switch nativeTransportControl(at: point) {
        case .rewind:
            nativeSeekActions?.performBackwardSeek()
        case .fastForward:
            nativeSeekActions?.performForwardSeek()
        case nil:
            super.mouseDown(with: event)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        configureNativeTransportControls(in: self)

        switch nativeTransportControl(at: point) {
        case .rewind:
            showInstantTooltip("快退", near: point)
        case .fastForward:
            showInstantTooltip("快进", near: point)
        case nil:
            hideInstantTooltip()
        }

        super.mouseMoved(with: event)
    }

    override func layout() {
        super.layout()
        configureNativeTransportControls(in: self)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let transportTrackingArea {
            removeTrackingArea(transportTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        transportTrackingArea = trackingArea
    }

    override func mouseExited(with event: NSEvent) {
        hideInstantTooltip()
        super.mouseExited(with: event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.ensureInstantTooltipLabel()
            self.configureNativeTransportControls(in: self)
        }
    }

    private enum NativeTransportControl {
        case rewind
        case fastForward
    }

    private func nativeTransportControl(at point: NSPoint) -> NativeTransportControl? {
        if transportView(at: point, matching: { label in
            label.contains("rewind")
        }) != nil {
            return .rewind
        }

        if transportView(at: point, matching: { label in
            label.contains("fast forward")
        }) != nil {
            return .fastForward
        }

        return nil
    }

    private func transportView(
        at point: NSPoint,
        in root: NSView? = nil,
        matching predicate: (String) -> Bool
    ) -> NSView? {
        let root = root ?? self

        for subview in root.subviews.reversed() {
            let pointInSubview = subview.convert(point, from: self)
            guard subview.bounds.contains(pointInSubview) else { continue }

            let label = controlLabel(for: subview)
            if predicate(label) {
                return subview
            }

            if let match = transportView(at: point, in: subview, matching: predicate) {
                return match
            }
        }

        return nil
    }

    private func configureNativeTransportControls(in root: NSView) {
        ensureInstantTooltipLabel()

        for subview in root.subviews {
            guard subview !== instantTooltipLabel else { continue }

            let label = controlLabel(for: subview)
            if label.contains("rewind") {
                subview.toolTip = "快退"
                subview.setAccessibilityHelp("快退")
                (subview as? NSControl)?.isEnabled = true
            } else if label.contains("fast forward") {
                subview.toolTip = "快进"
                subview.setAccessibilityHelp("快进")
                (subview as? NSControl)?.isEnabled = true
            }
            configureNativeTransportControls(in: subview)
        }
    }

    private func configureInstantTooltipLabel() {
        instantTooltipLabel.isHidden = true
        instantTooltipLabel.isEditable = false
        instantTooltipLabel.isSelectable = false
        instantTooltipLabel.isBordered = false
        instantTooltipLabel.drawsBackground = false
        instantTooltipLabel.alignment = .center
        instantTooltipLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        instantTooltipLabel.textColor = .white
        instantTooltipLabel.wantsLayer = true
        instantTooltipLabel.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.86).cgColor
        instantTooltipLabel.layer?.cornerRadius = 6
        instantTooltipLabel.layer?.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor
        instantTooltipLabel.layer?.borderWidth = 1
        instantTooltipLabel.setContentHuggingPriority(.required, for: .horizontal)
        instantTooltipLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        ensureInstantTooltipLabel()
    }

    private func ensureInstantTooltipLabel() {
        guard instantTooltipLabel.superview !== self else { return }
        addSubview(instantTooltipLabel, positioned: .above, relativeTo: nil)
    }

    private func showInstantTooltip(_ text: String, near point: NSPoint) {
        ensureInstantTooltipLabel()
        instantTooltipLabel.stringValue = text

        let fittingSize = instantTooltipLabel.intrinsicContentSize
        let width = fittingSize.width + 16
        let height = fittingSize.height + 10
        let x = min(max(point.x - (width / 2), 8), max(bounds.width - width - 8, 8))
        let y = min(max(point.y + 18, 8), max(bounds.height - height - 8, 8))

        instantTooltipLabel.frame = NSRect(x: x, y: y, width: width, height: height)
        instantTooltipLabel.isHidden = false
    }

    private func hideInstantTooltip() {
        instantTooltipLabel.isHidden = true
    }

    private func controlLabel(for view: NSView) -> String {
        let controlTitle = (view as? NSButton)?.title
        return [
            view.accessibilityLabel(),
            view.accessibilityHelp(),
            view.toolTip,
            controlTitle
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
    }
}

private final class InstantTooltipTextField: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
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
private final class PlaybackNavigationState: ObservableObject {
    @Published var currentEpisode: Episode?
    @Published var playlistEpisodes: [Episode] = []
    @Published var previousEpisode: Episode?
    @Published var nextEpisode: Episode?
    @Published var danmakuPreferences = DanmakuPreferences()

    var playPreviousEpisode: () -> Void = {}
    var playNextEpisode: () -> Void = {}
    var skipBackward: () -> Void = {}
    var skipForward: () -> Void = {}
}

private struct FullscreenVideoPlayerContent: View {
    let player: AVPlayer
    @ObservedObject var navigationState: PlaybackNavigationState

    var body: some View {
        ZStack(alignment: .top) {
            Color.black
                .ignoresSafeArea()

            MacVideoPlayer(
                player: player,
                skipBackward: navigationState.skipBackward,
                skipForward: navigationState.skipForward
            )
                .ignoresSafeArea()
                .overlay {
                    DanmakuOverlayView(preferences: navigationState.danmakuPreferences)
                }

            FullscreenPlaybackBar(navigationState: navigationState)
        }
    }
}

private struct FullscreenWebPlayerContent: View {
    @ObservedObject var navigationState: PlaybackNavigationState

    var body: some View {
        ZStack(alignment: .top) {
            Color.black
                .ignoresSafeArea()

            if let url = navigationState.currentEpisode?.url {
                MacWebVideoPlayer(url: url)
                    .ignoresSafeArea()
                    .overlay {
                        DanmakuOverlayView(preferences: navigationState.danmakuPreferences)
                    }
            }

            FullscreenPlaybackBar(navigationState: navigationState)
        }
    }
}

private struct FullscreenPlaybackBar: View {
    @ObservedObject var navigationState: PlaybackNavigationState

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.caption)
                Text(navigationState.currentEpisode?.title ?? "播放中")
                    .font(.caption.bold())
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.black.opacity(0.64), in: Capsule())

            Spacer()

            HStack(spacing: 8) {
                Button {
                    navigationState.playPreviousEpisode()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 34)
                        .contentShape(Rectangle())
                }
                .disabled(navigationState.previousEpisode == nil)
                .opacity(navigationState.previousEpisode == nil ? 0.45 : 1)
                .accessibilityLabel("播放上一集")
                .help(navigationState.previousEpisode.map { "播放上一集：\($0.title)" } ?? "没有上一集")
                .instantTooltip(navigationState.previousEpisode.map { "上一集：\($0.title)" } ?? "没有上一集")

                Button {
                    navigationState.playNextEpisode()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 34)
                        .contentShape(Rectangle())
                }
                .disabled(navigationState.nextEpisode == nil)
                .opacity(navigationState.nextEpisode == nil ? 0.45 : 1)
                .accessibilityLabel("播放下一集")
                .help(navigationState.nextEpisode.map { "播放下一集：\($0.title)" } ?? "没有下一集")
                .instantTooltip(navigationState.nextEpisode.map { "下一集：\($0.title)" } ?? "没有下一集")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.black.opacity(0.64), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
    }
}

private final class PlaybackWindow: NSWindow {
    var escapeHandler: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        if let escapeHandler {
            escapeHandler()
        } else {
            super.cancelOperation(sender)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            escapeHandler?()
            return
        }

        super.keyDown(with: event)
    }
}

@MainActor
private final class FullscreenPlayerWindow: NSObject, NSWindowDelegate {
    private static var current: FullscreenPlayerWindow?

    private let hostingView: NSHostingView<FullscreenVideoPlayerContent>
    private var window: NSWindow?

    private init(player: AVPlayer, navigationState: PlaybackNavigationState) {
        hostingView = NSHostingView(rootView: FullscreenVideoPlayerContent(
            player: player,
            navigationState: navigationState
        ))
        super.init()

        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 720)
        let window = PlaybackWindow(
            contentRect: screenFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = navigationState.currentEpisode?.title ?? "播放窗口"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrame(screenFrame, display: true)
        self.window = window
        window.escapeHandler = { [weak self] in
            self?.close()
        }
    }

    static func show(player: AVPlayer, navigationState: PlaybackNavigationState) {
        current?.close()

        let controller = FullscreenPlayerWindow(player: player, navigationState: navigationState)
        current = controller
        controller.show()
    }

    private func show() {
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
    }

    private func close() {
        window?.delegate = nil
        window?.contentView = nil
        window?.close()
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        window?.contentView = nil
        window?.delegate = nil
        window = nil
        Self.current = nil
    }
}

@MainActor
private final class FullscreenWebPlayerWindow: NSObject, NSWindowDelegate {
    private static var current: FullscreenWebPlayerWindow?

    private let hostingView: NSHostingView<FullscreenWebPlayerContent>
    private var window: NSWindow?

    private init(navigationState: PlaybackNavigationState) {
        hostingView = NSHostingView(rootView: FullscreenWebPlayerContent(navigationState: navigationState))
        super.init()

        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 720)
        let window = PlaybackWindow(
            contentRect: screenFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = navigationState.currentEpisode?.title ?? "播放窗口"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrame(screenFrame, display: true)
        self.window = window
        window.escapeHandler = { [weak self] in
            self?.close()
        }
    }

    static func show(navigationState: PlaybackNavigationState) {
        current?.close()

        let controller = FullscreenWebPlayerWindow(navigationState: navigationState)
        current = controller
        controller.show()
    }

    private func show() {
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
    }

    private func close() {
        window?.delegate = nil
        window?.contentView = nil
        window?.close()
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        window?.contentView = nil
        window?.delegate = nil
        window = nil
        Self.current = nil
    }
}
