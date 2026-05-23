import Foundation

/// Polls the CustomRemindersStore at a fixed interval and dispatches any reminders
/// whose next-due time has passed. Polling beats per-reminder Timers because:
///   - reminders can be added/changed/disabled live without re-arming anything
///   - missing a fire while the Mac was asleep just means we fire on next wake tick
///   - one Timer is cheaper than N Timers when the user has many reminders
final class ReminderScheduler {
    weak var dispatcher: ReminderDispatcher?
    private var timer: Timer?
    private let tickInterval: TimeInterval = 15

    func start() {
        stop()
        // Tick immediately on start so a freshly-added past-due reminder fires right away,
        // then on a steady interval.
        tick()
        let t = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let now = Date()
        let store = CustomRemindersStore.shared
        for reminder in store.reminders where reminder.isDue(at: now) {
            fire(reminder, at: now)
        }
    }

    private func fire(_ reminder: CustomReminder, at now: Date) {
        let event = ReminderEvent(title: reminder.title, urlString: reminder.urlString)
        dispatcher?.fire(event)
        CustomRemindersStore.shared.markFired(id: reminder.id, at: now)
    }
}
