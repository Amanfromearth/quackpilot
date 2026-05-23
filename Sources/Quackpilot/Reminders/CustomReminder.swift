import Foundation

/// A user-defined reminder that fires at a scheduled time, optionally on repeat.
struct CustomReminder: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var urlString: String
    /// The first (or only) time this reminder should fire.
    var firstFireAt: Date
    var repeatRule: RepeatRule
    var enabled: Bool = true
    /// Last time the scheduler actually fired this reminder. nil before first fire.
    var lastFiredAt: Date?
}

/// Repeat behavior. Codable enum with associated values — Swift synthesizes
/// Codable conformance for us.
enum RepeatRule: Codable, Hashable {
    case once
    case everyMinutes(Int)
    case hourly
    case daily
    case weekly

    /// Interval between fires, or nil for `.once`.
    var interval: TimeInterval? {
        switch self {
        case .once:                return nil
        case .everyMinutes(let m): return TimeInterval(max(1, m) * 60)
        case .hourly:              return 3600
        case .daily:               return 86_400
        case .weekly:              return 86_400 * 7
        }
    }

    var label: String {
        switch self {
        case .once:                return "Once"
        case .everyMinutes(let m): return "Every \(m) min"
        case .hourly:              return "Hourly"
        case .daily:               return "Daily"
        case .weekly:              return "Weekly"
        }
    }
}

extension CustomReminder {
    /// Returns the next time this reminder should fire (≤ now means it's due NOW),
    /// or nil if it should never fire again (disabled, or one-time and already fired).
    func nextDueDate(now: Date) -> Date? {
        guard enabled else { return nil }
        if let last = lastFiredAt {
            switch repeatRule {
            case .once:
                return nil
            default:
                guard let interval = repeatRule.interval else { return nil }
                return last.addingTimeInterval(interval)
            }
        }
        return firstFireAt
    }

    /// True if this reminder should fire at `now`.
    func isDue(at now: Date) -> Bool {
        guard let due = nextDueDate(now: now) else { return false }
        return now >= due
    }
}
