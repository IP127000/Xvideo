import SwiftUI

struct CinematicSidebarView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var watchProgress: WatchProgressStore
    @EnvironmentObject private var downloads: DownloadManager

    @Binding var searchDraft: String
    @Binding var selectedSection: LibrarySection
    @State private var isShowingSourceManager = false
    @State private var isHoveringSourceSettings = false

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    navigationSection
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 18)
            }

            sourceFooter
        }
        .background {
            ZStack(alignment: .topLeading) {
                CinemaTheme.sidebarBackground
                RadialGradient(
                    colors: [CinemaTheme.accent.opacity(0.26), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 360
                )
                .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $isShowingSourceManager) {
            SourceManagerView()
                .environmentObject(library)
        }
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(CinemaTheme.redGradient)
                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Xvideo")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(CinemaTheme.textPrimary)
                    Text("找番 · 追番 · 看番")
                        .font(.caption)
                        .foregroundStyle(CinemaTheme.textSecondary)
                }
            }

            HStack(spacing: 8) {
                MetricPill(value: "\(library.total)", title: "资源")
                MetricPill(value: "\(favorites.items.count)", title: "收藏")
                MetricPill(value: "\(watchProgress.items.count)", title: "追番")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    private var navigationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SidebarSectionTitle("媒体库")

            SidebarNavButton(
                title: "首页",
                subtitle: library.isRefreshingPreviewCache ? "正在更新本地缓存" : "继续观看和最近更新",
                systemImage: "house.fill",
                isSelected: selectedSection == .home
            ) {
                selectedSection = .home
                searchDraft = ""
                Task { await library.selectCategory(nil) }
            }

            SidebarNavButton(
                title: "找番",
                subtitle: library.discoveryIndex.tags.isEmpty ? "搜索和标签筛选" : "\(library.discoveryIndex.tags.count) 个标签",
                systemImage: "magnifyingglass.circle.fill",
                isSelected: selectedSection == .discovery
            ) {
                selectedSection = .discovery
                searchDraft = ""
            }

            SidebarNavButton(
                title: "时间表",
                subtitle: library.discoveryIndex.scheduleDays.first?.title ?? "按更新日期查看",
                systemImage: "calendar",
                isSelected: selectedSection == .schedule
            ) {
                selectedSection = .schedule
                searchDraft = ""
            }

            SidebarNavButton(
                title: "继续观看",
                subtitle: watchProgress.items.first?.positionLabel ?? "播放后自动记录",
                systemImage: "play.circle.fill",
                isSelected: selectedSection == .continueWatching
            ) {
                selectedSection = .continueWatching
                searchDraft = ""
            }

            SidebarNavButton(
                title: "我的收藏",
                subtitle: favorites.items.isEmpty ? "还没有收藏" : "\(favorites.items.count) 部影片",
                systemImage: "heart.fill",
                isSelected: selectedSection == .favorites
            ) {
                selectedSection = .favorites
                searchDraft = ""
                Task { await library.showFavorites(favorites.items) }
            }

            SidebarNavButton(
                title: "离线缓存",
                subtitle: downloads.tasks.isEmpty ? "管理下载任务" : "\(downloads.tasks.count) 个任务",
                systemImage: "arrow.down.circle.fill",
                isSelected: selectedSection == .offlineCache
            ) {
                selectedSection = .offlineCache
                searchDraft = ""
            }

            SidebarNavButton(
                title: "设置",
                subtitle: "数据源、播放器、弹幕",
                systemImage: "gearshape.fill",
                isSelected: selectedSection == .settings
            ) {
                selectedSection = .settings
                searchDraft = ""
            }
        }
    }

    private var sourceFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .overlay(CinemaTheme.separator)

            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(CinemaTheme.softBackground)
                    Image(systemName: "server.rack")
                        .foregroundStyle(CinemaTheme.gold)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(library.activeVideoSource?.name ?? "未配置视频源")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(CinemaTheme.textPrimary)
                        .lineLimit(1)
                    Text(sourceFooterSubtitle)
                        .font(.caption2)
                        .foregroundStyle(CinemaTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    isShowingSourceManager = true
                } label: {
                    Label("配置源", systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.bold))
                        .frame(height: 30)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(sourceSettingsForeground)
                .background(sourceSettingsBackground, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(sourceSettingsBorder, lineWidth: 1)
                }
                .onHover { isHoveringSourceSettings = $0 }
                .help("管理视频源")
                .animation(.easeOut(duration: 0.12), value: isHoveringSourceSettings)
            }
        }
        .padding(14)
        .background(.black.opacity(0.16))
    }

    private var sourceFooterSubtitle: String {
        guard let source = library.activeVideoSource else {
            return "添加自己的接口"
        }
        if let health = library.activeSourceHealth {
            return health.isHealthy ? "\(source.format.title) · \(health.itemCount) 条" : "连接失败"
        }
        return "\(source.format.title) 数据源 · 待测试"
    }

    private var sourceSettingsBackground: some ShapeStyle {
        if isHoveringSourceSettings {
            return AnyShapeStyle(CinemaTheme.accent)
        }
        return AnyShapeStyle(CinemaTheme.glassGradient)
    }

    private var sourceSettingsForeground: Color {
        isHoveringSourceSettings ? .white : CinemaTheme.textPrimary
    }

    private var sourceSettingsBorder: Color {
        isHoveringSourceSettings ? CinemaTheme.accent.opacity(0.55) : CinemaTheme.separator
    }

}

private struct SidebarSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(CinemaTheme.textTertiary)
            .textCase(.uppercase)
            .padding(.horizontal, 8)
    }
}

private struct MetricPill: View {
    let value: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(CinemaTheme.textPrimary)
                .lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(CinemaTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(CinemaTheme.glassGradient, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(CinemaTheme.separator, lineWidth: 1)
        }
    }
}

private struct SidebarNavButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? .white : CinemaTheme.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(CinemaTheme.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.72) : CinemaTheme.textTertiary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.12) : Color.clear, lineWidth: 1)
        }
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }

    private var background: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(CinemaTheme.redGradient)
        }
        if isHovering {
            return AnyShapeStyle(CinemaTheme.elevatedBackground)
        }
        return AnyShapeStyle(Color.clear)
    }
}

private struct CategorySidebarRow: View {
    let category: VodCategory
    let isSelected: Bool
    let systemImage: String
    let selectCategory: () -> Void
    let openFilter: () -> Void

    @State private var isHoveringTitle = false
    @State private var isHoveringFilter = false

    var body: some View {
        HStack(spacing: 0) {
            Button(action: selectCategory) {
                HStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 19)
                    Text(category.typeName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.leading, 10)
                .padding(.trailing, 8)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(titleForeground)
            .background(titleBackground)
            .onHover { isHoveringTitle = $0 }

            Rectangle()
                .fill(separatorColor)
                .frame(width: 1, height: 24)

            Button(action: openFilter) {
                MoreFilterLabel()
                    .frame(width: 68, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(filterForeground)
            .background(filterBackground)
            .onHover { isHoveringFilter = $0 }
            .help("打开\(category.typeName)筛选搜索")
        }
        .frame(maxWidth: .infinity)
        .background(containerBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(containerBorder, lineWidth: 1)
        }
        .animation(.easeOut(duration: 0.12), value: isHoveringTitle)
        .animation(.easeOut(duration: 0.12), value: isHoveringFilter)
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }

    private var containerBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(CinemaTheme.redGradient)
        }
        return AnyShapeStyle(CinemaTheme.panelBackground.opacity(0.48))
    }

    private var titleBackground: Color {
        if isHoveringTitle {
            return isSelected ? .white.opacity(0.12) : CinemaTheme.elevatedBackground
        }
        return .clear
    }

    private var titleForeground: Color {
        isSelected ? .white : CinemaTheme.textPrimary
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

    private var separatorColor: Color {
        isSelected ? .white.opacity(0.2) : CinemaTheme.separator
    }

    private var containerBorder: Color {
        if isSelected {
            return .white.opacity(0.12)
        }
        if isHoveringTitle || isHoveringFilter {
            return CinemaTheme.accent.opacity(0.45)
        }
        return .clear
    }
}
