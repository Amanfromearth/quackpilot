import AppKit
import Foundation

/// Polls the CustomRemindersStore at a fixed interval and dispatches any reminders
/// whose next-due time has passed. Polling beats per-reminder Timers because:
///   - reminders can be added/changed/disabled live without re-arming anything
///   - missing a fire while the Mac was asleep just means we fire on next wake tick
///   - one Timer is cheaper than N Timers when the user has many reminders
///
/// To make this reliable for a menu-bar agent we also tick on:
///   - system wake (NSWorkspace.didWakeNotification)
///   - app activation (NSApplication.didBecomeActiveNotification — fires when the
///     user clicks the menu bar icon, which is the most common "we got CPU back"
///     signal for an LSUIElement app that's been napped)
final class ReminderScheduler {
    weak var dispatcher: ReminderDispatcher?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private let tickInterval: TimeInterval = 15

    func start() {
        stop()
        // Initial tick so a freshly-added past-due reminder fires right away.
        tick()
        let t = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t

        installCatchupObservers()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        for token in observers {
            NotificationCenter.default.removeObserver(token)
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
        observers.removeAll()
    }

    private func installCatchupObservers() {
        let wake = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.tick() }
        let active = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.tick() }
        observers = [wake, active]
    }

    private func tick() {
        let now = Date()
        let snapshot = CustomRemindersStore.shared.reminders
        for reminder in snapshot where reminder.isDue(at: now) {
            fire(reminder, at: now)
        }
    }

    private func fire(_ reminder: CustomReminder, at now: Date) {
        let event = ReminderEvent(title: reminder.title, urlString: reminder.urlString)
        dispatcher?.fire(event)
        CustomRemindersStore.shared.markFired(id: reminder.id, at: now)
    }

    deinit { stop() }
}
