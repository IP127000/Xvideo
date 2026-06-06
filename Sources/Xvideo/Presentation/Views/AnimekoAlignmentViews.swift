import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct HomeAnimekoSections: View {
    @EnvironmentObject private var library: LibraryViewModel

    let openMovie: (VodItem) -> Void
    let playMovie: (VodItem) -> Void
    let openCategory: (VodCategory) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !library.discoveryIndex.todayItems.isEmpty || !library.discoveryIndex.recentWeekItems.isEmpty {
                updateSummary
                    .padding(.horizontal, 24)
            }

            if !library.discoveryIndex.tags.isEmpty || !library.rootCategories.isEmpty {
                tagAndCategoryEntrypoints
                    .padding(.horizontal, 24)
            }
        }
    }

    private var updateSummary: some View {
        HStack(alignment: .top, spacing: 14) {
            SummaryPanel(
                title: "今日更新",
                subtitle: "\(library.discoveryIndex.todayItems.count) 部",
                systemImage: "sun.max.fill",
                color: CinemaTheme.gold,
                items: Array(library.discoveryIndex.todayItems.prefix(3)),
                openMovie: openMovie,
                playMovie: playMovie
            )

            SummaryPanel(
                title: "本周更新",
                subtitle: "\(library.discoveryIndex.recentWeekItems.count) 部",
                systemImage: "calendar.badge.clock",
                color: CinemaTheme.teal,
                items: Array(library.discoveryIndex.recentWeekItems.prefix(3)),
                openMovie: openMovie,
                playMovie: playMovie
            )
        }
    }

    private var tagAndCategoryEntrypoints: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("找番入口")
                    .font(.title2.weight(.black))
                    .foregroundStyle(CinemaTheme.textPrimary)
                Text("标签、分类和最近更新聚合")
                    .font(.callout)
                    .foregroundStyle(CinemaTheme.textTertiary)
            }

            FlowLayout(spacing: 8) {
                ForEach(library.rootCategories.prefix(8)) { category in
                    Button {
                        openCategory(category)
                    } label: {
                        Label(category.typeName, systemImage: categoryIcon(for: category.typeName))
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(CinemaTheme.textPrimary)
                    .background(CinemaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(CinemaTheme.separator, lineWidth: 1)
                    }
                }

                ForEach(library.discoveryIndex.tags.prefix(12), id: \.self) { tag in
                    Text("# \(tag)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(CinemaTheme.accentHot)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(CinemaTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .background(CinemaTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(CinemaTheme.separator, lineWidth: 1)
        }
    }
}

struct DiscoveryBrowserView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @Binding var searchDraft: String

    let openMovie: (VodItem) -> Void
    let playMovie: (VodItem) -> Void

    @State private var selectedCategory: VodCategory?
    @State private var selectedTag: String?
    @State private var selectedYear: String?
    @State private var selectedArea: String?
    @State private var selectedLanguage: String?
    @State private var layout: DiscoveryLayout = .grid

    private let columns = [
        GridItem(.adaptive(minimum: 168, maximum: 220), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                pageHeader
                filters

                if filteredItems.isEmpty {
                    ContentUnavailableView("暂无结果", systemImage: "magnifyingglass", description: Text("换个关键词或清空筛选条件试试。"))
                        .foregroundStyle(CinemaTheme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 360)
                } else if layout == .grid {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                        ForEach(filteredItems) { item in
                            DiscoveryGridCard(item: item, openMovie: openMovie, playMovie: playMovie)
                        }
                    }
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredItems) { item in
                            DiscoveryListRow(item: item, openMovie: openMovie, playMovie: playMovie)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(CinemaTheme.appBackground)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("找番")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(CinemaTheme.textPrimary)
                    Text("\(filteredItems.count) 部匹配 · \(library.discoveryIndex.tags.count) 个标签")
                        .font(.callout)
                        .foregroundStyle(CinemaTheme.textSecondary)
                }

                Spacer()

                Picker("布局", selection: $layout) {
                    Label("网格", systemImage: "square.grid.2x2").tag(DiscoveryLayout.grid)
                    Label("列表", systemImage: "list.bullet").tag(DiscoveryLayout.list)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(CinemaTheme.accentHot)
                TextField("搜索标题、演员、导演或标签", text: $searchDraft)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(CinemaTheme.textPrimary)
                if !searchDraft.isEmpty {
                    Button {
                        searchDraft = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(CinemaTheme.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(CinemaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(CinemaTheme.separator, lineWidth: 1)
            }
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 13) {
            filterRow("类型") {
                filterButton("全部", isSelected: selectedCategory == nil) { selectedCategory = nil }
                ForEach(library.rootCategories) { category in
                    filterButton(category.typeName, isSelected: selectedCategory?.id == category.id) {
                        selectedCategory = category
                    }
                }
            }

            filterRow("标签") {
                filterButton("全部", isSelected: selectedTag == nil) { selectedTag = nil }
                ForEach(library.discoveryIndex.tags.prefix(32), id: \.self) { tag in
                    filterButton(tag, isSelected: selectedTag == tag) { selectedTag = tag }
                }
            }

            filterRow("年份") {
                filterButton("全部", isSelected: selectedYear == nil) { selectedYear = nil }
                ForEach(library.discoveryIndex.years.prefix(12), id: \.self) { year in
                    filterButton(year, isSelected: selectedYear == year) { selectedYear = year }
                }
            }

            filterRow("地区") {
                filterButton("全部", isSelected: selectedArea == nil) { selectedArea = nil }
                ForEach(library.discoveryIndex.areas.prefix(16), id: \.self) { area in
                    filterButton(area, isSelected: selectedArea == area) { selectedArea = area }
                }
            }

            filterRow("语言") {
                filterButton("全部", isSelected: selectedLanguage == nil) { selectedLanguage = nil }
                ForEach(library.discoveryIndex.languages.prefix(12), id: \.self) { language in
                    filterButton(language, isSelected: selectedLanguage == language) { selectedLanguage = language }
                }
            }

            HStack {
                Label("多条件筛选", systemImage: "line.3.horizontal.decrease.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CinemaTheme.textSecondary)
                Spacer()
                Button("清空") {
                    selectedCategory = nil
                    selectedTag = nil
                    selectedYear = nil
                    selectedArea = nil
                    selectedLanguage = nil
                    searchDraft = ""
                }
                .buttonStyle(.borderless)
                .disabled(!hasActiveFilter)
            }
        }
        .padding(14)
        .background(CinemaTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(CinemaTheme.separator, lineWidth: 1)
        }
    }

    private var filteredItems: [VodItem] {
        library.discoveryIndex.filtered(
            keyword: searchDraft,
            category: selectedCategory,
            tag: selectedTag,
            year: selectedYear,
            area: selectedArea,
            language: selectedLanguage
        )
    }

    private var hasActiveFilter: Bool {
        !searchDraft.isEmpty ||
            selectedCategory != nil ||
            selectedTag != nil ||
            selectedYear != nil ||
            selectedArea != nil ||
            selectedLanguage != nil
    }

    private func filterRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(CinemaTheme.textTertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    content()
                }
            }
        }
    }

    private func filterButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .white : CinemaTheme.textSecondary)
        .background(isSelected ? AnyShapeStyle(CinemaTheme.redGradient) : AnyShapeStyle(CinemaTheme.softBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ScheduleBrowserView: View {
    @EnvironmentObject private var library: LibraryViewModel
    let openMovie: (VodItem) -> Void
    let playMovie: (VodItem) -> Void

    @State private var selectedDayID: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("时间表")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(CinemaTheme.textPrimary)
                    Text("基于资源站更新时间生成，缺少精确放送日时自动降级展示")
                        .font(.callout)
                        .foregroundStyle(CinemaTheme.textSecondary)
                }

                dayTabs

                if selectedItems.isEmpty {
                    ContentUnavailableView("暂无更新", systemImage: "calendar", description: Text("当前数据源没有可用的更新时间。"))
                        .foregroundStyle(CinemaTheme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(selectedItems) { item in
                            ScheduleRow(item: item, openMovie: openMovie, playMovie: playMovie)
                        }
                    }
                }

                if !library.discoveryIndex.undatedItems.isEmpty {
                    undatedSection
                }
            }
            .padding(24)
        }
        .background(CinemaTheme.appBackground)
        .onAppear {
            selectedDayID = selectedDayID ?? library.discoveryIndex.scheduleDays.first?.id
        }
        .onChange(of: library.discoveryIndex.scheduleDays.first?.id) { _, firstID in
            if selectedDayID == nil {
                selectedDayID = firstID
            }
        }
    }

    private var dayTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(library.discoveryIndex.scheduleDays.prefix(7)) { day in
                    Button {
                        selectedDayID = day.id
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(day.title)
                                .font(.caption.weight(.bold))
                            Text("\(day.items.count) 部更新")
                                .font(.caption2)
                        }
                        .frame(width: 128, alignment: .leading)
                        .padding(10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedDayID == day.id ? .white : CinemaTheme.textSecondary)
                    .background(selectedDayID == day.id ? AnyShapeStyle(CinemaTheme.redGradient) : AnyShapeStyle(CinemaTheme.elevatedBackground), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var selectedItems: [VodItem] {
        guard let selectedDayID else {
            return library.discoveryIndex.scheduleDays.first?.items ?? []
        }
        return library.discoveryIndex.scheduleDays.first { $0.id == selectedDayID }?.items ?? []
    }

    private var undatedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("未标明时间")
                .font(.title3.weight(.bold))
                .foregroundStyle(CinemaTheme.textPrimary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 168, maximum: 220), spacing: 14)], alignment: .leading, spacing: 14) {
                ForEach(library.discoveryIndex.undatedItems.prefix(10)) { item in
                    DiscoveryGridCard(item: item, openMovie: openMovie, playMovie: playMovie)
                }
            }
        }
    }
}

struct OfflineCacheView: View {
    @EnvironmentObject private var downloads: DownloadManager
    @State private var filter: CacheFilter = .all

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("离线缓存")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(CinemaTheme.textPrimary)
                    Text("当前优先支持直链资源缓存，m3u8 会显示不支持原因")
                        .font(.callout)
                        .foregroundStyle(CinemaTheme.textSecondary)
                }
                Spacer()
                Picker("任务", selection: $filter) {
                    ForEach(CacheFilter.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 360)
            }

            if visibleTasks.isEmpty {
                ContentUnavailableView("暂无缓存任务", systemImage: "arrow.down.circle", description: Text("在详情页或播放器里选择下载后，任务会显示在这里。"))
                    .foregroundStyle(CinemaTheme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(groupedTasks.keys.sorted(), id: \.self) { movieName in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(movieName)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(CinemaTheme.textPrimary)
                                ForEach(groupedTasks[movieName] ?? []) { task in
                                    CacheTaskRow(task: task)
                                }
                            }
                            .padding(14)
                            .background(CinemaTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(CinemaTheme.separator, lineWidth: 1)
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(CinemaTheme.appBackground)
    }

    private var visibleTasks: [DownloadTaskInfo] {
        downloads.tasks.filter { task in
            switch filter {
            case .all:
                return true
            case .active:
                return task.status == .queued || task.status == .downloading || task.status == .paused
            case .finished:
                return task.status == .finished
            case .failed:
                if case .failed = task.status { return true }
                return task.status == .canceled
            }
        }
    }

    private var groupedTasks: [String: [DownloadTaskInfo]] {
        Dictionary(grouping: visibleTasks, by: \.movieName)
    }
}

struct SettingsBrowserView: View {
    @EnvironmentObject private var preferences: UserPreferencesStore
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var watchProgress: WatchProgressStore

    @State private var exportStatus: String?
    @State private var importStatus: String?
    @State private var isShowingSourceManager = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("设置")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(CinemaTheme.textPrimary)

                settingsSection("数据源", systemImage: "server.rack") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(library.activeVideoSource?.name ?? "未配置")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(CinemaTheme.textPrimary)
                            Text(library.activeSourceHealth?.summary ?? "尚未测试当前数据源")
                                .font(.callout)
                                .foregroundStyle(CinemaTheme.textSecondary)
                        }
                        Spacer()
                        Button("管理数据源") {
                            isShowingSourceManager = true
                        }
                    }
                }

                settingsSection("播放器", systemImage: "play.rectangle") {
                    Toggle("自动播放下一集", isOn: $preferences.player.autoplayNextEpisode)
                    HStack {
                        Text("快进/快退")
                        Slider(value: $preferences.player.skipIntervalSeconds, in: 5...60, step: 5)
                        Text("\(Int(preferences.player.skipIntervalSeconds)) 秒")
                            .foregroundStyle(CinemaTheme.textSecondary)
                            .frame(width: 58, alignment: .trailing)
                    }
                }

                settingsSection("弹幕", systemImage: "text.bubble") {
                    Toggle("启用弹幕", isOn: $preferences.danmaku.isEnabled)
                    HStack {
                        Text("字号")
                        Slider(value: $preferences.danmaku.fontSize, in: 12...30, step: 1)
                        Text("\(Int(preferences.danmaku.fontSize))")
                            .frame(width: 42, alignment: .trailing)
                    }
                    HStack {
                        Text("透明度")
                        Slider(value: $preferences.danmaku.opacity, in: 0.2...1, step: 0.05)
                    }
                    HStack {
                        Button("导入本地弹幕文本") { importDanmaku() }
                        Button("清空弹幕") { preferences.resetDanmaku() }
                            .disabled(preferences.danmaku.localMessages.isEmpty)
                        Text("\(preferences.danmaku.localMessages.count) 条")
                            .font(.caption)
                            .foregroundStyle(CinemaTheme.textSecondary)
                    }
                }

                settingsSection("缓存", systemImage: "externaldrive") {
                    Toggle("仅缓存直链资源", isOn: $preferences.cache.directLinksOnly)
                    HStack {
                        Text("缓存上限")
                        Slider(value: $preferences.cache.maxSizeGB, in: 1...50, step: 1)
                        Text("\(Int(preferences.cache.maxSizeGB)) GB")
                            .frame(width: 58, alignment: .trailing)
                    }
                }

                settingsSection("外观", systemImage: "rectangle.inset.filled") {
                    Toggle("紧凑模式", isOn: $preferences.appearance.compactMode)
                }

                settingsSection("本地数据", systemImage: "tray.and.arrow.down") {
                    HStack {
                        Button("导出本地数据") { exportLocalData() }
                        Button("导入本地数据") { importLocalData() }
                        Button(role: .destructive) {
                            watchProgress.removeAll()
                        } label: {
                            Text("清空观看记录")
                        }
                    }
                    if let exportStatus {
                        Text(exportStatus)
                            .font(.caption)
                            .foregroundStyle(CinemaTheme.textSecondary)
                    }
                    if let importStatus {
                        Text(importStatus)
                            .font(.caption)
                            .foregroundStyle(CinemaTheme.textSecondary)
                    }
                }
            }
            .padding(24)
        }
        .background(CinemaTheme.appBackground)
        .sheet(isPresented: $isShowingSourceManager) {
            SourceManagerView()
                .environmentObject(library)
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.bold))
                .foregroundStyle(CinemaTheme.textPrimary)
            content()
        }
        .padding(16)
        .background(CinemaTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(CinemaTheme.separator, lineWidth: 1)
        }
    }

    private func importDanmaku() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK,
              let url = panel.url,
              let text = try? String(contentsOf: url) else {
            return
        }
        preferences.importDanmakuText(text)
    }

    private func exportLocalData() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "xvideo-local-data.json"
        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        let backup = LocalDataBackup(
            favorites: favorites.items,
            watchProgress: watchProgress.items,
            videoSources: library.videoSources,
            activeSourceID: library.activeVideoSourceID
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(backup)
            try data.write(to: url, options: [.atomic])
            exportStatus = "已导出到 \(url.lastPathComponent)"
        } catch {
            exportStatus = "导出失败：\(error.localizedDescription)"
        }
    }

    private func importLocalData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try Data(contentsOf: url)
            let backup = try decoder.decode(LocalDataBackup.self, from: data)
            favorites.replace(with: backup.favorites)
            watchProgress.replace(with: backup.watchProgress)
            Task {
                await library.replaceVideoSources(backup.videoSources, activeSourceID: backup.activeSourceID)
            }
            importStatus = "已导入 \(url.lastPathComponent)"
        } catch {
            importStatus = "导入失败：\(error.localizedDescription)"
        }
    }
}

struct DanmakuOverlayView: View {
    let preferences: DanmakuPreferences

    var body: some View {
        GeometryReader { proxy in
            if preferences.isEnabled {
                if preferences.localMessages.isEmpty {
                    Text("暂无弹幕")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.46), in: Capsule())
                        .position(x: proxy.size.width - 72, y: 34)
                } else {
                    TimelineView(.animation) { timeline in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        ForEach(Array(preferences.localMessages.prefix(8).enumerated()), id: \.offset) { index, message in
                            Text(message)
                                .font(.system(size: preferences.fontSize, weight: .bold))
                                .foregroundStyle(.white.opacity(preferences.opacity))
                                .shadow(color: .black.opacity(0.85), radius: 2, x: 0, y: 1)
                                .lineLimit(1)
                                .position(
                                    x: danmakuX(time: time, width: proxy.size.width, row: index),
                                    y: 34 + CGFloat(index) * min(preferences.fontSize + 8, 34)
                                )
                        }
                    }
                    .frame(height: proxy.size.height * preferences.displayArea, alignment: .top)
                    .clipped()
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func danmakuX(time: TimeInterval, width: CGFloat, row: Int) -> CGFloat {
        let cycle = max(6 / max(preferences.speed, 0.3), 2)
        let phase = (time + Double(row) * 0.8).truncatingRemainder(dividingBy: cycle) / cycle
        return width + 160 - CGFloat(phase) * (width + 320)
    }
}

private struct SummaryPanel: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    let items: [VodItem]
    let openMovie: (VodItem) -> Void
    let playMovie: (VodItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(CinemaTheme.textPrimary)
                Spacer()
                Text(subtitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
            }
            if items.isEmpty {
                Text("暂无更新")
                    .font(.callout)
                    .foregroundStyle(CinemaTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            } else {
                ForEach(items) { item in
                    MiniMediaRow(item: item, openMovie: openMovie, playMovie: playMovie)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(CinemaTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(CinemaTheme.separator, lineWidth: 1)
        }
    }
}

private struct DiscoveryGridCard: View {
    let item: VodItem
    let openMovie: (VodItem) -> Void
    let playMovie: (VodItem) -> Void

    var body: some View {
        Button {
            openMovie(item)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                ZStack(alignment: .bottomLeading) {
                    PosterView(url: item.posterURL, width: 168, height: 238)
                        .frame(maxWidth: .infinity)
                    Text(item.vodRemarks?.nilIfBlank ?? item.typeName?.nilIfBlank ?? "更新")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.72), in: Capsule())
                        .padding(8)
                }
                Text(item.vodName)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(CinemaTheme.textPrimary)
                    .lineLimit(2)
                Text(metadata(for: item))
                    .font(.caption)
                    .foregroundStyle(CinemaTheme.textTertiary)
                    .lineLimit(1)
            }
            .padding(8)
            .background(CinemaTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(CinemaTheme.separator, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("开始播放") { playMovie(item) }
            Button("查看详情") { openMovie(item) }
        }
    }
}

private struct DiscoveryListRow: View {
    let item: VodItem
    let openMovie: (VodItem) -> Void
    let playMovie: (VodItem) -> Void

    var body: some View {
        HStack(spacing: 12) {
            PosterView(url: item.posterURL, width: 74, height: 104)
            VStack(alignment: .leading, spacing: 7) {
                Text(item.vodName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(CinemaTheme.textPrimary)
                    .lineLimit(1)
                Text(metadata(for: item))
                    .font(.callout)
                    .foregroundStyle(CinemaTheme.textSecondary)
                    .lineLimit(1)
                Text(item.summary)
                    .font(.caption)
                    .foregroundStyle(CinemaTheme.textTertiary)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                openMovie(item)
            } label: {
                Label("详情", systemImage: "info.circle")
            }
            Button {
                playMovie(item)
            } label: {
                Label("播放", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(CinemaTheme.accent)
        }
        .padding(12)
        .background(CinemaTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(CinemaTheme.separator, lineWidth: 1)
        }
    }
}

private struct ScheduleRow: View {
    let item: VodItem
    let openMovie: (VodItem) -> Void
    let playMovie: (VodItem) -> Void

    var body: some View {
        HStack(spacing: 12) {
            PosterView(url: item.posterURL, width: 86, height: 122)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(item.vodRemarks?.nilIfBlank ?? "更新")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CinemaTheme.accent, in: Capsule())
                    Text(item.vodTime?.nilIfBlank ?? "未标明时间")
                        .font(.caption)
                        .foregroundStyle(CinemaTheme.textTertiary)
                }
                Text(item.vodName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(CinemaTheme.textPrimary)
                    .lineLimit(2)
                Text(metadata(for: item))
                    .font(.callout)
                    .foregroundStyle(CinemaTheme.textSecondary)
            }
            Spacer()
            Button("详情") { openMovie(item) }
            Button {
                playMovie(item)
            } label: {
                Label("播放", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(CinemaTheme.accent)
        }
        .padding(12)
        .background(CinemaTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(CinemaTheme.separator, lineWidth: 1)
        }
    }
}

private struct MiniMediaRow: View {
    let item: VodItem
    let openMovie: (VodItem) -> Void
    let playMovie: (VodItem) -> Void

    var body: some View {
        HStack(spacing: 10) {
            PosterView(url: item.posterURL, width: 48, height: 68)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.vodName)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(CinemaTheme.textPrimary)
                    .lineLimit(1)
                Text(item.vodRemarks?.nilIfBlank ?? item.vodTime?.nilIfBlank ?? "最近更新")
                    .font(.caption)
                    .foregroundStyle(CinemaTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                playMovie(item)
            } label: {
                Image(systemName: "play.fill")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(CinemaTheme.accent, in: Circle())
            .help("播放")
        }
        .contentShape(Rectangle())
        .onTapGesture {
            openMovie(item)
        }
    }
}

private struct CacheTaskRow: View {
    @EnvironmentObject private var downloads: DownloadManager
    let task: DownloadTaskInfo

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(CinemaTheme.textPrimary)
                    .lineLimit(1)
                ProgressView(value: task.progress)
                    .tint(statusColor)
                Text(task.status.label)
                    .font(.caption)
                    .foregroundStyle(CinemaTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if task.status == .downloading {
                Button("暂停") { downloads.pause(task) }
            } else if task.status == .paused || task.status == .canceled || isFailed {
                Button("重试") { downloads.retry(task) }
            }

            if task.status == .finished {
                Button("显示") { downloads.reveal(task) }
            }

            Button(role: .destructive) {
                downloads.remove(task)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(CinemaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private var isFailed: Bool {
        if case .failed = task.status { return true }
        return false
    }

    private var statusIcon: String {
        switch task.status {
        case .queued:
            return "clock"
        case .downloading:
            return "arrow.down.circle.fill"
        case .paused:
            return "pause.circle.fill"
        case .canceled:
            return "xmark.circle.fill"
        case .finished:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .finished:
            return CinemaTheme.teal
        case .failed, .canceled:
            return CinemaTheme.gold
        case .downloading:
            return CinemaTheme.accentHot
        case .queued, .paused:
            return CinemaTheme.textSecondary
        }
    }
}

private enum DiscoveryLayout: Hashable {
    case grid
    case list
}

private enum CacheFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case finished
    case failed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .active:
            return "下载中"
        case .finished:
            return "已完成"
        case .failed:
            return "失败"
        }
    }
}

private struct LocalDataBackup: Codable {
    let favorites: [FavoriteMovie]
    let watchProgress: [WatchProgressItem]
    let videoSources: [VideoSource]
    let activeSourceID: VideoSource.ID?
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: spacing)], alignment: .leading, spacing: spacing) {
            content
        }
    }
}

private func categoryIcon(for name: String) -> String {
    if name.contains("电影") { return "film" }
    if name.contains("连续") || name.contains("短剧") { return "tv" }
    if name.contains("动漫") { return "sparkles.tv" }
    if name.contains("综艺") { return "person.2.wave.2" }
    if name.contains("体育") { return "sportscourt" }
    return "rectangle.stack"
}

private func metadata(for item: VodItem) -> String {
    [
        item.vodYear,
        item.vodArea,
        item.vodLang,
        item.typeName,
        item.vodClass
    ]
    .compactMap { $0?.nilIfBlank }
    .joined(separator: " · ")
    .nilIfBlank ?? "暂无元数据"
}
