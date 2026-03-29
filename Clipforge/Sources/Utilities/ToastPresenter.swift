import AppKit
import SwiftUI

@MainActor
final class ToastPresenter {
    static let shared = ToastPresenter()

    private var windowController: ToastWindowController?

    private init() {}

    func showSuccess(
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        show(
            payload: ToastPayload(
                style: .success,
                title: title,
                message: message,
                actionTitle: actionTitle,
                action: action,
                secondaryActionTitle: secondaryActionTitle,
                secondaryAction: secondaryAction
            )
        )
    }

    func showError(
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        show(
            payload: ToastPayload(
                style: .error,
                title: title,
                message: message,
                actionTitle: actionTitle,
                action: action,
                secondaryActionTitle: secondaryActionTitle,
                secondaryAction: secondaryAction
            )
        )
    }

    private func show(payload: ToastPayload) {
        windowController?.dismiss(immediately: true)
        let controller = ToastWindowController(payload: payload)
        windowController = controller
        controller.show()
    }
}

private struct ToastPayload {
    struct Action {
        let title: String
        let handler: () -> Void
    }

    enum Style {
        case success
        case error

        var iconName: String {
            switch self {
            case .success:
                return "checkmark.circle.fill"
            case .error:
                return "exclamationmark.triangle.fill"
            }
        }

        var iconColor: Color {
            switch self {
            case .success:
                return .green
            case .error:
                return .orange
            }
        }

        var borderColor: Color {
            switch self {
            case .success:
                return .green
            case .error:
                return .orange
            }
        }
    }

    let style: Style
    let title: String
    let message: String
    let actions: [Action]

    init(
        style: Style,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.style = style
        self.title = title
        self.message = message

        var actions: [Action] = []
        if let actionTitle, let action {
            actions.append(Action(title: actionTitle, handler: action))
        }
        if let secondaryActionTitle, let secondaryAction {
            actions.append(Action(title: secondaryActionTitle, handler: secondaryAction))
        }
        self.actions = actions
    }
}

@MainActor
private final class ToastWindowController: NSWindowController {
    private var dismissalWorkItem: DispatchWorkItem?
    private let payload: ToastPayload

    init(payload: ToastPayload) {
        self.payload = payload

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 132),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let hostingController = NSHostingController(
            rootView: ToastView(
                payload: payload,
                onAction: { [weak panel] action in
                    action.handler()
                    panel?.close()
                },
                onClose: { [weak panel] in
                    panel?.close()
                }
            )
        )
        panel.contentViewController = hostingController

        super.init(window: panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let panel = window else { return }

        let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        if let visibleFrame = screen?.visibleFrame {
            let origin = NSPoint(
                x: visibleFrame.maxX - panel.frame.width - 20,
                y: visibleFrame.maxY - panel.frame.height - 20
            )
            panel.setFrameOrigin(origin)
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }
        dismissalWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8, execute: workItem)
    }

    func dismiss(immediately: Bool = false) {
        dismissalWorkItem?.cancel()
        dismissalWorkItem = nil

        guard let panel = window else { return }

        guard immediately == false else {
            panel.orderOut(nil)
            panel.close()
            return
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            panel.animator().alphaValue = 0
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            panel.orderOut(nil)
            panel.close()
        }
    }
}

private struct ToastView: View {
    let payload: ToastPayload
    let onAction: (ToastPayload.Action) -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: payload.style.iconName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(payload.style.iconColor)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(payload.title)
                    .font(.system(size: 14, weight: .semibold))

                Text(payload.message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if payload.actions.isEmpty == false {
                    HStack(spacing: 12) {
                        ForEach(Array(payload.actions.enumerated()), id: \.offset) { _, action in
                            Button(action.title) {
                                onAction(action)
                            }
                            .buttonStyle(.link)
                        }
                    }
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 360)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(payload.style.borderColor.opacity(0.35), lineWidth: 1)
        )
    }
}
