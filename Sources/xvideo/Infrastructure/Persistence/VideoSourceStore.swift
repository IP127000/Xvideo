import Foundation

struct VideoSourceSnapshot {
    let sources: [VideoSource]
    let activeSourceID: VideoSource.ID

    var activeSource: VideoSource {
        sources.first { $0.id == activeSourceID } ?? VideoSource.defaultSource
    }
}

struct VideoSourceStore {
    private struct SourceFile: Codable {
        let sources: [VideoSource]
        let activeSourceID: VideoSource.ID
    }

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let directoryURL = baseURL.appendingPathComponent("xvideo", isDirectory: true)
        fileURL = directoryURL.appendingPathComponent("video-sources.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()

        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func load() -> VideoSourceSnapshot {
        guard let data = try? Data(contentsOf: fileURL),
              let sourceFile = try? decoder.decode(SourceFile.self, from: data) else {
            return VideoSourceSnapshot(
                sources: VideoSource.builtInSources,
                activeSourceID: VideoSource.defaultSource.id
            )
        }

        let sources = mergedWithBuiltIns(sourceFile.sources)
        let activeSourceID = sources.contains { $0.id == sourceFile.activeSourceID }
            ? sourceFile.activeSourceID
            : VideoSource.defaultSource.id

        return VideoSourceSnapshot(sources: sources, activeSourceID: activeSourceID)
    }

    func save(sources: [VideoSource], activeSourceID: VideoSource.ID) {
        let sourceFile = SourceFile(
            sources: mergedWithBuiltIns(sources),
            activeSourceID: activeSourceID
        )

        guard let data = try? encoder.encode(sourceFile) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    private func mergedWithBuiltIns(_ sources: [VideoSource]) -> [VideoSource] {
        var result = sources

        for builtIn in VideoSource.builtInSources {
            if let index = result.firstIndex(where: { $0.id == builtIn.id }) {
                result[index] = builtIn
            } else {
                result.append(builtIn)
            }
        }

        return result.sorted { lhs, rhs in
            if lhs.isBuiltIn != rhs.isBuiltIn {
                return lhs.isBuiltIn && !rhs.isBuiltIn
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}
