import AppKit

final class ReminderDispatcher {
    weak var screenManager: ScreenManager?

    func fire(_ event: ReminderEvent) {
        guard let controller = screenManager?.controllerForMouseScreen() else { return }
        controller.scene.spawn(event: event)
    }
}
