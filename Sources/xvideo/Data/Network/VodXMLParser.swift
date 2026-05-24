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

    private var page: Int?
    private var pageCount: Int?
    private var total: Int?
    private var videos: [VodItem] = []
    private var categories: [VodCategory] = []
    private var currentVideo: XMLVideo?
    private var currentCategoryID: Int?
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

        return VodListResponse(
            code: 1,
            page: delegate.page,
            pagecount: delegate.pageCount,
            total: delegate.total,
            list: delegate.videos,
            class: delegate.categories.isEmpty ? nil : delegate.categories
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
                VodCategory(
                    typeId: currentCategoryID,
                    typePid: Self.parentID(for: currentCategoryID, name: text),
                    typeName: text.isEmpty ? "未分类" : text
                )
            )
            self.currentCategoryID = nil
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

    private static func parentID(for id: Int, name: String) -> Int {
        if let fallbackParentID = fallbackParentIDs[id] {
            return fallbackParentID
        }

        if ["电影片", "连续剧", "综艺片", "动漫片", "体育"].contains(name) {
            return 0
        }
        if name.contains("剧") {
            return 2
        }
        if name.contains("综艺") {
            return 3
        }
        if name.contains("动漫") {
            return 4
        }
        if name.contains("足球") || name.contains("篮球") || name.contains("网球") || name.contains("斯诺克") {
            return 36
        }
        if name.contains("片") || name.contains("电影") {
            return 1
        }
        return 0
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
