import AVKit
import SwiftUI
import WebKit

struct PlayerPanel: View {
    let episode: Episode?
    let previousEpisode: Episode?
    let nextEpisode: Episode?
    let playPreviousEpisode: () -> Void
    let playNextEpisode: () -> Void

    @State private var player = AVPlayer()
    @State private var currentURL: URL?
    @State private var loadTask: Task<Void, Never>?
    @StateObject private var navigationState = PlaybackNavigationState()

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
        .onAppear {
            syncNavigationState()
            updatePlayerIfNeeded()
        }
        .onChange(of: episode?.url) { _, _ in
            syncNavigationState()
            updatePlayerIfNeeded()
        }
        .onChange(of: previousEpisode?.id) { _, _ in
            syncNavigationState()
        }
        .onChange(of: nextEpisode?.id) { _, _ in
            syncNavigationState()
        }
        .onDisappear {
            loadTask?.cancel()
            player.replaceCurrentItem(with: nil)
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
                    syncNavigationState()
                    if usesWebPlayer(episode.url) {
                        FullscreenWebPlayerWindow.show(navigationState: navigationState)
                    } else {
                        FullscreenPlayerWindow.show(player: player, navigationState: navigationState)
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
        }
        .padding(12)
    }

    private func syncNavigationState() {
        navigationState.currentEpisode = episode
        navigationState.previousEpisode = previousEpisode
        navigationState.nextEpisode = nextEpisode
        navigationState.playPreviousEpisode = playPreviousEpisode
        navigationState.playNextEpisode = playNextEpisode
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
private final class PlaybackNavigationState: ObservableObject {
    @Published var currentEpisode: Episode?
    @Published var previousEpisode: Episode?
    @Published var nextEpisode: Episode?

    var playPreviousEpisode: () -> Void = {}
    var playNextEpisode: () -> Void = {}
}

private struct FullscreenVideoPlayerContent: View {
    let player: AVPlayer
    @ObservedObject var navigationState: PlaybackNavigationState

    var body: some View {
        ZStack(alignment: .top) {
            Color.black
                .ignoresSafeArea()

            MacVideoPlayer(player: player)
                .ignoresSafeArea()

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
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.black.opacity(0.64), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
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
        let window = NSWindow(
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
        let window = NSWindow(
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
