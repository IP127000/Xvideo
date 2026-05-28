import Foundation

struct SourceTestResult: Sendable {
    let categoryCount: Int
    let itemCount: Int
}

struct VodAPIClient: Sendable {
    private let httpClient: HTTPClient
    private let defaultHeaders = [
        "User-Agent": "Xvideo/1.0",
        "Accept": "application/json,application/xml,text/xml,text/plain,*/*"
    ]

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    func fetchList(
        source: VideoSource,
        typeId: Int? = nil,
        page: Int = 1,
        keyword: String? = nil,
        year: String? = nil,
        area: String? = nil
    ) async throws -> VodListResponse {
        var items = [URLQueryItem(name: "pg", value: "\(page)")]

        if let typeId {
            items.append(URLQueryItem(name: "t", value: "\(typeId)"))
        }

        if let keyword = keyword?.trimmingCharacters(in: .whitespacesAndNewlines), !keyword.isEmpty {
            items.append(URLQueryItem(name: "wd", value: keyword))
        }

        appendFilterItems(to: &items, year: year, area: area)

        return try await request(source: source, url: makeURL(source.apiURL, queryItems: items))
    }

    func fetchDetailedList(
        source: VideoSource,
        typeId: Int? = nil,
        page: Int = 1,
        keyword: String? = nil,
        year: String? = nil,
        area: String? = nil
    ) async throws -> VodListResponse {
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

        appendFilterItems(to: &items, year: year, area: area)

        return try await request(source: source, url: makeURL(source.apiURL, queryItems: items))
    }

    func search(source: VideoSource, keyword: String, page: Int = 1) async throws -> VodListResponse {
        let searchURL = source.searchURL ?? source.apiURL
        let action = source.searchURL == nil ? "detail" : "videolist"
        let items = [
            URLQueryItem(name: "ac", value: action),
            URLQueryItem(name: "wd", value: keyword),
            URLQueryItem(name: "pg", value: "\(page)")
        ]
        return try await request(source: source, url: makeURL(searchURL, queryItems: items))
    }

    func fetchCategories(source: VideoSource) async throws -> [VodCategory] {
        let categoryProbes = [
            [
                URLQueryItem(name: "ac", value: "detail"),
                URLQueryItem(name: "pg", value: "1")
            ],
            [],
            [
                URLQueryItem(name: "ac", value: "list")
            ],
            [
                URLQueryItem(name: "ac", value: "videolist"),
                URLQueryItem(name: "pg", value: "1")
            ]
        ]

        for items in categoryProbes {
            do {
                let response: VodListResponse = try await request(
                    source: source,
                    url: makeURL(source.apiURL, queryItems: items)
                )

                if let categories = response.class, !categories.isEmpty {
                    return categories
                }
            } catch {
                continue
            }
        }

        return Self.fallbackCategories
    }

    func fetchDetail(source: VideoSource, id: Int) async throws -> VodItem {
        let items = [
            URLQueryItem(name: "ac", value: "detail"),
            URLQueryItem(name: "ids", value: "\(id)")
        ]
        let response: VodListResponse = try await request(source: source, url: makeURL(source.apiURL, queryItems: items))

        guard let item = response.list.first else {
            throw APIError.emptyDetail
        }

        return item
    }

    func test(source: VideoSource) async throws -> SourceTestResult {
        let probes = [
            [
                URLQueryItem(name: "ac", value: "detail"),
                URLQueryItem(name: "pg", value: "1")
            ],
            [
                URLQueryItem(name: "ac", value: "videolist"),
                URLQueryItem(name: "pg", value: "1")
            ],
            [],
            [
                URLQueryItem(name: "ac", value: "list")
            ]
        ]
        var listOnlyResult: SourceTestResult?

        for items in probes {
            do {
                let response: VodListResponse = try await request(
                    source: source,
                    url: makeURL(source.apiURL, queryItems: items)
                )
                let categoryCount = response.class?.count ?? 0

                if categoryCount > 0 {
                    return SourceTestResult(categoryCount: categoryCount, itemCount: response.list.count)
                }

                if !response.list.isEmpty, listOnlyResult == nil {
                    listOnlyResult = SourceTestResult(categoryCount: 0, itemCount: response.list.count)
                }
            } catch {
                continue
            }
        }

        if let listOnlyResult {
            return listOnlyResult
        }

        throw APIError.badResponse
    }

    private func request(source: VideoSource, url: URL) async throws -> VodListResponse {
        let data = try await httpClient.data(from: url, headers: defaultHeaders)
        return try decode(data, preferredFormat: source.format)
    }

    private func decode(_ data: Data, preferredFormat: VideoSourceFormat) throws -> VodListResponse {
        switch preferredFormat {
        case .json:
            return try JSONDecoder().decode(VodListResponse.self, from: data)
        case .xml:
            return try VodXMLParser.parse(data)
        case .auto:
            if looksLikeXML(data) {
                return try VodXMLParser.parse(data)
            }
            return try JSONDecoder().decode(VodListResponse.self, from: data)
        }
    }

    private func looksLikeXML(_ data: Data) -> Bool {
        guard let preview = String(data: data.prefix(64), encoding: .utf8) else {
            return false
        }
        return preview.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<")
    }

    private func makeURL(_ url: URL, queryItems: [URLQueryItem]) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var items = components.queryItems ?? []
        items.append(contentsOf: queryItems)
        components.queryItems = items
        return components.url ?? url
    }

    private func appendFilterItems(to items: inout [URLQueryItem], year: String?, area: String?) {
        if let year = year?.trimmingCharacters(in: .whitespacesAndNewlines), !year.isEmpty {
            items.append(URLQueryItem(name: "year", value: year))
        }

        if let area = area?.trimmingCharacters(in: .whitespacesAndNewlines), !area.isEmpty {
            items.append(URLQueryItem(name: "area", value: area))
        }
    }
}

private extension VodAPIClient {
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
    case missingSource

    var errorDescription: String? {
        switch self {
        case .badResponse:
            return "网站接口返回异常。"
        case .emptyDetail:
            return "没有找到影片详情。"
        case .missingSource:
            return "请先添加并启用视频源。"
        }
    }
}
