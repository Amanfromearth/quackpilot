import Foundation
import ServiceManagement

/// Thin wrapper around SMAppService for registering the main app as a login item.
/// Requires macOS 13+ and a proper .app bundle (not `swift run` from terminal) —
/// when run from terminal `mainApp.status` is `.notFound` and toggling is a no-op.
enum LaunchAtLogin {
    static var isAvailable: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status != .notFound
        }
        return false
    }

    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    /// Returns true on success, false otherwise (e.g. user has not approved yet,
    /// or app isn't running from a bundle). Errors are logged.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("LaunchAtLogin toggle failed: \(error)")
            return false
        }
    }
}
