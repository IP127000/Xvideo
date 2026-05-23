import Foundation

struct LzizyAPIClient: Sendable {
    private let httpClient: HTTPClient
    private let baseURL = URL(string: "https://lzizy.net/api.php/provide/vod/")!
    private let searchURL = URL(string: "https://macapi1.com/maccms/json/liangzi/")!
    private let defaultHeaders = [
        "User-Agent": "xvideo/1.0",
        "Accept": "application/json,text/plain,*/*"
    ]

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    func fetchList(typeId: Int? = nil, page: Int = 1, keyword: String? = nil) async throws -> VodListResponse {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "pg", value: "\(page)")]

        if let typeId {
            items.append(URLQueryItem(name: "t", value: "\(typeId)"))
        }

        if let keyword = keyword?.trimmingCharacters(in: .whitespacesAndNewlines), !keyword.isEmpty {
            items.append(URLQueryItem(name: "wd", value: keyword))
        }

        components.queryItems = items
        return try await request(components.url!)
    }

    func fetchDetailedList(typeId: Int? = nil, page: Int = 1, keyword: String? = nil) async throws -> VodListResponse {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "ac", value: "detail"),
            URLQueryItem(name: "pg", value: "\(page)")
        ]

        if let typeId {
            items.append(URLQueryItem(name: "t", value: "\(typeId)"))
        }

        if let keyword = keyword?.trimmingCharacters(in: .whitespacesAndNewlines), !keyword.isEmpty {
            items.append(URLQueryItem(name: "wd", value: keyword))
        }

        components.queryItems = items
        return try await request(components.url!)
    }

    func search(keyword: String, page: Int = 1) async throws -> VodListResponse {
        var components = URLComponents(url: searchURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "ac", value: "videolist"),
            URLQueryItem(name: "wd", value: keyword),
            URLQueryItem(name: "pg", value: "\(page)")
        ]
        return try await request(components.url!)
    }

    func fetchCategories() async throws -> [VodCategory] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "ac", value: "detail"),
            URLQueryItem(name: "pg", value: "1")
        ]
        let response: VodListResponse = try await request(components.url!)
        return response.class?.isEmpty == false ? response.class ?? [] : Self.fallbackCategories
    }

    func fetchDetail(id: Int) async throws -> VodItem {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "ac", value: "detail"),
            URLQueryItem(name: "ids", value: "\(id)")
        ]
        let response: VodListResponse = try await request(components.url!)

        guard let item = response.list.first else {
            throw APIError.emptyDetail
        }

        return item
    }

    private func request<T: Decodable>(_ url: URL) async throws -> T {
        try await httpClient.get(url, headers: defaultHeaders)
    }
}

private extension LzizyAPIClient {
    static let fallbackCategories: [VodCategory] = [
        VodCategory(typeId: 1, typePid: 0, typeName: "电影片"),
        VodCategory(typeId: 2, typePid: 0, typeName: "连续剧"),
        VodCategory(typeId: 3, typePid: 0, typeName: "综艺片"),
        VodCategory(typeId: 4, typePid: 0, typeName: "动漫片"),
        VodCategory(typeId: 36, typePid: 0, typeName: "体育"),
        VodCategory(typeId: 6, typePid: 1, typeName: "动作片"),
        VodCategory(typeId: 7, typePid: 1, typeName: "喜剧片"),
        VodCategory(typeId: 8, typePid: 1, typeName: "爱情片"),
        VodCategory(typeId: 9, typePid: 1, typeName: "科幻片"),
        VodCategory(typeId: 10, typePid: 1, typeName: "恐怖片"),
        VodCategory(typeId: 11, typePid: 1, typeName: "剧情片"),
        VodCategory(typeId: 12, typePid: 1, typeName: "战争片"),
        VodCategory(typeId: 20, typePid: 1, typeName: "记录片"),
        VodCategory(typeId: 34, typePid: 1, typeName: "伦理片"),
        VodCategory(typeId: 35, typePid: 1, typeName: "电影解说"),
        VodCategory(typeId: 13, typePid: 2, typeName: "国产剧"),
        VodCategory(typeId: 14, typePid: 2, typeName: "香港剧"),
        VodCategory(typeId: 15, typePid: 2, typeName: "韩国剧"),
        VodCategory(typeId: 16, typePid: 2, typeName: "欧美剧"),
        VodCategory(typeId: 21, typePid: 2, typeName: "台湾剧"),
        VodCategory(typeId: 22, typePid: 2, typeName: "日本剧"),
        VodCategory(typeId: 23, typePid: 2, typeName: "海外剧"),
        VodCategory(typeId: 24, typePid: 2, typeName: "泰国剧"),
        VodCategory(typeId: 25, typePid: 3, typeName: "大陆综艺"),
        VodCategory(typeId: 26, typePid: 3, typeName: "港台综艺"),
        VodCategory(typeId: 27, typePid: 3, typeName: "日韩综艺"),
        VodCategory(typeId: 28, typePid: 3, typeName: "欧美综艺"),
        VodCategory(typeId: 29, typePid: 4, typeName: "国产动漫"),
        VodCategory(typeId: 30, typePid: 4, typeName: "日韩动漫"),
        VodCategory(typeId: 31, typePid: 4, typeName: "欧美动漫"),
        VodCategory(typeId: 32, typePid: 4, typeName: "港台动漫"),
        VodCategory(typeId: 33, typePid: 4, typeName: "海外动漫"),
        VodCategory(typeId: 37, typePid: 36, typeName: "足球"),
        VodCategory(typeId: 38, typePid: 36, typeName: "篮球"),
        VodCategory(typeId: 39, typePid: 36, typeName: "网球"),
        VodCategory(typeId: 40, typePid: 36, typeName: "斯诺克")
    ]
}

enum APIError: LocalizedError {
    case badResponse
    case emptyDetail

    var errorDescription: String? {
        switch self {
        case .badResponse:
            return "网站接口返回异常。"
        case .emptyDetail:
            return "没有找到影片详情。"
        }
    }
}
