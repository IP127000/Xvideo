import Foundation

struct DiscoveryIndex {
    let items: [VodItem]
    let categories: [VodCategory]
    let tags: [String]
    let years: [String]
    let areas: [String]
    let languages: [String]
    let scheduleDays: [ScheduleDay]
    let undatedItems: [VodItem]

    init(items: [VodItem], categories: [VodCategory]) {
        self.items = items
        self.categories = categories
        tags = Self.uniqueValues(items.flatMap(\.discoveryTags))
        years = Self.uniqueValues(items.compactMap { $0.vodYear?.nilIfBlank }).sorted(by: >)
        areas = Self.uniqueValues(items.compactMap { $0.vodArea?.nilIfBlank })
        languages = Self.uniqueValues(items.compactMap { $0.vodLang?.nilIfBlank })

        let grouped = Dictionary(grouping: items) { item in
            item.updateDate
        }
        let sortedDates = grouped.keys.compactMap { $0 }.sorted(by: >)
        scheduleDays = sortedDates.map { date in
            ScheduleDay(
                date: date,
                title: Self.dayTitle(for: date),
                items: (grouped[date] ?? []).sortedByUpdate()
            )
        }
        undatedItems = grouped[nil] ?? []
    }

    var todayItems: [VodItem] {
        guard let firstDay = scheduleDays.first else { return [] }
        return firstDay.items
    }

    var recentWeekItems: [VodItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let cutoff = calendar.date(byAdding: .day, value: -7, to: today) else {
            return items.sortedByUpdate()
        }
        return items.filter { item in
            guard let date = item.updateDate else { return false }
            return date >= cutoff
        }
        .sortedByUpdate()
    }

    func filtered(
        keyword: String,
        category: VodCategory?,
        tag: String?,
        year: String?,
        area: String?,
        language: String?
    ) -> [VodItem] {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)

        return items.filter { item in
            if let category, item.typeId != category.typeId && item.typeName != category.typeName {
                return false
            }
            if let tag, !item.discoveryTags.contains(where: { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame }) {
                return false
            }
            if let year, item.vodYear?.nilIfBlank != year {
                return false
            }
            if let area, item.vodArea?.nilIfBlank != area {
                return false
            }
            if let language, item.vodLang?.nilIfBlank != language {
                return false
            }
            guard !trimmedKeyword.isEmpty else { return true }

            return [
                item.vodName,
                item.vodActor,
                item.vodDirector,
                item.vodClass,
                item.typeName,
                item.vodRemarks
            ]
            .compactMap { $0?.nilIfBlank }
            .contains { $0.localizedCaseInsensitiveContains(trimmedKeyword) }
        }
        .sortedByUpdate()
    }

    private static func uniqueValues(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty,
                  !seen.contains(normalized) else {
                continue
            }
            seen.insert(normalized)
            result.append(normalized)
        }
        return result.sorted { lhs, rhs in
            lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    private static func dayTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: date)
    }
}

struct ScheduleDay: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let title: String
    let items: [VodItem]
}

extension VodItem {
    var discoveryTags: [String] {
        let rawTags = (vodClass?.nilIfBlank ?? "")
            .components(separatedBy: CharacterSet(charactersIn: ",/|、 "))
        let fallback = [typeName, vodArea, vodLang].compactMap { $0?.nilIfBlank }
        return (rawTags + fallback)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var updateDate: Date? {
        guard let raw = vodTime?.nilIfBlank else { return nil }
        let datePart = raw
            .replacingOccurrences(of: "/", with: "-")
            .split(separator: " ")
            .first
            .map(String.init) ?? raw

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current

        for format in ["yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssZ"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) ?? formatter.date(from: datePart) {
                return Calendar.current.startOfDay(for: date)
            }
        }

        return nil
    }
}

private extension Array where Element == VodItem {
    func sortedByUpdate() -> [VodItem] {
        sorted { lhs, rhs in
            switch (lhs.updateDate, rhs.updateDate) {
            case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                return lhsDate > rhsDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.vodId > rhs.vodId
            }
        }
    }
}
