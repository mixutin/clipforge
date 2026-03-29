import SwiftUI
import AppKit

struct RecentUploadsList: View {
    let items: [UploadRecord]
    let previewLimit: Int
    let onCopy: (UploadRecord) -> Void
    let onCopyRecognizedText: (UploadRecord) -> Void
    let onOpen: (UploadRecord) -> Void
    let onShowHistory: () -> Void

    private var displayItems: [UploadRecord] {
        Array(items.prefix(previewLimit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Uploads")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button("View All") {
                    onShowHistory()
                }
                .buttonStyle(.link)
                .font(.system(size: 11))

                Text("\(items.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if items.isEmpty {
                Text("Uploads will appear here once Clipforge finishes one successfully.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(displayItems) { item in
                            HStack(alignment: .top, spacing: 10) {
                                UploadThumbnailView(data: item.thumbnailPNGData, mediaKind: item.mediaKind)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.localFilename)
                                        .font(.system(size: 12, weight: .medium))

                                    Text(item.remoteURL)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                }

                                Spacer(minLength: 0)

                                HStack(spacing: 6) {
                                    Button("Copy") {
                                        onCopy(item)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)

                                    if item.hasRecognizedText {
                                        Button("Text") {
                                            onCopyRecognizedText(item)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }

                                    Button("Open") {
                                        onOpen(item)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.primary.opacity(0.04))
                            )
                        }
                    }
                }
                .frame(maxHeight: 170)

                if items.count > displayItems.count {
                    Text("Showing the latest \(displayItems.count) uploads here. Open Upload History to search everything saved locally.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct UploadThumbnailView: View {
    let data: Data?
    let mediaKind: UploadRecord.MediaKind

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let data, let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.07))

                        Image(systemName: mediaKind == .video ? "video" : "photo")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if mediaKind == .video {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white, .black.opacity(0.45))
                    .padding(4)
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
