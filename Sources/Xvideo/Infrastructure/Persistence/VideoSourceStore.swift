import Foundation

struct VideoSourceSnapshot {
    let sources: [VideoSource]
    let activeSourceID: VideoSource.ID?

    var activeSource: VideoSource? {
        guard let activeSourceID else { return nil }
        return sources.first { $0.id == activeSourceID }
    }
}

struct VideoSourceStore {
    private struct SourceFile: Codable {
        let sources: [VideoSource]
        let activeSourceID: VideoSource.ID?
    }

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let directoryURL = baseURL.appendingPathComponent("Xvideo", isDirectory: true)
        fileURL = directoryURL.appendingPathComponent("video-sources.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()

        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func load() -> VideoSourceSnapshot {
        guard let data = try? Data(contentsOf: fileURL),
              let sourceFile = try? decoder.decode(SourceFile.self, from: data) else {
            return VideoSourceSnapshot(sources: [], activeSourceID: nil)
        }

        let sources = storedUserSources(sourceFile.sources)
        let activeSourceID = sourceFile.activeSourceID.flatMap { activeID in
            sources.contains { $0.id == activeID } ? activeID : nil
        } ?? sources.first?.id

        return VideoSourceSnapshot(sources: sources, activeSourceID: activeSourceID)
    }

    func save(sources: [VideoSource], activeSourceID: VideoSource.ID?) {
        let sourceFile = SourceFile(
            sources: storedUserSources(sources),
            activeSourceID: activeSourceID.flatMap { activeID in
                sources.contains { $0.id == activeID } ? activeID : nil
            }
        )

        guard let data = try? encoder.encode(sourceFile) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    private func storedUserSources(_ sources: [VideoSource]) -> [VideoSource] {
        sources.filter { !$0.isBuiltIn }
            .sorted { lhs, rhs in
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }
}
