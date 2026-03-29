import SwiftUI

struct ScrollCaptureView: View {
    @ObservedObject var state: ScrollCaptureSessionState
    let onCaptureNext: () -> Void
    let onUndoLast: () -> Void
    let onFinish: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Scroll Capture")
                    .font(.system(size: 22, weight: .bold))

                Text("Capture a long page by scrolling the active window a bit at a time. Clipforge will stitch the frames into one tall image.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("Start with the first section visible in the frontmost app window.", systemImage: "1.circle.fill")
                Label("Scroll down by about two thirds so some content still overlaps.", systemImage: "2.circle.fill")
                Label("Press Capture Next until you reach the end, then finish stitching.", systemImage: "3.circle.fill")
            }
            .font(.system(size: 12.5))
            .foregroundStyle(.secondary)

            HStack {
                Text("Captured sections")
                    .font(.system(size: 12, weight: .semibold))

                Spacer()

                Text("\(state.frameCount)")
                    .font(.system(size: 22, weight: .bold))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
            )

            HStack(spacing: 10) {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button("Undo Last", action: onUndoLast)
                    .disabled(state.frameCount <= 1 || state.isCapturing)

                Spacer()

                Button(state.isCapturing ? "Capturing…" : "Capture Next") {
                    onCaptureNext()
                }
                .disabled(state.isCapturing)

                Button("Finish & Stitch") {
                    onFinish()
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.isCapturing)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
