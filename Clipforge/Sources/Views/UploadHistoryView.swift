import AppKit
import SwiftUI

struct UploadHistoryView: View {
    @EnvironmentObject private var appController: AppController
    @State private var searchText = ""

    private var filteredUploads: [UploadRecord] {
        UploadHistoryFilter.filter(appController.recentUploads, query: searchText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if appController.recentUploads.isEmpty {
                emptyState(
                    title: "No uploads yet",
                    message: "Uploaded images will appear here once Clipforge finishes a successful upload."
                )
            } else if filteredUploads.isEmpty {
                emptyState(
                    title: "No matches",
                    message: "Try a different filename, URL fragment, or date."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredUploads) { item in
                            historyRow(for: item)
                        }
                    }
                    .padding(.trailing, 2)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 560)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.accentColor.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Upload History")
                        .font(.system(size: 24, weight: .bold))

                    Text(headerSubtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search filename, URL, or date", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )

                if searchText.isEmpty == false {
                    Button("Clear") {
                        searchText = ""
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var headerSubtitle: String {
        if searchText.isEmpty {
            return "\(appController.recentUploads.count) uploads saved locally for quick lookup."
        }

        return "Showing \(filteredUploads.count) of \(appController.recentUploads.count) uploads."
    }

    private func historyRow(for item: UploadRecord) -> some View {
        HStack(alignment: .top, spacing: 14) {
            HistoryThumbnailView(data: item.thumbnailPNGData)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.localFilename)
                    .font(.system(size: 14, weight: .semibold))
                    .textSelection(.enabled)

                Text(item.remoteURL)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button("Copy") {
                    appController.copyUploadContent(item)
                }
                .buttonStyle(.bordered)

                Button("Open") {
                    appController.openUpload(item)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.small)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func emptyState(title: String, message: String) -> some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(size: 18, weight: .semibold))

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 30)
    }
}

private struct HistoryThumbnailView: View {
    let data: Data?

    var body: some View {
        Group {
            if let data, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.07))

                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 74, height: 74)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
