import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let screenManager = ScreenManager()
    let dispatcher = ReminderDispatcher()
    let hotkeys = HotkeyManager()
    let statusItem = StatusItemController()
    var debugWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        SpriteAssets.registerPixelFont()

        dispatcher.screenManager = screenManager
        screenManager.start()

        statusItem.install(
            onTrigger: { [weak self] in self?.triggerRandomReminder() },
            onSpawn: { [weak self] in self?.spawnPlaceholderPlane() },
            onDebug: { [weak self] in self?.toggleDebugPanel() },
            onQuit: { NSApp.terminate(nil) }
        )

        hotkeys.register(
            spawn: { [weak self] in self?.spawnPlaceholderPlane() },
            triggerReminder: { [weak self] in self?.triggerRandomReminder() },
            reloadAssets: { [weak self] in self?.reloadAssets() },
            toggleDebug: { [weak self] in self?.toggleDebugPanel() }
        )
    }

    func triggerRandomReminder() {
        dispatcher.fire(MockReminderCatalog.random())
    }

    func spawnPlaceholderPlane() {
        dispatcher.fire(MockReminderCatalog.placeholder())
    }

    func reloadAssets() {
        SpriteAssets.reloadFromDisk()
        screenManager.controllers.forEach { $0.reloadAssets() }
    }

    func toggleDebugPanel() {
        if let win = debugWindow, win.isVisible {
            win.orderOut(nil)
            return
        }
        let panel = DebugPanelView()
            .environmentObject(DebugSettings.shared)
            .frame(minWidth: 360, minHeight: 480)
        let host = NSHostingController(rootView: panel)
        let win = debugWindow ?? NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        win.title = "Reminder Debug"
        win.contentViewController = host
        win.center()
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        debugWindow = win
    }
}
