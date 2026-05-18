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
        components.queryItems = [URLQueryItem(name: "pg", value: "1")]
        let response: VodListResponse = try await request(components.url!)
        return response.class ?? []
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
