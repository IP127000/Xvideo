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

extension VideoSource {
    static let defaultSource = VideoSource(
        id: UUID(uuidString: "5E142A4B-3F31-4CC7-A2D7-10C3FBEEB620")!,
        name: "Xvideo",
        homepageURL: URL(string: "https://lzizy.net"),
        apiURL: URL(string: "https://lzizy.net/api.php/provide/vod/")!,
        searchURL: URL(string: "https://macapi1.com/maccms/json/liangzi/"),
        format: .json,
        isBuiltIn: true
    )

    static let dyttSource = VideoSource(
        id: UUID(uuidString: "D8229C14-AE30-4CE9-B50E-87E9EC2D0A6A")!,
        name: "电影天堂资源",
        homepageURL: URL(string: "https://dyttzy.tv/"),
        apiURL: URL(string: "http://caiji.dyttzyapi.com/api.php/provide/vod/at/xml/")!,
        format: .xml,
        isBuiltIn: true
    )

    static let builtInSources = [defaultSource, dyttSource]
}
