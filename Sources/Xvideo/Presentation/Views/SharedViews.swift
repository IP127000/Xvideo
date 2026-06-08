import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct PosterView: View {
    @EnvironmentObject private var library: LibraryViewModel

    let url: URL?
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Group {
            if let localURL = library.cachedPosterFileURL(for: url),
               let image = platformImage(from: localURL) {
                image
                    .resizable()
                    .scaledToFill()
            } else if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        posterPlaceholder
                    }
                }
            } else {
                posterPlaceholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 8)
    }

    private var posterPlaceholder: some View {
        ZStack {
            Rectangle()
                .fill(CinemaTheme.softBackground)
            Image(systemName: "film")
                .font(.title)
                .foregroundStyle(CinemaTheme.textTertiary)
        }
    }

    private func platformImage(from localURL: URL) -> Image? {
        #if os(macOS)
        guard let image = NSImage(contentsOf: localURL) else { return nil }
        return Image(nsImage: image)
        #elseif os(iOS)
        guard let image = UIImage(contentsOfFile: localURL.path) else { return nil }
        return Image(uiImage: image)
        #endif
    }
}

struct Badge: View {
    let text: String
    var color: Color = CinemaTheme.accent

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}

struct MoreFilterLabel: View {
    var body: some View {
        Label("More", systemImage: "line.3.horizontal.decrease")
            .font(.caption.weight(.bold))
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
    }
}

struct DownloadShelfView: View {
    @EnvironmentObject private var downloads: DownloadManager

    var body: some View {
        if !downloads.tasks.isEmpty {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Label("下载", systemImage: "arrow.down.circle")
                        .font(.headline)
                        .foregroundStyle(CinemaTheme.textPrimary)
                    Spacer()
                    Text("\(downloads.tasks.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(CinemaTheme.textSecondary)
                }

                ForEach(downloads.tasks.prefix(3)) { task in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(task.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(CinemaTheme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            if task.status == .finished {
                                #if os(macOS)
                                Button("显示") {
                                    downloads.reveal(task)
                                }
                                .buttonStyle(.borderless)
                                #else
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(CinemaTheme.teal)
                                #endif
                            }
                        }
                        ProgressView(value: task.progress)
                            .tint(CinemaTheme.accent)
                        Text(task.status.label)
                            .font(.caption2)
                            .foregroundStyle(CinemaTheme.textSecondary)
                    }
                }
            }
            .padding(14)
            .frame(width: 330)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(CinemaTheme.separator, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.32), radius: 22, y: 12)
        }
    }
}
