import AVKit
import SwiftUI
import WebKit
import UIKit

struct PlayerPanel: View {
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
    @State private var isFullscreenPresented = false
    private let skipInterval: TimeInterval = 15

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.black)

            if let episode {
                Group {
                    if usesWebPlayer(episode.url) {
                        PlatformWebVideoPlayer(url: episode.url)
                    } else {
                        PlatformVideoPlayer(
                            player: queuePlayer.player,
                            skipBackward: skipBackwardFromPlayer,
                            skipForward: skipForwardFromPlayer
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(playerTopBar(episode: episode), alignment: .top)
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
        .fullScreenCover(isPresented: $isFullscreenPresented) {
            PhoneFullscreenPlayerCover(
                player: queuePlayer.player,
                navigationState: navigationState
            )
        }
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

                Button {
                    syncNavigationState()
                    isFullscreenPresented = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("全屏播放")
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
            playlistEpisodes: playlistEpisodes,
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
        skipPlayback(by: -skipInterval)
    }

    private func skipForwardFromPlayer() {
        skipPlayback(by: skipInterval)
    }

    private func skipPlayback(by seconds: TimeInterval) {
        guard let episode, !usesWebPlayer(episode.url) else { return }
        queuePlayer.seek(by: seconds)
    }

    private func usesWebPlayer(_ url: URL) -> Bool {
        usesWebPlayerURL(url)
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

private struct PlatformVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    let skipBackward: () -> Void
    let skipForward: () -> Void

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.videoGravity = .resizeAspect
        controller.allowsPictureInPicturePlayback = true
        controller.updatesNowPlayingInfoCenter = false
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
    }

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: ()) {
        controller.player = nil
    }
}

private struct PlatformWebVideoPlayer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: Self.makeConfiguration())
        webView.allowsBackForwardNavigationGestures = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.load(Self.request(for: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }
        webView.load(Self.request(for: url))
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: ()) {
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
    }

    @MainActor
    static func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        return configuration
    }

    static func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 35
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(url.deletingLastPathComponent().absoluteString, forHTTPHeaderField: "Referer")
        return request
    }
}

private struct PhoneFullscreenPlayerCover: View {
    let player: AVPlayer
    @ObservedObject var navigationState: PlaybackNavigationState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color.black
                .ignoresSafeArea()

            if let episode = navigationState.currentEpisode {
                Group {
                    if usesWebPlayerURL(episode.url) {
                        PlatformWebVideoPlayer(url: episode.url)
                    } else {
                        PlatformVideoPlayer(
                            player: player,
                            skipBackward: navigationState.skipBackward,
                            skipForward: navigationState.skipForward
                        )
                    }
                }
                .ignoresSafeArea()
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "play.rectangle")
                        .font(.system(size: 52, weight: .light))
                    Text("选择一集开始播放")
                        .font(.headline)
                }
                .foregroundStyle(.white.opacity(0.82))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            controlsBar
        }
        .background(.black)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    private var controlsBar: some View {
        HStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("退出全屏")

            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.caption)
                Text(navigationState.currentEpisode?.title ?? "播放中")
                    .font(.caption.bold())
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(.black.opacity(0.62), in: Capsule())

            Spacer(minLength: 8)

            Button {
                navigationState.playPreviousEpisode()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .disabled(navigationState.previousEpisode == nil)
            .opacity(navigationState.previousEpisode == nil ? 0.45 : 1)
            .accessibilityLabel("播放上一集")

            Button {
                navigationState.playNextEpisode()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .disabled(navigationState.nextEpisode == nil)
            .opacity(navigationState.nextEpisode == nil ? 0.45 : 1)
            .accessibilityLabel("播放下一集")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.78), .black.opacity(0.34), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }
}

@MainActor
private final class PlaybackNavigationState: ObservableObject {
    @Published var currentEpisode: Episode?
    @Published var playlistEpisodes: [Episode] = []
    @Published var previousEpisode: Episode?
    @Published var nextEpisode: Episode?

    var playPreviousEpisode: () -> Void = {}
    var playNextEpisode: () -> Void = {}
    var skipBackward: () -> Void = {}
    var skipForward: () -> Void = {}
}
