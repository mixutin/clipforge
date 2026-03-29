import SwiftUI

struct AnnotationEditorView: View {
    @ObservedObject var viewModel: AnnotationEditorViewModel
    let onCancel: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            topBar

            AnnotationCanvasView(viewModel: viewModel)
                .frame(minWidth: 760, minHeight: 500)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            bottomBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Label("Annotate Before Delivery", systemImage: "pencil.and.outline")
                .font(.system(size: 14, weight: .semibold))

            Divider()
                .frame(height: 20)

            HStack(spacing: 8) {
                ForEach(AnnotationTool.allCases) { tool in
                    Button {
                        viewModel.selectedTool = tool
                    } label: {
                        Label(tool.title, systemImage: tool.iconName)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.selectedTool == tool ? .accentColor : .gray.opacity(0.28))
                }
            }

            Divider()
                .frame(height: 20)

            HStack(spacing: 8) {
                ForEach(AnnotationColor.allCases) { color in
                    Button {
                        viewModel.selectedColor = color
                    } label: {
                        Circle()
                            .fill(Color(nsColor: color.color))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        Color.white.opacity(viewModel.selectedColor == color ? 0.95 : 0.28),
                                        lineWidth: viewModel.selectedColor == color ? 2.5 : 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .help(color.title)
                }
            }

            Spacer()

            Button("Undo") {
                viewModel.undo()
            }
            .disabled(!viewModel.canUndo)

            Button("Clear") {
                viewModel.clear()
            }
            .disabled(!viewModel.hasAnnotations)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.regularMaterial)
    }

    private var bottomBar: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Drag to draw on the screenshot.")
                    .font(.system(size: 12, weight: .medium))

                Text("Use Box, Arrow, Highlight, or Pen. Continue keeps your changes, Cancel leaves the capture untouched.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)

            Button("Continue") {
                onContinue()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.thickMaterial)
    }
}
