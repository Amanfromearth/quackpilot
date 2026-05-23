import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let screenManager = ScreenManager()
    let dispatcher = ReminderDispatcher()
    let hotkeys = HotkeyManager()
    let statusItem = StatusItemController()
    let scheduler = ReminderScheduler()
    lazy var calendarScheduler = CalendarAlertScheduler(service: Services.calendar)
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        SpriteAssets.registerPixelFont()

        dispatcher.screenManager = screenManager
        screenManager.start()

        scheduler.dispatcher = dispatcher
        scheduler.start()

        calendarScheduler.dispatcher = dispatcher
        calendarScheduler.start()

        statusItem.install(
            onTrigger: { [weak self] in self?.triggerRandomReminder() },
            onSpawn: { [weak self] in self?.spawnPlaceholderPlane() },
            onSettings: { [weak self] in self?.toggleSettingsPanel() },
            onQuit: { NSApp.terminate(nil) }
        )

        hotkeys.register(
            spawn: { [weak self] in self?.spawnPlaceholderPlane() },
            triggerReminder: { [weak self] in self?.triggerRandomReminder() },
            reloadAssets: { [weak self] in self?.reloadAssets() },
            toggleSettings: { [weak self] in self?.toggleSettingsPanel() }
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

    func toggleSettingsPanel() {
        if let win = settingsWindow, win.isVisible {
            win.orderOut(nil)
            return
        }
        let panel = SettingsPanelView()
            .environmentObject(AppSettings.shared)
            .frame(minWidth: 420, minHeight: 480)
        let host = NSHostingController(rootView: panel)
        let win = settingsWindow ?? NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 640),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        win.title = "Quackpilot Settings"
        win.contentViewController = host
        win.center()
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = win
    }
}
