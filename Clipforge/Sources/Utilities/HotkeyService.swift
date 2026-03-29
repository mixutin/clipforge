import Carbon.HIToolbox
import AppKit
import Foundation
import os

struct HotkeyDescriptor: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    static let `default` = HotkeyDescriptor(
        keyCode: UInt32(kVK_ANSI_6),
        modifiers: UInt32(cmdKey | shiftKey)
    )

    init?(event: NSEvent) {
        let allowedFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let modifiers = HotkeyDescriptor.carbonModifiers(from: allowedFlags)
        let keyCode = UInt32(event.keyCode)

        guard modifiers != 0, HotkeyDescriptor.modifierOnlyKeyCodes.contains(keyCode) == false else {
            return nil
        }

        self.init(keyCode: keyCode, modifiers: modifiers)
    }

    var displayString: String {
        var parts: [String] = []

        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("Command")
        }
        if modifiers & UInt32(optionKey) != 0 {
            parts.append("Option")
        }
        if modifiers & UInt32(controlKey) != 0 {
            parts.append("Control")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("Shift")
        }

        parts.append(keyLabel(for: keyCode))
        return parts.joined(separator: " + ")
    }

    private func keyLabel(for keyCode: UInt32) -> String {
        switch keyCode {
        case UInt32(kVK_ANSI_A): return "A"
        case UInt32(kVK_ANSI_B): return "B"
        case UInt32(kVK_ANSI_C): return "C"
        case UInt32(kVK_ANSI_D): return "D"
        case UInt32(kVK_ANSI_E): return "E"
        case UInt32(kVK_ANSI_F): return "F"
        case UInt32(kVK_ANSI_G): return "G"
        case UInt32(kVK_ANSI_H): return "H"
        case UInt32(kVK_ANSI_I): return "I"
        case UInt32(kVK_ANSI_J): return "J"
        case UInt32(kVK_ANSI_K): return "K"
        case UInt32(kVK_ANSI_L): return "L"
        case UInt32(kVK_ANSI_M): return "M"
        case UInt32(kVK_ANSI_N): return "N"
        case UInt32(kVK_ANSI_O): return "O"
        case UInt32(kVK_ANSI_P): return "P"
        case UInt32(kVK_ANSI_Q): return "Q"
        case UInt32(kVK_ANSI_R): return "R"
        case UInt32(kVK_ANSI_S): return "S"
        case UInt32(kVK_ANSI_T): return "T"
        case UInt32(kVK_ANSI_U): return "U"
        case UInt32(kVK_ANSI_V): return "V"
        case UInt32(kVK_ANSI_W): return "W"
        case UInt32(kVK_ANSI_X): return "X"
        case UInt32(kVK_ANSI_Y): return "Y"
        case UInt32(kVK_ANSI_Z): return "Z"
        case UInt32(kVK_ANSI_1): return "1"
        case UInt32(kVK_ANSI_2): return "2"
        case UInt32(kVK_ANSI_3): return "3"
        case UInt32(kVK_ANSI_4): return "4"
        case UInt32(kVK_ANSI_5): return "5"
        case UInt32(kVK_ANSI_6): return "6"
        case UInt32(kVK_ANSI_7): return "7"
        case UInt32(kVK_ANSI_8): return "8"
        case UInt32(kVK_ANSI_9): return "9"
        case UInt32(kVK_ANSI_0): return "0"
        case UInt32(kVK_Space): return "Space"
        case UInt32(kVK_Return): return "Return"
        case UInt32(kVK_Tab): return "Tab"
        case UInt32(kVK_Delete): return "Delete"
        case UInt32(kVK_ForwardDelete): return "Forward Delete"
        case UInt32(kVK_Escape): return "Escape"
        case UInt32(kVK_F1): return "F1"
        case UInt32(kVK_F2): return "F2"
        case UInt32(kVK_F3): return "F3"
        case UInt32(kVK_F4): return "F4"
        case UInt32(kVK_F5): return "F5"
        case UInt32(kVK_F6): return "F6"
        case UInt32(kVK_F7): return "F7"
        case UInt32(kVK_F8): return "F8"
        case UInt32(kVK_F9): return "F9"
        case UInt32(kVK_F10): return "F10"
        case UInt32(kVK_F11): return "F11"
        case UInt32(kVK_F12): return "F12"
        default: return "Key \(keyCode)"
        }
    }

    private static let modifierOnlyKeyCodes: Set<UInt32> = [
        UInt32(kVK_Command),
        UInt32(kVK_RightCommand),
        UInt32(kVK_Shift),
        UInt32(kVK_RightShift),
        UInt32(kVK_Control),
        UInt32(kVK_RightControl),
        UInt32(kVK_Option),
        UInt32(kVK_RightOption),
        UInt32(kVK_CapsLock),
        UInt32(kVK_Function)
    ]

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbonFlags: UInt32 = 0

        if flags.contains(.command) {
            carbonFlags |= UInt32(cmdKey)
        }
        if flags.contains(.option) {
            carbonFlags |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            carbonFlags |= UInt32(controlKey)
        }
        if flags.contains(.shift) {
            carbonFlags |= UInt32(shiftKey)
        }

        return carbonFlags
    }
}

@MainActor
final class HotkeyService {
    static let shared = HotkeyService()

    private let logger = Logger(subsystem: "com.clipforge.app", category: "Hotkey")
    private let signature: OSType = 0x43465047
    private let identifier: UInt32 = 1

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var action: (() -> Void)?

    private init() {
        installHandlerIfNeeded()
    }

    func register(_ descriptor: HotkeyDescriptor, action: @escaping () -> Void) {
        unregister()
        self.action = action

        let hotKeyID = EventHotKeyID(signature: signature, id: identifier)
        let status = RegisterEventHotKey(
            descriptor.keyCode,
            descriptor.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            logger.error("Failed to register global hotkey: \(status)")
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard
                    let eventRef,
                    let userData
                else { return noErr }

                let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()

                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr else { return noErr }

                if hotKeyID.signature == service.signature, hotKeyID.id == service.identifier {
                    service.action?()
                }

                return noErr
            },
            1,
            &eventSpec,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &handlerRef
        )
    }
}
