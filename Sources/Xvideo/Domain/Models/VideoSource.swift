import Foundation

enum VideoSourceFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto
    case json
    case xml

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            return "自动"
        case .json:
            return "JSON"
        case .xml:
            return "XML"
        }
    }
}

struct VideoSource: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var homepageURL: URL?
    var apiURL: URL
    var searchURL: URL?
    var format: VideoSourceFormat
    var isBuiltIn: Bool

    init(
        id: UUID = UUID(),
        name: String,
        homepageURL: URL?,
        apiURL: URL,
        searchURL: URL? = nil,
        format: VideoSourceFormat = .auto,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.homepageURL = homepageURL
        self.apiURL = apiURL
        self.searchURL = searchURL
        self.format = format
        self.isBuiltIn = isBuiltIn
    }
}

enum VideoSourceValidationError: LocalizedError {
    case emptyName
    case invalidHomepageURL
    case invalidAPIURL
    case duplicateAPIURL

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "请填写资源名称。"
        case .invalidHomepageURL:
            return "网站地址格式不正确。"
        case .invalidAPIURL:
            return "采集接口 URL 格式不正确。"
        case .duplicateAPIURL:
            return "这个采集接口已经存在。"
        }
    }
}
