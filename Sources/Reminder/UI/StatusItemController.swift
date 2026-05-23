import AppKit

final class StatusItemController: NSObject, NSMenuDelegate {
    private var item: NSStatusItem?
    private var onTrigger: (() -> Void)?
    private var onSpawn: (() -> Void)?
    private var onDebug: (() -> Void)?
    private var onQuit: (() -> Void)?

    func install(
        onTrigger: @escaping () -> Void,
        onSpawn: @escaping () -> Void,
        onDebug: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onTrigger = onTrigger
        self.onSpawn = onSpawn
        self.onDebug = onDebug
        self.onQuit = onQuit

        let it = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = it.button {
            button.title = "✈︎"
            button.toolTip = "Reminder"
        }
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Trigger Reminder", action: #selector(triggerAction), keyEquivalent: "2").target = self
        menu.addItem(withTitle: "Spawn Plane", action: #selector(spawnAction), keyEquivalent: "1").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Debug Panel…", action: #selector(debugAction), keyEquivalent: "4").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Reminder", action: #selector(quitAction), keyEquivalent: "q").target = self
        it.menu = menu
        self.item = it
    }

    @objc private func triggerAction() { onTrigger?() }
    @objc private func spawnAction()   { onSpawn?() }
    @objc private func debugAction()   { onDebug?() }
    @objc private func quitAction()    { onQuit?() }
}
