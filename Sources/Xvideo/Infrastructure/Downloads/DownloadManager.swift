import AppKit
import Foundation

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    @Published private(set) var tasks: [DownloadTaskInfo] = []

    private var urlSession: URLSession!
    private var taskIDs: [Int: UUID] = [:]
    private var runningTasks: [UUID: URLSessionDownloadTask] = [:]
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    override init() {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let directoryURL = baseURL.appendingPathComponent("Xvideo", isDirectory: true)
        fileURL = directoryURL.appendingPathComponent("download-tasks.json")

        super.init()
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 4
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        load()
    }

    func download(_ episode: Episode, movieName: String) {
        guard canCache(episode.url) else {
            let info = DownloadTaskInfo(
                movieName: movieName,
                title: episode.title,
                sourceURL: episode.url,
                progress: 0,
                status: .failed("当前仅支持直链资源缓存"),
                localURL: nil
            )
            tasks.insert(info, at: 0)
            save()
            return
        }

        let info = DownloadTaskInfo(
            movieName: movieName,
            title: episode.title,
            sourceURL: episode.url,
            progress: 0,
            status: .queued,
            localURL: nil
        )
        tasks.insert(info, at: 0)
        save()
        startDownload(info)
    }

    func retry(_ task: DownloadTaskInfo) {
        guard canCache(task.sourceURL) else {
            updateTask(id: task.id) {
                $0.status = .failed("当前仅支持直链资源缓存")
            }
            return
        }
        updateTask(id: task.id) {
            $0.progress = 0
            $0.status = .queued
            $0.localURL = nil
        }
        guard let updated = tasks.first(where: { $0.id == task.id }) else { return }
        startDownload(updated)
    }

    func pause(_ task: DownloadTaskInfo) {
        runningTasks[task.id]?.cancel()
        runningTasks[task.id] = nil
        updateTask(id: task.id) {
            $0.status = .paused
        }
    }

    func cancel(_ task: DownloadTaskInfo) {
        runningTasks[task.id]?.cancel()
        runningTasks[task.id] = nil
        updateTask(id: task.id) {
            $0.status = .canceled
        }
    }

    func remove(_ task: DownloadTaskInfo) {
        runningTasks[task.id]?.cancel()
        runningTasks[task.id] = nil
        if let localURL = task.localURL {
            try? FileManager.default.removeItem(at: localURL)
        }
        tasks.removeAll { $0.id == task.id }
        save()
    }

    func clearFinished() {
        tasks.removeAll { task in
            if task.status == .finished, let localURL = task.localURL {
                return FileManager.default.fileExists(atPath: localURL.path)
            }
            return false
        }
        save()
    }

    func canCache(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mp4", "m4v", "mov", "mkv", "webm"].contains(ext)
    }

    private func startDownload(_ info: DownloadTaskInfo) {
        guard canCache(info.sourceURL) else {
            updateTask(id: info.id) {
                $0.status = .failed("当前仅支持直链资源缓存")
            }
            return
        }

        var request = URLRequest(url: info.sourceURL)
        request.setValue("Xvideo/1.0", forHTTPHeaderField: "User-Agent")
        let task = urlSession.downloadTask(with: request)
        taskIDs[task.taskIdentifier] = info.id
        runningTasks[info.id] = task
        updateTask(id: info.id) { $0.status = .downloading }
        task.resume()
    }

    func reveal(_ task: DownloadTaskInfo) {
        guard let localURL = task.localURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([localURL])
    }

    private func updateTask(id: UUID, _ update: (inout DownloadTaskInfo) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        update(&tasks[index])
        save()
    }

    private func destinationURL(for task: DownloadTaskInfo) -> URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let directory = downloads.appendingPathComponent("Xvideo", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let ext = task.sourceURL.pathExtension.nilIfBlank ?? "mp4"
        let safeName = "\(task.movieName) \(task.title)"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        return directory.appendingPathComponent(safeName).appendingPathExtension(ext)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let savedTasks = try? decoder.decode([DownloadTaskInfo].self, from: data) else {
            return
        }
        tasks = savedTasks.map { task in
            var copy = task
            if copy.status == .downloading || copy.status == .queued {
                copy.status = .paused
            }
            return copy
        }
    }

    private func save() {
        guard let data = try? encoder.encode(tasks) else { return }
        try? data.write(to: fileURL, options: [.atomic])
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
            guard tasks.first(where: { $0.id == id })?.status == .downloading else { return }
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

            let destination = destinationURL(for: taskInfo)
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
            runningTasks[id] = nil
            taskIDs[taskIdentifier] = nil
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
            if let currentStatus = tasks.first(where: { $0.id == id })?.status,
               currentStatus == .paused || currentStatus == .canceled {
                taskIDs[taskIdentifier] = nil
                return
            }
            updateTask(id: id) {
                $0.status = .failed(error.localizedDescription)
            }
            runningTasks[id] = nil
            taskIDs[taskIdentifier] = nil
        }
    }
}
