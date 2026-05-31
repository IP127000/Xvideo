import SwiftUI

struct MediaBrowserView: View {
    @Binding var searchDraft: String
    @Binding var selectedSection: LibrarySection
    let openMovie: (VodItem) -> Void
    let playMovie: () -> Void

    var body: some View {
        Group {
            switch selectedSection {
            case .favorites:
                FavoritesBrowserView(openMovie: openMovie)
            case .home, .category:
                MovieListBrowserView(searchDraft: $searchDraft, openMovie: openMovie, playMovie: playMovie)
            }
        }
        .background(CinemaTheme.appBackground)
    }
}

private struct MovieListBrowserView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var favorites: FavoritesStore
    @Binding var searchDraft: String
    let openMovie: (VodItem) -> Void
    let playMovie: () -> Void

    @State private var isHoveringHeaderMore = false
    @State private var isFilterPanelManuallyOpened = false
    @State private var isAllMoviesSectionActive = false
    @State private var featuredBatchIndex = 0
    @State private var hoveredPreview: HoveredMoviePreview?
    private let featuredMovieLimit = 10

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
                GeometryReader { containerProxy in
                    ZStack(alignment: .topLeading) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 28) {
                                if let spotlightMovie {
                                    SpotlightHero(movie: spotlightMovie, playMovie: playMovie)
                                        .padding(.horizontal, 24)
                                        .padding(.top, 22)
                                }

                                MovieRail(
                                    title: railTitle,
                                    subtitle: "\(railMovies.count) 部正在展示",
                                    movies: railMovies,
                                    selectedMovieID: library.selectedMovie?.id,
                                    canShuffle: featuredCandidates.count > featuredMovieLimit,
                                    shuffleMovies: showNextFeaturedBatch,
                                    openMovie: openMovie,
                                    previewMovie: showHoverPreview,
                                    clearPreview: clearHoverPreview,
                                    playMovie: playMovieFromCard
                                )

                                MoviePosterGrid(
                                    movies: gridMovies,
                                    paginationAnchor: library.movies.last,
                                    isLoading: library.isLoadingList,
                                    selectedMovieID: library.selectedMovie?.id,
                                    openMovie: openMovie,
                                    previewMovie: showHoverPreview,
                                    clearPreview: clearHoverPreview,
                                    playMovie: playMovieFromCard
                                )
                                .padding(.horizontal, 24)

                                if library.isLoadingList {
                                    ProgressView()
                                        .controlSize(.small)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                }
                            }
                            .padding(.bottom, 32)
                        }
                        .coordinateSpace(name: "movieBrowserScroll")
                        .onPreferenceChange(AllMoviesSectionYPreferenceKey.self) { sectionY in
                            guard let sectionY else { return }
                            isAllMoviesSectionActive = sectionY < 180
                        }

                        if let hoveredPreview {
                            MovieHoverDetailCard(movie: hoveredPreview.movie)
                                .frame(width: hoverDetailWidth)
                                .position(hoverDetailPosition(for: hoveredPreview.frame, in: containerProxy.size))
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                .zIndex(100)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .onChange(of: library.movies.first?.id) { _, _ in
                    featuredBatchIndex = 0
                }
                .onChange(of: library.movies.count) { _, _ in
                    clampFeaturedBatchIndex()
                }
                .onChange(of: library.selectedCategory?.id) { _, _ in
                    featuredBatchIndex = 0
                }
            }
        }
        .background(browserBackdrop)
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
                VStack(alignment: .leading, spacing: 5) {
                    Text(library.currentTitle)
                        .font(.system(size: 34, weight: .black, design: .rounded))
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

                Button {
                    Task { await library.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(CinemaTheme.textPrimary)
                .background(CinemaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(CinemaTheme.separator, lineWidth: 1)
                }
                .help("刷新")

                if library.canRequestMoreForCurrentSelection {
                    Button {
                        isFilterPanelManuallyOpened = true
                        Task { await library.openFilterSearch(for: library.selectedCategory) }
                    } label: {
                        MoreFilterLabel()
                            .frame(width: 74, height: 32)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(headerMoreForeground)
                    .background(headerMoreBackground, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(headerMoreBorder, lineWidth: 1)
                    }
                    .onHover { isHoveringHeaderMore = $0 }
                    .help("打开筛选搜索")
                    .disabled(library.isLoadingList)
                    .animation(.easeOut(duration: 0.12), value: isHoveringHeaderMore)
                }
            }

            SearchField(searchDraft: $searchDraft)

            if !library.childCategories.isEmpty {
                ChildCategoryStrip(searchDraft: $searchDraft)
            }

            if shouldShowFilterPanel {
                FilterSearchPanel()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background {
            Rectangle()
                .fill(CinemaTheme.headerBackground)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(CinemaTheme.separator)
                        .frame(height: 1)
                }
        }
    }

    private var spotlightMovie: VodItem? {
        library.selectedMovie ?? library.movies.first
    }

    private var railMovies: [VodItem] {
        guard !featuredCandidates.isEmpty else { return [] }

        let startIndex = min(featuredBatchIndex * featuredMovieLimit, max(featuredCandidates.count - 1, 0))
        let endIndex = min(startIndex + featuredMovieLimit, featuredCandidates.count)
        return Array(featuredCandidates[startIndex..<endIndex])
    }

    private var featuredCandidates: [VodItem] {
        let favoriteIDs = Set(favorites.items.map(\.id))
        return library.movies.enumerated().sorted { lhs, rhs in
            let lhsFavorite = favoriteIDs.contains(lhs.element.id)
            let rhsFavorite = favoriteIDs.contains(rhs.element.id)

            if lhsFavorite != rhsFavorite {
                return lhsFavorite && !rhsFavorite
            }

            return lhs.offset < rhs.offset
        }
        .map(\.element)
    }

    private var gridMovies: [VodItem] {
        let featuredIDs = Set(railMovies.map(\.id))
        return library.movies.filter { !featuredIDs.contains($0.id) }
    }

    private var shouldShowFilterPanel: Bool {
        library.isShowingFilterSearch && (isFilterPanelManuallyOpened || isAllMoviesSectionActive)
    }

    private var railTitle: String {
        "精选影片"
    }

    private func showNextFeaturedBatch() {
        guard featuredCandidates.count > featuredMovieLimit else { return }
        let batchCount = Int(ceil(Double(featuredCandidates.count) / Double(featuredMovieLimit)))
        featuredBatchIndex = (featuredBatchIndex + 1) % batchCount
    }

    private func clampFeaturedBatchIndex() {
        let batchCount = max(Int(ceil(Double(featuredCandidates.count) / Double(featuredMovieLimit))), 1)
        if featuredBatchIndex >= batchCount {
            featuredBatchIndex = 0
        }
    }

    private func playMovieFromCard(_ movie: VodItem) {
        openMovie(movie)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            playMovie()
        }
    }

    private var hoverDetailWidth: CGFloat { 430 }

    private var hoverDetailHeight: CGFloat { 340 }

    private func showHoverPreview(_ movie: VodItem, frame: CGRect) {
        hoveredPreview = HoveredMoviePreview(movie: movie, frame: frame)
    }

    private func clearHoverPreview(_ movie: VodItem) {
        if hoveredPreview?.movie.id == movie.id {
            hoveredPreview = nil
        }
    }

    private func hoverDetailPosition(for frame: CGRect, in size: CGSize) -> CGPoint {
        let margin: CGFloat = 14
        let canOpenRight = frame.maxX + margin + hoverDetailWidth <= size.width
        let x: CGFloat
        if canOpenRight {
            x = frame.maxX + margin + hoverDetailWidth / 2
        } else {
            x = max(hoverDetailWidth / 2 + margin, frame.minX - margin - hoverDetailWidth / 2)
        }

        let minY = hoverDetailHeight / 2 + margin
        let maxY = max(minY, size.height - hoverDetailHeight / 2 - margin)
        let y = min(max(frame.minY + hoverDetailHeight / 2, minY), maxY)
        return CGPoint(x: x, y: y)
    }

    private var browserBackdrop: some View {
        ZStack(alignment: .topTrailing) {
            CinemaTheme.appBackground
            RadialGradient(
                colors: [CinemaTheme.accent.opacity(0.2), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 760
            )
            .allowsHitTesting(false)
            RadialGradient(
                colors: [CinemaTheme.teal.opacity(0.12), .clear],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 620
            )
            .allowsHitTesting(false)
        }
    }

    private var headerMoreBackground: Color {
        guard isHoveringHeaderMore, !library.isLoadingList else {
            return CinemaTheme.elevatedBackground
        }
        return CinemaTheme.accent
    }

    private var headerMoreForeground: Color {
        guard isHoveringHeaderMore, !library.isLoadingList else {
            return CinemaTheme.textPrimary
        }
        return .white
    }

    private var headerMoreBorder: Color {
        guard isHoveringHeaderMore, !library.isLoadingList else {
            return CinemaTheme.separator
        }
        return CinemaTheme.accent.opacity(0.55)
    }

    private var headerSubtitle: String {
        if shouldShowFilterPanel {
            return filterSummary
        }
        if library.isShowingPreview {
            return "大屏浏览模式 · 点击影片在上方查看详情"
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
                    Task { await library.selectCategory(library.selectedCategory) }
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

private struct LoadingStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .tint(CinemaTheme.accentHot)

            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(CinemaTheme.textPrimary)

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(CinemaTheme.textSecondary)
        }
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

private struct SpotlightHero: View {
    let movie: VodItem
    let playMovie: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            heroPoster

            LinearGradient(
                colors: [.black.opacity(0.04), .black.opacity(0.38), .black.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [.black.opacity(0.82), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Badge(text: movie.vodRemarks ?? "最新推荐", color: CinemaTheme.accentHot)
                    Badge(text: "评分 \(movie.scoreText)", color: CinemaTheme.gold)
                    if let typeName = movie.typeName?.nilIfBlank {
                        Badge(text: typeName, color: CinemaTheme.teal)
                    }
                }

                Text(movie.vodName)
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(CinemaTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(metadataText)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(CinemaTheme.textSecondary)
                    .lineLimit(1)

                Text(movie.summary)
                    .font(.body)
                    .foregroundStyle(CinemaTheme.textSecondary)
                    .lineLimit(3)
                    .frame(maxWidth: 620, alignment: .leading)

                Button(action: playMovie) {
                    Label("开始播放", systemImage: "play.fill")
                        .font(.headline.weight(.bold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(CinemaTheme.redGradient, in: RoundedRectangle(cornerRadius: 8))
                .help("进入播放页")
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, minHeight: 360, maxHeight: 420)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.13), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.36), radius: 26, x: 0, y: 18)
    }

    private var heroPoster: some View {
        HStack {
            Spacer()
            PosterView(url: movie.posterURL, width: 270, height: 382)
                .padding(.trailing, 52)
                .rotation3DEffect(.degrees(-4), axis: (x: 0, y: 1, z: 0))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient(
                colors: [
                    CinemaTheme.elevatedBackground,
                    CinemaTheme.accent.opacity(0.28),
                    CinemaTheme.gold.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var metadataText: String {
        [
            movie.vodYear,
            movie.vodArea,
            movie.vodLang,
            movie.vodClass
        ].compactMap { $0?.nilIfBlank }.joined(separator: " · ")
    }
}

private struct MovieRail: View {
    let title: String
    let subtitle: String
    let movies: [VodItem]
    let selectedMovieID: VodItem.ID?
    let canShuffle: Bool
    let shuffleMovies: () -> Void
    let openMovie: (VodItem) -> Void
    let previewMovie: (VodItem, CGRect) -> Void
    let clearPreview: (VodItem) -> Void
    let playMovie: (VodItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title2.weight(.black))
                    .foregroundStyle(CinemaTheme.textPrimary)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(CinemaTheme.textTertiary)
                Spacer()

                Button(action: shuffleMovies) {
                    Label("换一批", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .foregroundStyle(canShuffle ? CinemaTheme.textPrimary : CinemaTheme.textTertiary)
                .background(CinemaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(CinemaTheme.separator, lineWidth: 1)
                }
                .disabled(!canShuffle)
                .help(canShuffle ? "换一批精选影片" : "暂无更多精选影片")
            }
            .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(movies) { movie in
                        MoviePosterCard(
                            movie: movie,
                            isSelected: selectedMovieID == movie.id,
                            width: 150,
                            posterHeight: 214,
                            openMovie: openMovie,
                            previewMovie: previewMovie,
                            clearPreview: clearPreview,
                            playMovie: playMovie
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 4)
            }
        }
    }
}

private struct MoviePosterGrid: View {
    @EnvironmentObject private var library: LibraryViewModel

    let movies: [VodItem]
    let paginationAnchor: VodItem?
    let isLoading: Bool
    let selectedMovieID: VodItem.ID?
    let openMovie: (VodItem) -> Void
    let previewMovie: (VodItem, CGRect) -> Void
    let clearPreview: (VodItem) -> Void
    let playMovie: (VodItem) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 16)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("全部影片")
                .font(.title2.weight(.black))
                .foregroundStyle(CinemaTheme.textPrimary)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: AllMoviesSectionYPreferenceKey.self,
                            value: proxy.frame(in: .named("movieBrowserScroll")).minY
                        )
                    }
                }

            if movies.isEmpty {
                AllMoviesLoadingHint(isLoading: isLoading)
                    .task(id: paginationAnchor?.id) {
                        if let paginationAnchor {
                            await library.loadBrowsableGridPageIfNeeded(current: paginationAnchor)
                        }
                    }
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                    ForEach(movies) { movie in
                        MoviePosterCard(
                            movie: movie,
                            isSelected: selectedMovieID == movie.id,
                            width: nil,
                            posterHeight: 228,
                            openMovie: openMovie,
                            previewMovie: previewMovie,
                            clearPreview: clearPreview,
                            playMovie: playMovie
                        )
                        .task {
                            await library.loadBrowsableGridPageIfNeeded(current: movie)
                        }
                    }
                }
            }
        }
    }
}

private struct AllMoviesLoadingHint: View {
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.down.circle")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(isLoading ? "正在加载全部影片" : "加载全部影片")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(CinemaTheme.textPrimary)
            }

            Spacer()
        }
        .padding(14)
        .background(CinemaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(CinemaTheme.separator, lineWidth: 1)
        }
    }
}

private struct AllMoviesSectionYPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}

private struct MoviePosterCard: View {
    @EnvironmentObject private var favorites: FavoritesStore

    let movie: VodItem
    let isSelected: Bool
    let width: CGFloat?
    let posterHeight: CGFloat
    let openMovie: (VodItem) -> Void
    var previewMovie: ((VodItem, CGRect) -> Void)? = nil
    var clearPreview: ((VodItem) -> Void)? = nil
    var playMovie: ((VodItem) -> Void)? = nil

    @State private var isHovering = false
    @State private var cardFrame = CGRect.zero

    var body: some View {
        Button {
            openMovie(movie)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                ZStack(alignment: .topTrailing) {
                    PosterView(url: movie.posterURL, width: posterWidth, height: posterHeight)
                        .frame(maxWidth: width ?? .infinity)

                    if favorites.isFavorite(movie) {
                        Image(systemName: "heart.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(.pink, in: Circle())
                            .padding(8)
                    }

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.78)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .allowsHitTesting(false)

                    if isHovering {
                        VStack {
                            Spacer()
                            HStack {
                                Label("双击播放", systemImage: "play.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(.black.opacity(0.72), in: Capsule())
                                Spacer()
                            }
                            .padding(10)
                        }
                        .transition(.opacity)
                        .allowsHitTesting(false)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(movie.vodName)
                        .font(.callout.weight(.bold))
                        .foregroundStyle(CinemaTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let remarks = movie.vodRemarks?.nilIfBlank {
                            Text(remarks)
                        }
                        if movie.episodeCount > 1 {
                            Text("\(movie.episodeCount) 集")
                        }
                        if let year = movie.vodYear?.nilIfBlank {
                            Text(year)
                        }
                        if let updateDate = movie.formattedUpdateDate {
                            Text(updateDate)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(CinemaTheme.textTertiary)
                    .lineLimit(1)
                }
            }
            .frame(width: width)
            .padding(8)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? CinemaTheme.accentHot.opacity(0.86) : Color.white.opacity(isHovering ? 0.18 : 0.07), lineWidth: 1)
            }
            .shadow(color: .black.opacity(isHovering ? 0.32 : 0.16), radius: isHovering ? 18 : 10, x: 0, y: isHovering ? 12 : 7)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.025 : 1)
        .zIndex(isHovering ? 50 : 0)
        .background(cardFrameReader)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                playMovie?(movie)
            }
        )
        .onHover { isHovering in
            self.isHovering = isHovering
            if isHovering {
                previewMovie?(movie, cardFrame)
            } else {
                clearPreview?(movie)
            }
        }
        .help(playMovie == nil ? "单击查看详情" : "单击查看详情，双击播放")
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .animation(.easeOut(duration: 0.14), value: isSelected)
    }

    private var cardFrameReader: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named("movieBrowserScroll"))
            Color.clear
                .onAppear {
                    cardFrame = frame
                }
                .onChange(of: frame) { _, newFrame in
                    cardFrame = newFrame
                    if isHovering {
                        previewMovie?(movie, newFrame)
                    }
                }
        }
    }

    private var cardBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [CinemaTheme.accent.opacity(0.24), CinemaTheme.elevatedBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        if isHovering {
            return AnyShapeStyle(CinemaTheme.elevatedBackground)
        }
        return AnyShapeStyle(Color.black.opacity(0.18))
    }

    private var posterWidth: CGFloat {
        width ?? 164
    }

}

private struct HoveredMoviePreview {
    let movie: VodItem
    let frame: CGRect
}

private struct MovieHoverDetailCard: View {
    let movie: VodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(movie.vodName)
                        .font(.title3.weight(.black))
                        .foregroundStyle(CinemaTheme.textPrimary)
                        .lineLimit(2)

                    Text(metadataText)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(CinemaTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Label("双击播放", systemImage: "play.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(CinemaTheme.accent, in: Capsule())
            }

            Text(movie.summary)
                .font(.callout)
                .foregroundStyle(CinemaTheme.textSecondary)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                detailLine(title: "更新", value: updateText)
                detailLine(title: "剧集", value: episodeText)
                detailLine(title: "主演", value: movie.vodActor)
                detailLine(title: "导演", value: movie.vodDirector)
            }
        }
        .padding(18)
        .background(CinemaTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(CinemaTheme.accent.opacity(0.42), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.38), radius: 24, x: 0, y: 16)
    }

    private var metadataText: String {
        [
            movie.vodYear,
            movie.vodArea,
            movie.typeName,
            movie.vodClass
        ].compactMap { $0?.nilIfBlank }
            .joined(separator: " · ")
            .nilIfBlank ?? "暂无元数据"
    }

    private var updateText: String {
        movie.formattedUpdateDate ?? movie.vodTime?.nilIfBlank ?? "暂无"
    }

    private var episodeText: String {
        if movie.episodeCount > 1 {
            return "\(movie.episodeCount) 集"
        }
        return movie.vodRemarks?.nilIfBlank ?? "暂无"
    }

    private func detailLine(title: String, value: String?) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(CinemaTheme.textTertiary)
                .frame(width: 38, alignment: .leading)
            Text(value?.nilIfBlank ?? "暂无")
                .font(.caption)
                .foregroundStyle(CinemaTheme.textSecondary)
                .lineLimit(2)
        }
    }
}

private extension VodItem {
    var episodeCount: Int {
        SourceParser.parsePlaybackSources(from: self)
            .map(\.episodes.count)
            .max() ?? 0
    }

    var formattedUpdateDate: String? {
        guard let raw = vodTime?.nilIfBlank else { return nil }
        let datePart = raw.split(separator: " ").first.map(String.init) ?? raw
        return datePart.replacingOccurrences(of: "/", with: "-")
    }
}

private struct FavoritesBrowserView: View {
    @EnvironmentObject private var favorites: FavoritesStore

    let openMovie: (VodItem) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 158, maximum: 198), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("我的收藏", systemImage: "heart.fill")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(CinemaTheme.textPrimary)

                        Text(favorites.items.isEmpty ? "收藏喜欢的影片后会出现在这里" : "\(favorites.items.count) 部常看内容")
                            .font(.callout)
                            .foregroundStyle(CinemaTheme.textSecondary)
                    }

                    Spacer()
                }

                if favorites.items.isEmpty {
                    ContentUnavailableView("暂无收藏", systemImage: "heart", description: Text("在播放页点击收藏即可加入这里。"))
                        .foregroundStyle(CinemaTheme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                        ForEach(favorites.items) { favorite in
                            MoviePosterCard(
                                movie: favorite.item,
                                isSelected: false,
                                width: nil,
                                posterHeight: 238,
                                openMovie: openMovie
                            )
                        }
                    }
                }
            }
            .padding(24)
        }
        .background {
            ZStack(alignment: .topTrailing) {
                CinemaTheme.appBackground
                RadialGradient(
                    colors: [.pink.opacity(0.16), .clear],
                    center: .topTrailing,
                    startRadius: 40,
                    endRadius: 620
                )
            }
        }
    }
}
