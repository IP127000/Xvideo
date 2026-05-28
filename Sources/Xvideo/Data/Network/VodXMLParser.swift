import Foundation

final class VodXMLParser: NSObject, XMLParserDelegate {
    private struct XMLVideo {
        var vodId = 0
        var typeId: Int?
        var name = ""
        var typeName: String?
        var pic: String?
        var note: String?
        var area: String?
        var lang: String?
        var year: String?
        var actor: String?
        var director: String?
        var content: String?
        var last: String?
        var playNames: [String] = []
        var playURLs: [String] = []
    }

    private struct XMLCategory {
        let id: Int
        let parentID: Int?
        let name: String
    }

    private struct RootCategoryIDs {
        let movie: Int?
        let drama: Int?
        let variety: Int?
        let anime: Int?
        let sports: Int?
        let shortDrama: Int?
    }

    private var page: Int?
    private var pageCount: Int?
    private var total: Int?
    private var videos: [VodItem] = []
    private var categories: [XMLCategory] = []
    private var currentVideo: XMLVideo?
    private var currentCategoryID: Int?
    private var currentCategoryParentID: Int?
    private var currentPlayFlag: String?
    private var currentElement = ""
    private var textBuffer = ""

    static func parse(_ data: Data) throws -> VodListResponse {
        let delegate = VodXMLParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else {
            throw parser.parserError ?? APIError.badResponse
        }

        let categories = Self.vodCategories(from: delegate.categories)

        return VodListResponse(
            code: 1,
            page: delegate.page,
            pagecount: delegate.pageCount,
            total: delegate.total,
            list: delegate.videos,
            class: categories.isEmpty ? nil : categories
        )
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        textBuffer = ""

        switch elementName {
        case "list":
            page = attributeDict.flexibleInt(named: "page")
            pageCount = attributeDict.flexibleInt(named: "pagecount")
            total = attributeDict.flexibleInt(named: "recordcount") ?? attributeDict.flexibleInt(named: "total")
        case "video":
            currentVideo = XMLVideo()
        case "ty":
            currentCategoryID = attributeDict.flexibleInt(named: "id")
                ?? attributeDict.flexibleInt(named: "type_id")
            currentCategoryParentID = attributeDict.flexibleInt(named: "pid")
                ?? attributeDict.flexibleInt(named: "parentid")
                ?? attributeDict.flexibleInt(named: "type_pid")
        case "dd":
            currentPlayFlag = attributeDict["flag"]
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let string = String(data: CDATABlock, encoding: .utf8) {
            textBuffer += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let text = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        if currentVideo != nil {
            applyVideoField(elementName: elementName, text: text)
        } else if elementName == "ty", let currentCategoryID {
            categories.append(
                XMLCategory(
                    id: currentCategoryID,
                    parentID: currentCategoryParentID,
                    name: text.isEmpty ? "未分类" : text
                )
            )
            self.currentCategoryID = nil
            currentCategoryParentID = nil
        }

        if elementName == "video", let currentVideo {
            videos.append(vodItem(from: currentVideo))
            self.currentVideo = nil
        }

        if elementName == "dd" {
            currentPlayFlag = nil
        }

        textBuffer = ""
    }

    private func applyVideoField(elementName: String, text: String) {
        guard var video = currentVideo else { return }

        switch elementName {
        case "id":
            video.vodId = Int(text) ?? 0
        case "tid":
            video.typeId = Int(text)
        case "name":
            video.name = text
        case "type":
            video.typeName = text.nilIfBlank
        case "pic":
            video.pic = text.nilIfBlank
        case "note":
            video.note = text.nilIfBlank
        case "area":
            video.area = text.nilIfBlank
        case "lang":
            video.lang = text.nilIfBlank
        case "year":
            video.year = text.nilIfBlank
        case "actor":
            video.actor = text.nilIfBlank
        case "director":
            video.director = text.nilIfBlank
        case "des":
            video.content = text.nilIfBlank
        case "last":
            video.last = text.nilIfBlank
        case "dd":
            if let currentPlayFlag, !text.isEmpty {
                video.playNames.append(currentPlayFlag)
                video.playURLs.append(text)
            }
        default:
            break
        }

        currentVideo = video
    }

    private func vodItem(from video: XMLVideo) -> VodItem {
        VodItem(
            vodId: video.vodId,
            vodName: video.name.isEmpty ? "未命名" : video.name,
            typeId: video.typeId,
            typeName: video.typeName,
            vodPic: video.pic,
            vodPicThumb: nil,
            vodPicSlide: nil,
            vodPicScreenshot: nil,
            vodRemarks: video.note,
            vodArea: video.area,
            vodLang: video.lang,
            vodYear: video.year,
            vodScore: nil,
            vodDoubanScore: nil,
            vodTime: video.last,
            vodClass: nil,
            vodActor: video.actor,
            vodDirector: video.director,
            vodContent: video.content,
            vodBlurb: nil,
            vodPlayFrom: video.playNames.joined(separator: "$$$").nilIfBlank,
            vodPlayURL: video.playURLs.joined(separator: "$$$").nilIfBlank,
            vodDownURL: nil
        )
    }

    private static func vodCategories(from xmlCategories: [XMLCategory]) -> [VodCategory] {
        let rootIDs = rootCategoryIDs(in: xmlCategories)
        var seen = Set<Int>()
        return xmlCategories.compactMap { category in
            guard category.id > 0, seen.insert(category.id).inserted else { return nil }

            return VodCategory(
                typeId: category.id,
                typePid: parentID(
                    for: category.id,
                    explicitParentID: category.parentID,
                    name: category.name,
                    rootIDs: rootIDs
                ),
                typeName: category.name
            )
        }
    }

    private static func rootCategoryIDs(in categories: [XMLCategory]) -> RootCategoryIDs {
        let ids = Set(categories.map(\.id))

        return RootCategoryIDs(
            movie: rootID(in: categories, matching: isMovieRootName) ?? (ids.contains(1) ? 1 : nil),
            drama: rootID(in: categories, matching: isDramaRootName) ?? (ids.contains(2) ? 2 : nil),
            variety: rootID(in: categories, matching: isVarietyRootName) ?? (ids.contains(3) ? 3 : nil),
            anime: rootID(in: categories, matching: isAnimeRootName) ?? (ids.contains(4) ? 4 : nil),
            sports: rootID(in: categories, matching: isSportsRootName) ?? (ids.contains(36) ? 36 : nil),
            shortDrama: rootID(in: categories, matching: isShortDramaRootName)
        )
    }

    private static func rootID(
        in categories: [XMLCategory],
        matching predicate: (String) -> Bool
    ) -> Int? {
        categories.first { predicate(normalizedCategoryName($0.name)) }?.id
    }

    private static func parentID(
        for id: Int,
        explicitParentID: Int?,
        name: String,
        rootIDs: RootCategoryIDs
    ) -> Int {
        let normalizedName = normalizedCategoryName(name)

        if let explicitParentID, explicitParentID != id {
            return max(explicitParentID, 0)
        }

        if isMovieRootName(normalizedName) ||
            isDramaRootName(normalizedName) ||
            isVarietyRootName(normalizedName) ||
            isAnimeRootName(normalizedName) ||
            isSportsRootName(normalizedName) ||
            isShortDramaRootName(normalizedName) {
            return 0
        }

        if isShortDramaChildName(normalizedName) {
            return rootIDs.shortDrama ?? 0
        }
        if isSportsChildName(normalizedName) {
            return rootIDs.sports ?? 0
        }
        if isVarietyChildName(normalizedName) {
            return rootIDs.variety ?? 0
        }
        if isAnimeChildName(normalizedName) {
            return rootIDs.anime ?? 0
        }
        if isDramaChildName(normalizedName) {
            return rootIDs.drama ?? 0
        }
        if isMovieChildName(normalizedName) {
            return rootIDs.movie ?? 0
        }

        if let fallbackParentID = fallbackParentIDs[id] {
            return mappedParentID(fallbackParentID, rootIDs: rootIDs)
        }

        return 0
    }

    private static func mappedParentID(_ parentID: Int, rootIDs: RootCategoryIDs) -> Int {
        switch parentID {
        case 1:
            return rootIDs.movie ?? 0
        case 2:
            return rootIDs.drama ?? 0
        case 3:
            return rootIDs.variety ?? 0
        case 4:
            return rootIDs.anime ?? 0
        case 36:
            return rootIDs.sports ?? 0
        default:
            return parentID
        }
    }

    private static func normalizedCategoryName(_ name: String) -> String {
        name.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .lowercased()
    }

    private static func isMovieRootName(_ name: String) -> Bool {
        ["电影", "电影片"].contains(name)
    }

    private static func isDramaRootName(_ name: String) -> Bool {
        ["电视剧", "连续剧", "剧集"].contains(name)
    }

    private static func isVarietyRootName(_ name: String) -> Bool {
        ["综艺", "综艺片"].contains(name)
    }

    private static func isAnimeRootName(_ name: String) -> Bool {
        ["动漫", "动漫片"].contains(name)
    }

    private static func isSportsRootName(_ name: String) -> Bool {
        name == "体育" || name == "体育赛事"
    }

    private static func isShortDramaRootName(_ name: String) -> Bool {
        ["短剧", "短剧片", "爽文短剧"].contains(name)
    }

    private static func isMovieChildName(_ name: String) -> Bool {
        name == "动画片" ||
            name.contains("电影") ||
            name.contains("片") ||
            name.contains("纪录") ||
            name.contains("记录") ||
            name.contains("伦理") ||
            name.contains("解说") ||
            name.contains("三级") ||
            name.contains("4k")
    }

    private static func isDramaChildName(_ name: String) -> Bool {
        name.contains("剧")
    }

    private static func isVarietyChildName(_ name: String) -> Bool {
        name.contains("综艺") || name.contains("演唱会")
    }

    private static func isAnimeChildName(_ name: String) -> Bool {
        name.contains("动漫")
    }

    private static func isSportsChildName(_ name: String) -> Bool {
        name.contains("足球") ||
            name.contains("篮球") ||
            name.contains("网球") ||
            name.contains("斯诺克") ||
            name.contains("体育")
    }

    private static func isShortDramaChildName(_ name: String) -> Bool {
        name.contains("短剧") ||
            name.contains("爽剧") ||
            name.contains("恋爱") ||
            name.contains("仙侠") ||
            name.contains("穿越") ||
            name.contains("悬疑") ||
            name.contains("都市")
    }

    private static let fallbackParentIDs: [Int: Int] = [
        1: 0, 2: 0, 3: 0, 4: 0, 36: 0,
        6: 1, 7: 1, 8: 1, 9: 1, 10: 1, 11: 1, 12: 1, 20: 1, 34: 1, 35: 1,
        13: 2, 14: 2, 15: 2, 16: 2, 21: 2, 22: 2, 23: 2, 24: 2,
        25: 3, 26: 3, 27: 3, 28: 3,
        29: 4, 30: 4, 31: 4, 32: 4, 33: 4,
        37: 36, 38: 36, 39: 36, 40: 36
    ]
}

private extension Dictionary where Key == String, Value == String {
    func flexibleInt(named name: String) -> Int? {
        guard let value = self[name]?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        return Int(value)
    }
}
