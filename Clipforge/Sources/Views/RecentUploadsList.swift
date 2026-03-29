import SwiftUI

struct RecentUploadsList: View {
    let items: [UploadRecord]
    let onCopy: (UploadRecord) -> Void
    let onOpen: (UploadRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Uploads")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

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
                        ForEach(items) { item in
                            HStack(alignment: .top, spacing: 10) {
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
            }
        }
    }
}
