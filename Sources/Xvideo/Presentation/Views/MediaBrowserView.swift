import SwiftUI

struct MediaBrowserView: View {
    @Binding var searchDraft: String
    @Binding var selectedSection: LibrarySection

    var body: some View {
        VStack(spacing: 0) {
            switch selectedSection {
            case .favorites:
                FavoritesBrowserView()
            case .home, .category:
                MovieListBrowserView(searchDraft: $searchDraft)
            }
        }
        .background(CinemaTheme.appBackground)
    }
}

private struct MovieListBrowserView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @Binding var searchDraft: String

    var body: some View {
        VStack(spacing: 0) {
            browserHeader

            if library.movies.isEmpty && library.isLoadingList {
                LoadingStateView(title: "正在加载片库", subtitle: "优先读取本地缓存，必要时连接数据源")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if library.movies.isEmpty {
                ContentUnavailableView("暂无内容", systemImage: "film.stack", description: Text("可以换个分类或关键词试试。"))
                    .foregroundStyle(CinemaTheme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(library.movies) { item in
                            MovieListCard(
                                item: item,
                                isSelected: library.selectedMovie?.id == item.id
                            ) {
                                Task { await library.selectMovie(item) }
                            }
                            .task {
                                await library.loadNextPageIfNeeded(current: item)
                            }
                        }

                        if library.isLoadingList {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.vertical, 18)
                        }
                    }
                    .padding(14)
                }
            }
        }
        .alert("无法加载", isPresented: Binding(
            get: { library.errorMessage != nil },
            set: { if !$0 { library.errorMessage = nil } }
        )) {
            Button("好") { library.errorMessage = nil }
        } message: {
            Text(library.errorMessage ?? "")
        }
    }

    private var browserHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(library.currentTitle)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(CinemaTheme.textPrimary)
                        .lineLimit(1)

                    Text(headerSubtitle)
                        .font(.callout)
                        .foregroundStyle(CinemaTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if library.isRefreshingPreviewCache {
                    ProgressView()
                        .controlSize(.small)
                        .help("正在更新本地预览")
                }

                if library.canRequestMoreForCurrentSelection {
                    Button {
                        Task { await library.openFilterSearch(for: library.selectedCategory) }
                    } label: {
                        MoreFilterLabel()
                            .frame(width: 74, height: 32)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(CinemaTheme.textPrimary)
                    .background(CinemaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(CinemaTheme.separator, lineWidth: 1)
                    }
                    .help("打开筛选搜索")
                    .disabled(library.isLoadingList)
                }
            }

            SearchField(searchDraft: $searchDraft)

            if !library.childCategories.isEmpty {
                ChildCategoryStrip(searchDraft: $searchDraft)
            }

            if library.isShowingFilterSearch {
                FilterSearchPanel()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .background {
            Rectangle()
                .fill(CinemaTheme.panelBackground)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(CinemaTheme.separator)
                        .frame(height: 1)
                }
        }
    }

    private var headerSubtitle: String {
        if library.isShowingFilterSearch {
            return filterSummary
        }
        if library.isShowingPreview {
            return "每个分类优先展示本地预览，继续下拉会加载更多"
        }
        return "\(library.total) 条结果"
    }

    private var filterSummary: String {
        let parts = [
            library.filterCategory?.typeName,
            library.filterYear.nilIfBlank,
            library.filterArea.nilIfBlank
        ].compactMap { $0 }
        return parts.isEmpty ? "筛选搜索" : parts.joined(separator: " · ")
    }
}

private struct SearchField: View {
    @EnvironmentObject private var library: LibraryViewModel
    @Binding var searchDraft: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(isFocused ? CinemaTheme.accentHot : CinemaTheme.textSecondary)

            TextField("搜索影片、演员或关键词", text: $searchDraft)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .font(.callout)
                .foregroundStyle(CinemaTheme.textPrimary)
                .onSubmit {
                    library.searchText = searchDraft
                    Task { await library.search() }
                }

            if !searchDraft.isEmpty {
                Button {
                    searchDraft = ""
                    library.searchText = ""
                    Task { await library.refresh() }
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
                .stroke(isFocused ? CinemaTheme.accent.opacity(0.7) : CinemaTheme.separator, lineWidth: 1)
        }
        .animation(.easeOut(duration: 0.12), value: isFocused)
    }
}

private struct ChildCategoryStrip: View {
    @EnvironmentObject private var library: LibraryViewModel
    @Binding var searchDraft: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(library.childCategories) { category in
                    ChildCategoryControl(
                        category: category,
                        isSelected: library.selectedCategory?.id == category.id
                    ) {
                        searchDraft = ""
                        Task { await library.selectCategory(category) }
                    } openFilter: {
                        searchDraft = ""
                        Task { await library.openFilterSearch(for: category) }
                    }
                }
            }
        }
    }
}

private struct ChildCategoryControl: View {
    let category: VodCategory
    let isSelected: Bool
    let selectCategory: () -> Void
    let openFilter: () -> Void

    @State private var isHoveringTitle = false
    @State private var isHoveringFilter = false

    var body: some View {
        HStack(spacing: 0) {
            Button(action: selectCategory) {
                Text(category.typeName)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(isSelected ? .white : CinemaTheme.textPrimary)
            .background(titleBackground)
            .onHover { isHoveringTitle = $0 }

            Rectangle()
                .fill(isSelected ? .white.opacity(0.2) : CinemaTheme.separator)
                .frame(width: 1, height: 22)

            Button(action: openFilter) {
                MoreFilterLabel()
                    .frame(width: 68, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(filterForeground)
            .background(filterBackground)
            .onHover { isHoveringFilter = $0 }
            .help("打开\(category.typeName)筛选搜索")
        }
        .background(containerBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? .white.opacity(0.12) : CinemaTheme.separator, lineWidth: 1)
        }
        .animation(.easeOut(duration: 0.12), value: isHoveringTitle)
        .animation(.easeOut(duration: 0.12), value: isHoveringFilter)
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }

    private var containerBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(CinemaTheme.redGradient)
        }
        return AnyShapeStyle(CinemaTheme.elevatedBackground)
    }

    private var titleBackground: Color {
        if isHoveringTitle {
            return isSelected ? .white.opacity(0.12) : CinemaTheme.softBackground
        }
        return .clear
    }

    private var filterBackground: Color {
        if isHoveringFilter {
            return isSelected ? .white.opacity(0.2) : CinemaTheme.accent
        }
        return isSelected ? .clear : CinemaTheme.softBackground
    }

    private var filterForeground: Color {
        if isSelected || isHoveringFilter {
            return .white
        }
        return CinemaTheme.textSecondary
    }
}

private struct FilterSearchPanel: View {
    @EnvironmentObject private var library: LibraryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            filterRow(title: "类型") {
                ForEach(library.filterCategories) { category in
                    filterButton(
                        title: category.typeName,
                        isSelected: library.filterCategory?.id == category.id
                    ) {
                        Task { await library.updateFilterCategory(category) }
                    }
                }
            }

            filterRow(title: "时间") {
                ForEach(library.filterYears, id: \.self) { year in
                    filterButton(
                        title: year.isEmpty ? "全部" : year,
                        isSelected: library.filterYear == year
                    ) {
                        Task { await library.updateFilterYear(year) }
                    }
                }
            }

            filterRow(title: "地区") {
                ForEach(library.filterAreas, id: \.self) { area in
                    filterButton(
                        title: area.isEmpty ? "全部" : area,
                        isSelected: library.filterArea == area
                    ) {
                        Task { await library.updateFilterArea(area) }
                    }
                }
            }

            HStack {
                Label("高级筛选", systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CinemaTheme.textSecondary)
                Spacer()
                Button("重置") {
                    Task { await library.resetFilters() }
                }
                .buttonStyle(.borderless)
                .disabled(library.filterYear.isEmpty && library.filterArea.isEmpty)
            }
        }
        .padding(12)
        .background(CinemaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(CinemaTheme.separator, lineWidth: 1)
        }
    }

    private func filterRow<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
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

    private func filterButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .frame(minWidth: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : CinemaTheme.textSecondary)
        .background(isSelected ? AnyShapeStyle(CinemaTheme.redGradient) : AnyShapeStyle(CinemaTheme.softBackground), in: Capsule())
        .overlay {
            Capsule()
                .stroke(isSelected ? Color.white.opacity(0.12) : CinemaTheme.separator, lineWidth: 1)
        }
    }
}

private struct MovieListCard: View {
    @EnvironmentObject private var favorites: FavoritesStore

    let item: VodItem
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                PosterView(url: item.posterURL, width: 70, height: 100)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Text(item.vodName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(CinemaTheme.textPrimary)
                            .lineLimit(1)

                        if favorites.isFavorite(item) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                                .font(.caption)
                        }
                    }

                    HStack(spacing: 6) {
                        if let remarks = item.vodRemarks?.nilIfBlank {
                            Badge(text: remarks, color: CinemaTheme.blue)
                        }
                        if let typeName = item.typeName?.nilIfBlank {
                            Text(typeName)
                        }
                        if let year = item.vodYear?.nilIfBlank {
                            Text(year)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(CinemaTheme.textSecondary)
                    .lineLimit(1)

                    Text(item.vodTime?.nilIfBlank ?? "等待加载")
                        .font(.caption2)
                        .foregroundStyle(CinemaTheme.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? .white : CinemaTheme.textTertiary)
            }
            .padding(10)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? CinemaTheme.accent.opacity(0.8) : CinemaTheme.separator, lineWidth: 1)
        }
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }

    private var background: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [CinemaTheme.accent.opacity(0.28), CinemaTheme.elevatedBackground],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        if isHovering {
            return AnyShapeStyle(CinemaTheme.elevatedBackground)
        }
        return AnyShapeStyle(CinemaTheme.panelBackground)
    }
}

private struct FavoritesBrowserView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var favorites: FavoritesStore

    private let columns = [
        GridItem(.adaptive(minimum: 142, maximum: 182), spacing: 14)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("我的收藏", systemImage: "heart.fill")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(CinemaTheme.textPrimary)
                    Spacer()
                    Text("\(favorites.items.count) 部")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(CinemaTheme.textSecondary)
                }

                Text("收藏会保留影片信息和海报，点击即可在右侧继续观看")
                    .font(.callout)
                    .foregroundStyle(CinemaTheme.textSecondary)
            }
            .padding(18)
            .background(CinemaTheme.panelBackground)

            if favorites.items.isEmpty {
                ContentUnavailableView("暂无收藏", systemImage: "heart", description: Text("在详情页点击收藏后会显示在这里。"))
                    .foregroundStyle(CinemaTheme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(favorites.items) { favorite in
                            FavoritePosterCard(favorite: favorite) {
                                Task { await library.selectMovie(favorite.item) }
                            }
                        }
                    }
                    .padding(14)
                }
            }
        }
        .task(id: favorites.items.map(\.id)) {
            await library.cachePosters(for: favorites.items.map(\.item))
        }
    }
}

private struct FavoritePosterCard: View {
    @EnvironmentObject private var favorites: FavoritesStore

    let favorite: FavoriteMovie
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                PosterView(url: favorite.item.posterURL, width: 142, height: 202)
                    .frame(maxWidth: .infinity)

                Text(favorite.item.vodName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(CinemaTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    if let remarks = favorite.item.vodRemarks?.nilIfBlank {
                        Text(remarks)
                    }
                    if let year = favorite.item.vodYear?.nilIfBlank {
                        Text(year)
                    }
                }
                .font(.caption)
                .foregroundStyle(CinemaTheme.textSecondary)
                .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(isHovering ? CinemaTheme.elevatedBackground : CinemaTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(CinemaTheme.separator, lineWidth: 1)
        }
        .contextMenu {
            Button("取消收藏", role: .destructive) {
                favorites.toggle(favorite.item)
            }
        }
        .onHover { isHovering = $0 }
    }
}

private struct LoadingStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text(title)
                .font(.headline)
                .foregroundStyle(CinemaTheme.textPrimary)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(CinemaTheme.textSecondary)
        }
    }
}
