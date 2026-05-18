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

struct DownloadTaskInfo: Identifiable {
    let id = UUID()
    let title: String
    let sourceURL: URL
    var progress: Double
    var status: DownloadStatus
    var localURL: URL?
}

enum DownloadStatus: Equatable {
    case queued
    case downloading
    case finished
    case failed(String)

    var label: String {
        switch self {
        case .queued:
            return "等待中"
        case .downloading:
            return "下载中"
        case .finished:
            return "已完成"
        case .failed(let message):
            return "失败：\(message)"
        }
    }
}
