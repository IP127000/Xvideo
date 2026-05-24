import Foundation

struct LibraryPage: Codable {
    let items: [VodItem]
    let page: Int
    let pageCount: Int
    let total: Int
    let remoteCategories: [VodCategory]?

    init(
        items: [VodItem],
        page: Int,
        pageCount: Int,
        total: Int,
        remoteCategories: [VodCategory]? = nil
    ) {
        self.items = items
        self.page = page
        self.pageCount = pageCount
        self.total = total
        self.remoteCategories = remoteCategories
    }

    init(response: VodListResponse, fallbackPage: Int) {
        items = response.list
        page = response.page ?? fallbackPage
        pageCount = response.pagecount ?? 1
        total = response.total ?? response.list.count
        remoteCategories = response.class
    }
}
