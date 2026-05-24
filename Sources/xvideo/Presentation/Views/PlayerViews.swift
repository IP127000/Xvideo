import AVKit
import SwiftUI
import WebKit

struct PlayerPanel: View {
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
        }
        .padding(12)
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
