import Foundation

struct Episode: Identifiable, Hashable {
    var id: String { url.absoluteString }
    let title: String
    let url: URL
}

struct PlaybackSource: Identifiable, Hashable {
    let id: String
    let name: String
    let episodes: [Episode]
}

struct DownloadTaskInfo: Identifiable, Codable, Equatable {
    let id: UUID
    let movieName: String
    let title: String
    let sourceURL: URL
    var progress: Double
    var status: DownloadStatus
    var localURL: URL?

    init(
        id: UUID = UUID(),
        movieName: String,
        title: String,
        sourceURL: URL,
        progress: Double,
        status: DownloadStatus,
        localURL: URL?
    ) {
        self.id = id
        self.movieName = movieName
        self.title = title
        self.sourceURL = sourceURL
        self.progress = progress
        self.status = status
        self.localURL = localURL
    }
}

enum DownloadStatus: Codable, Equatable {
    case queued
    case downloading
    case paused
    case canceled
    case finished
    case failed(String)

    var label: String {
        switch self {
        case .queued:
            return "等待中"
        case .downloading:
            return "下载中"
        case .paused:
            return "已暂停"
        case .canceled:
            return "已取消"
        case .finished:
            return "已完成"
        case .failed(let message):
            return "失败：\(message)"
        }
    }

    var isTerminal: Bool {
        switch self {
        case .finished, .failed, .canceled:
            return true
        case .queued, .downloading, .paused:
            return false
        }
    }
}
