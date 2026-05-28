import SwiftUI

struct SourceManagerView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var homepageURL = ""
    @State private var apiURL = ""
    @State private var format: VideoSourceFormat = .auto
    @State private var isWorking = false
    @State private var statusText: String?
    @State private var statusIsError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            HStack(alignment: .top, spacing: 16) {
                sourceList
                addSourcePanel
            }

            if library.isSwitchingVideoSource || isWorking {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在验证或切换数据源")
                        .font(.caption)
                        .foregroundStyle(CinemaTheme.textSecondary)
                }
            }
        }
        .padding(22)
        .frame(width: 820)
        .background(CinemaTheme.appBackground)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("视频源")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(CinemaTheme.textPrimary)
                Text("添加、测试并切换你自己的视频采集接口")
                    .font(.callout)
                    .foregroundStyle(CinemaTheme.textSecondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 32, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(CinemaTheme.textPrimary)
            .background(CinemaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var sourceList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("已保存资源", systemImage: "server.rack")
                .font(.headline)
                .foregroundStyle(CinemaTheme.textPrimary)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if library.videoSources.isEmpty {
                        emptySourceState
                    } else {
                        ForEach(library.videoSources) { source in
                            sourceRow(source)
                        }
                    }
                }
            }
            .frame(minHeight: 330, maxHeight: 390)
        }
        .padding(14)
        .frame(width: 390)
        .background(CinemaTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(CinemaTheme.separator, lineWidth: 1)
        }
    }

    private var emptySourceState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "plus.rectangle.on.folder")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(CinemaTheme.accentHot)
            Text("还没有保存的视频源")
                .font(.callout.weight(.semibold))
                .foregroundStyle(CinemaTheme.textPrimary)
            Text("Xvideo 不内置任何数据源，请添加你自己的采集接口。")
                .font(.caption)
                .foregroundStyle(CinemaTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CinemaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(CinemaTheme.separator, lineWidth: 1)
        }
    }

    private var addSourcePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("添加资源", systemImage: "plus.circle")
                .font(.headline)
                .foregroundStyle(CinemaTheme.textPrimary)

            TextField("名称", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("网站地址（可选）", text: $homepageURL)
                .textFieldStyle(.roundedBorder)

            TextField("采集接口 URL", text: $apiURL)
                .textFieldStyle(.roundedBorder)

            Picker("格式", selection: $format) {
                ForEach(VideoSourceFormat.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            if let statusText {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusIsError ? Color.red : CinemaTheme.textSecondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(CinemaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
            }

            Spacer(minLength: 8)

            HStack {
                Button {
                    Task { await testSource() }
                } label: {
                    Label("测试", systemImage: "checkmark.seal")
                }
                .disabled(isWorking || apiURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()

                Button {
                    Task { await addSource() }
                } label: {
                    Label("测试并启用", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(CinemaTheme.accent)
                .disabled(
                    isWorking ||
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    apiURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 390)
        .background(CinemaTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(CinemaTheme.separator, lineWidth: 1)
        }
    }

    private func sourceRow(_ source: VideoSource) -> some View {
        let isActive = source.id == library.activeVideoSourceID

        return HStack(spacing: 12) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "server.rack")
                .foregroundStyle(isActive ? CinemaTheme.accentHot : CinemaTheme.textSecondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(source.name)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(CinemaTheme.textPrimary)
                        .lineLimit(1)
                    if source.isBuiltIn {
                        Text("内置")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(CinemaTheme.accent.opacity(0.16), in: Capsule())
                            .foregroundStyle(CinemaTheme.accentHot)
                    }
                }
                Text(source.apiURL.absoluteString)
                    .font(.caption)
                    .foregroundStyle(CinemaTheme.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            if isActive {
                Text("当前")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(CinemaTheme.accentHot)
            } else {
                Button {
                    Task { await library.selectVideoSource(source) }
                } label: {
                    Image(systemName: "play.circle")
                }
                .disabled(library.isSwitchingVideoSource)
                .help("启用")
            }

            if !source.isBuiltIn {
                Button(role: .destructive) {
                    Task { await library.deleteVideoSource(source) }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("删除")
            }
        }
        .padding(10)
        .background(isActive ? CinemaTheme.accent.opacity(0.13) : CinemaTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? CinemaTheme.accent.opacity(0.45) : CinemaTheme.separator, lineWidth: 1)
        }
    }

    private func testSource() async {
        await runSourceAction(clearFormOnSuccess: false) {
            try await library.testVideoSource(
                name: name.isEmpty ? "临时资源" : name,
                homepageURLString: homepageURL,
                apiURLString: apiURL,
                format: format
            )
        }
    }

    private func addSource() async {
        await runSourceAction(clearFormOnSuccess: true) {
            try await library.addVideoSource(
                name: name,
                homepageURLString: homepageURL,
                apiURLString: apiURL,
                format: format
            )
        }
    }

    private func runSourceAction(
        clearFormOnSuccess: Bool,
        action: () async throws -> SourceTestResult
    ) async {
        isWorking = true
        defer { isWorking = false }

        do {
            let result = try await action()
            statusIsError = false
            statusText = "连接成功：\(result.categoryCount) 个分类，\(result.itemCount) 条影片"
            if clearFormOnSuccess {
                name = ""
                homepageURL = ""
                apiURL = ""
                format = .auto
            }
        } catch {
            statusIsError = true
            statusText = error.localizedDescription
        }
    }
}
