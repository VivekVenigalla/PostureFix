import Carbon.HIToolbox
import AppKit

///Global Option+Shift+P hotkey that immediately stops monitoring (and therefore
///the camera), no matter where focus is or whether the menu bar icon is
///reachable. macOS can push third-party status items into the overflow area
///when it inserts its own Video Effects item for an active camera, which can
///strand a user with the camera on and no visible way to turn it off — this
///is the escape hatch for that.
///
///Uses the Carbon Hot Key Manager rather than NSEvent's global monitor:
///NSEvent.addGlobalMonitorForEvents silently requires Accessibility
///permission for key events (with no prompt or error if it's missing), while
///RegisterEventHotKey works unprompted — the same mechanism apps like
///Alfred/Rectangle rely on for global shortcuts.
enum EmergencyHotkey {
    private static var hotKeyRef: EventHotKeyRef?
    private static var eventHandlerRef: EventHandlerRef?
    private static var callback: (() -> Void)?

    static func install(onTrigger: @escaping () -> Void) {
        guard hotKeyRef == nil else { return }
        callback = onTrigger

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ -> OSStatus in
                EmergencyHotkey.callback?()
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        let signature = fourCharCode("PFEH")
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let modifiers = UInt32(optionKey | shiftKey)

        RegisterEventHotKey(
            UInt32(kVK_ANSI_P),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    static func uninstall() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        eventHandlerRef = nil
        callback = nil
    }

    private static func fourCharCode(_ string: String) -> FourCharCode {
        string.utf8.reduce(0) { ($0 << 8) + FourCharCode($1) }
    }
}
