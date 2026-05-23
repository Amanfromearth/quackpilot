import AppKit
import Carbon.HIToolbox

/// Registers global Cmd+Shift+1..4 hotkeys via Carbon's RegisterEventHotKey.
/// (NSEvent.addGlobalMonitorForEvents is read-only for modifier+key combos and can't be used
/// to intercept system-wide presses.)
final class HotkeyManager {
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var callbacks: [UInt32: () -> Void] = [:]

    func register(
        spawn: @escaping () -> Void,
        triggerReminder: @escaping () -> Void,
        reloadAssets: @escaping () -> Void,
        toggleSettings: @escaping () -> Void
    ) {
        installHandler()
        register(id: 1, keyCode: UInt32(kVK_ANSI_1), action: spawn)
        register(id: 2, keyCode: UInt32(kVK_ANSI_2), action: triggerReminder)
        register(id: 3, keyCode: UInt32(kVK_ANSI_3), action: reloadAssets)
        register(id: 4, keyCode: UInt32(kVK_ANSI_4), action: toggleSettings)
    }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, eventRef, userData) -> OSStatus in
                guard let eventRef = eventRef, let userData = userData else { return noErr }
                var hk = EventHotKeyID()
                let err = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hk
                )
                if err == noErr {
                    let mgr = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                    if let cb = mgr.callbacks[hk.id] {
                        DispatchQueue.main.async { cb() }
                    }
                }
                return noErr
            },
            1, &spec, selfPtr, &handler
        )
    }

    private func register(id: UInt32, keyCode: UInt32, action: @escaping () -> Void) {
        var ref: EventHotKeyRef?
        let signature: OSType = 0x524d4452 // 'RMDR'
        let hkID = EventHotKeyID(signature: signature, id: id)
        let mods: UInt32 = UInt32(cmdKey) | UInt32(shiftKey)
        let status = RegisterEventHotKey(keyCode, mods, hkID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref = ref {
            refs.append(ref)
            callbacks[id] = action
        } else {
            NSLog("RegisterEventHotKey failed for id \(id), status=\(status)")
        }
    }

    deinit {
        for r in refs { UnregisterEventHotKey(r) }
        if let h = handler { RemoveEventHandler(h) }
    }
}
