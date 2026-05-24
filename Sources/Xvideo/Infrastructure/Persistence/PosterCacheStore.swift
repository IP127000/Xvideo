import CryptoKit
import Foundation
import AppKit

actor PosterCacheStore {
    private let directoryURL: URL

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        directoryURL = baseURL
            .appendingPathComponent("Xvideo", isDirectory: true)
            .appendingPathComponent("posters", isDirectory: true)

        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func cachedFileURLs(for urls: [URL]) -> [URL: URL] {
        urls.reduce(into: [URL: URL]()) { result, url in
            let fileURL = fileURL(for: url)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                result[url] = fileURL
            }
        }
    }

    func cachePosters(for items: [VodItem]) async -> [URL: URL] {
        let urls = Array(Set(items.compactMap(\.posterURL)))
        var cachedFiles = cachedFileURLs(for: urls)
        let missingURLs = urls.filter { cachedFiles[$0] == nil }

        for batchStart in stride(from: 0, to: missingURLs.count, by: 8) {
            let batch = Array(missingURLs[batchStart..<min(batchStart + 8, missingURLs.count)])
            let batchFiles = await downloadPosters(for: batch)
            cachedFiles.merge(batchFiles) { current, _ in current }
        }

        return cachedFiles
    }

    private func downloadPosters(for urls: [URL]) async -> [URL: URL] {
        await withTaskGroup(of: (URL, URL)?.self) { group in
            for url in urls {
                let destinationURL = fileURL(for: url)
                group.addTask {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        return (url, destinationURL)
                    }

                    do {
                        let (data, response) = try await URLSession.shared.data(from: url)
                        guard let httpResponse = response as? HTTPURLResponse,
                              (200..<300).contains(httpResponse.statusCode),
                              httpResponse.mimeType?.hasPrefix("image/") == true,
                              !data.isEmpty,
                              NSImage(data: data) != nil else {
                            return nil
                        }
                        try data.write(to: destinationURL, options: [.atomic])
                        return (url, destinationURL)
                    } catch {
                        return nil
                    }
                }
            }

            var files: [URL: URL] = [:]
            for await result in group {
                guard let result else { continue }
                files[result.0] = result.1
            }
            return files
        }
    }

    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let fileName = digest.map { String(format: "%02x", $0) }.joined()
        let fileExtension = url.pathExtension.nilIfBlank ?? "jpg"
        return directoryURL.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
    }
}
