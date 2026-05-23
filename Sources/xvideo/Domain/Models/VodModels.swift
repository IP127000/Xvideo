import Foundation

struct VodListResponse: Decodable {
    let code: Int
    let msg: String?
    let page: Int?
    let pagecount: Int?
    let total: Int?
    let list: [VodItem]
    let `class`: [VodCategory]?

    init(
        code: Int = 1,
        msg: String? = nil,
        page: Int? = nil,
        pagecount: Int? = nil,
        total: Int? = nil,
        list: [VodItem],
        class categories: [VodCategory]? = nil
    ) {
        self.code = code
        self.msg = msg
        self.page = page
        self.pagecount = pagecount
        self.total = total
        self.list = list
        self.class = categories
    }

    enum CodingKeys: String, CodingKey {
        case code
        case msg
        case page
        case pagecount
        case total
        case list
        case `class`
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeFlexibleInt(forKey: .code) ?? 0
        msg = try container.decodeIfPresent(String.self, forKey: .msg)
        page = try container.decodeFlexibleInt(forKey: .page)
        pagecount = try container.decodeFlexibleInt(forKey: .pagecount)
        total = try container.decodeFlexibleInt(forKey: .total)
        list = try container.decodeIfPresent([VodItem].self, forKey: .list) ?? []
        `class` = try container.decodeIfPresent([VodCategory].self, forKey: .class)
    }
}

struct VodCategory: Decodable, Identifiable, Hashable {
    let typeId: Int
    let typePid: Int
    let typeName: String

    var id: Int { typeId }

    enum CodingKeys: String, CodingKey {
        case typeId = "type_id"
        case typePid = "type_pid"
        case typeName = "type_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        typeId = try container.decodeFlexibleInt(forKey: .typeId) ?? 0
        typePid = try container.decodeFlexibleInt(forKey: .typePid) ?? 0
        typeName = try container.decodeIfPresent(String.self, forKey: .typeName) ?? "未分类"
    }
}

struct VodItem: Codable, Identifiable, Hashable {
    let vodId: Int
    let vodName: String
    let typeId: Int?
    let typeName: String?
    let vodPic: String?
    let vodRemarks: String?
    let vodArea: String?
    let vodLang: String?
    let vodYear: String?
    let vodScore: String?
    let vodDoubanScore: String?
    let vodTime: String?
    let vodClass: String?
    let vodActor: String?
    let vodDirector: String?
    let vodContent: String?
    let vodBlurb: String?
    let vodPlayFrom: String?
    let vodPlayURL: String?
    let vodDownURL: String?

    var id: Int { vodId }

    var scoreText: String {
        [vodDoubanScore, vodScore]
            .compactMap { $0 }
            .first { !$0.isEmpty && $0 != "0.0" } ?? "暂无"
    }

    var summary: String {
        let source = vodContent?.nilIfBlank ?? vodBlurb?.nilIfBlank ?? "暂无简介"
        return source.strippingHTML.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var posterURL: URL? {
        guard let vodPic, let encoded = vodPic.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: encoded)
    }

    static let placeholder = VodItem(
        vodId: -1,
        vodName: "",
        typeId: nil,
        typeName: nil,
        vodPic: nil,
        vodRemarks: nil,
        vodArea: nil,
        vodLang: nil,
        vodYear: nil,
        vodScore: nil,
        vodDoubanScore: nil,
        vodTime: nil,
        vodClass: nil,
        vodActor: nil,
        vodDirector: nil,
        vodContent: nil,
        vodBlurb: nil,
        vodPlayFrom: nil,
        vodPlayURL: nil,
        vodDownURL: nil
    )

    enum CodingKeys: String, CodingKey {
        case vodId = "vod_id"
        case vodName = "vod_name"
        case typeId = "type_id"
        case typeName = "type_name"
        case vodPic = "vod_pic"
        case vodRemarks = "vod_remarks"
        case vodArea = "vod_area"
        case vodLang = "vod_lang"
        case vodYear = "vod_year"
        case vodScore = "vod_score"
        case vodDoubanScore = "vod_douban_score"
        case vodTime = "vod_time"
        case vodClass = "vod_class"
        case vodActor = "vod_actor"
        case vodDirector = "vod_director"
        case vodContent = "vod_content"
        case vodBlurb = "vod_blurb"
        case vodPlayFrom = "vod_play_from"
        case vodPlayURL = "vod_play_url"
        case vodDownURL = "vod_down_url"
    }

    init(
        vodId: Int,
        vodName: String,
        typeId: Int?,
        typeName: String?,
        vodPic: String?,
        vodRemarks: String?,
        vodArea: String?,
        vodLang: String?,
        vodYear: String?,
        vodScore: String?,
        vodDoubanScore: String?,
        vodTime: String?,
        vodClass: String?,
        vodActor: String?,
        vodDirector: String?,
        vodContent: String?,
        vodBlurb: String?,
        vodPlayFrom: String?,
        vodPlayURL: String?,
        vodDownURL: String?
    ) {
        self.vodId = vodId
        self.vodName = vodName
        self.typeId = typeId
        self.typeName = typeName
        self.vodPic = vodPic
        self.vodRemarks = vodRemarks
        self.vodArea = vodArea
        self.vodLang = vodLang
        self.vodYear = vodYear
        self.vodScore = vodScore
        self.vodDoubanScore = vodDoubanScore
        self.vodTime = vodTime
        self.vodClass = vodClass
        self.vodActor = vodActor
        self.vodDirector = vodDirector
        self.vodContent = vodContent
        self.vodBlurb = vodBlurb
        self.vodPlayFrom = vodPlayFrom
        self.vodPlayURL = vodPlayURL
        self.vodDownURL = vodDownURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vodId = try container.decodeFlexibleInt(forKey: .vodId) ?? 0
        vodName = try container.decodeIfPresent(String.self, forKey: .vodName) ?? "未命名"
        typeId = try container.decodeFlexibleInt(forKey: .typeId)
        typeName = try container.decodeIfPresent(String.self, forKey: .typeName)
        vodPic = try container.decodeIfPresent(String.self, forKey: .vodPic)
        vodRemarks = try container.decodeIfPresent(String.self, forKey: .vodRemarks)
        vodArea = try container.decodeIfPresent(String.self, forKey: .vodArea)
        vodLang = try container.decodeIfPresent(String.self, forKey: .vodLang)
        vodYear = try container.decodeStringOrNumber(forKey: .vodYear)
        vodScore = try container.decodeStringOrNumber(forKey: .vodScore)
        vodDoubanScore = try container.decodeStringOrNumber(forKey: .vodDoubanScore)
        vodTime = try container.decodeIfPresent(String.self, forKey: .vodTime)
        vodClass = try container.decodeIfPresent(String.self, forKey: .vodClass)
        vodActor = try container.decodeIfPresent(String.self, forKey: .vodActor)
        vodDirector = try container.decodeIfPresent(String.self, forKey: .vodDirector)
        vodContent = try container.decodeIfPresent(String.self, forKey: .vodContent)
        vodBlurb = try container.decodeIfPresent(String.self, forKey: .vodBlurb)
        vodPlayFrom = try container.decodeIfPresent(String.self, forKey: .vodPlayFrom)
        vodPlayURL = try container.decodeIfPresent(String.self, forKey: .vodPlayURL)
        vodDownURL = try container.decodeIfPresent(String.self, forKey: .vodDownURL)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    func decodeStringOrNumber(forKey key: Key) throws -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        return nil
    }
}
