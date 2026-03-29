import AppKit
import Foundation

@MainActor
final class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()

    @Published private(set) var hasUploadableImage = false

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount

    private init() {
        refresh()
    }

    func start() {
        refresh()

        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }

        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let changeCount = NSPasteboard.general.changeCount
        guard changeCount != lastChangeCount else { return }

        lastChangeCount = changeCount
        refresh()
    }

    private func refresh() {
        lastChangeCount = NSPasteboard.general.changeCount
        hasUploadableImage = ClipboardService.shared.containsUploadableImage()
    }
}
