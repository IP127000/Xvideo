import Foundation

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    @Published private(set) var tasks: [DownloadTaskInfo] = []

    private var urlSession: URLSession!
    private var taskIDs: [Int: UUID] = [:]

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 4
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func download(_ episode: Episode, movieName: String) {
        let info = DownloadTaskInfo(
            title: "\(movieName) \(episode.title)",
            sourceURL: episode.url,
            progress: 0,
            status: .queued,
            localURL: nil
        )
        tasks.insert(info, at: 0)

        var request = URLRequest(url: episode.url)
        request.setValue("Xvideo/1.0", forHTTPHeaderField: "User-Agent")
        let task = urlSession.downloadTask(with: request)
        taskIDs[task.taskIdentifier] = info.id
        updateTask(id: info.id) { $0.status = .downloading }
        task.resume()
    }

    func reveal(_ task: DownloadTaskInfo) {
        _ = task
    }

    private func updateTask(id: UUID, _ update: (inout DownloadTaskInfo) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        update(&tasks[index])
    }

    private func destinationURL(for title: String, sourceURL: URL) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = documents.appendingPathComponent("Xvideo", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let ext = sourceURL.pathExtension.nilIfBlank ?? "mp4"
        let safeName = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        return directory.appendingPathComponent(safeName).appendingPathExtension(ext)
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let taskIdentifier = downloadTask.taskIdentifier
        Task { @MainActor in
            guard let id = taskIDs[taskIdentifier] else { return }
            updateTask(id: id) {
                $0.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let taskIdentifier = downloadTask.taskIdentifier
        Task { @MainActor in
            guard let id = taskIDs[taskIdentifier],
                  let taskInfo = tasks.first(where: { $0.id == id }) else {
                return
            }

            let destination = destinationURL(for: taskInfo.title, sourceURL: taskInfo.sourceURL)
            try? FileManager.default.removeItem(at: destination)

            do {
                try FileManager.default.moveItem(at: location, to: destination)
                updateTask(id: id) {
                    $0.progress = 1
                    $0.status = .finished
                    $0.localURL = destination
                }
            } catch {
                updateTask(id: id) {
                    $0.status = .failed(error.localizedDescription)
                }
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        let taskIdentifier = task.taskIdentifier
        Task { @MainActor in
            guard let id = taskIDs[taskIdentifier] else { return }
            updateTask(id: id) {
                $0.status = .failed(error.localizedDescription)
            }
        }
    }
}
