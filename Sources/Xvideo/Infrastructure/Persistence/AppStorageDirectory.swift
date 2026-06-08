import Foundation

enum AppStorageDirectory {
    static func applicationSupport(fileManager: FileManager = .default) -> URL {
        if let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return url
        }

        #if os(macOS)
        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
        #else
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        #endif
    }
}
