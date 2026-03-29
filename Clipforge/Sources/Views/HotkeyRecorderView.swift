import AppKit
import Carbon.HIToolbox
import SwiftUI

struct HotkeyRecorderView: View {
    @Binding var hotkey: HotkeyDescriptor

    @State private var isRecording = false
    @State private var eventMonitor: Any?
    @State private var validationMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button(action: toggleRecording) {
                    HStack(spacing: 8) {
                        Image(systemName: isRecording ? "record.circle.fill" : "keyboard")
                            .foregroundStyle(isRecording ? .red : .secondary)

                        Text(isRecording ? "Press a shortcut…" : hotkey.displayString)
                            .frame(minWidth: 170, alignment: .leading)
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Reset") {
                    hotkey = .default
                    validationMessage = ""
                }
                .buttonStyle(.bordered)
            }

            Text(validationMessage.isEmpty ? helperText : validationMessage)
                .font(.system(size: 11))
                .foregroundStyle(validationMessage.isEmpty ? Color.secondary : Color.orange)
        }
        .onDisappear {
            stopRecording()
        }
    }

    private var helperText: String {
        "Use at least one modifier key. Clipforge updates the global hotkey immediately."
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        isRecording = true
        validationMessage = ""

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }

            guard let descriptor = HotkeyDescriptor(event: event) else {
                validationMessage = "Choose a key combined with Command, Option, Control, or Shift."
                NSSound.beep()
                return nil
            }

            hotkey = descriptor
            validationMessage = ""
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false

        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}
