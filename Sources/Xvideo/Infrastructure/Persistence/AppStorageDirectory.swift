import Foundation

enum AppStorageDirectory {
    static func applicationSupport(fileManager: FileManager = .default) -> URL {
        if let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return url
        }

        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
    }
}
