import AppKit

final class ScreenManager {
    private(set) var controllers: [OverlayWindowController] = []

    func start() {
        rebuild()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screensChanged() {
        rebuild()
    }

    private func rebuild() {
        for c in controllers { c.close() }
        controllers = NSScreen.screens.map { OverlayWindowController(screen: $0) }
        for c in controllers { c.show() }
    }

    /// Pick the overlay controller for the screen currently containing the mouse cursor.
    func controllerForMouseScreen() -> OverlayWindowController? {
        let loc = NSEvent.mouseLocation
        return controllers.first { c in
            c.window?.screen?.frame.contains(loc) ?? false
        } ?? controllers.first
    }
}
