import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var showPhysicsBounds: Bool {
        didSet { UserDefaults.standard.set(showPhysicsBounds, forKey: "debug.showPhysicsBounds") }
    }
    @Published var bannerAmplitude: Double {
        didSet { UserDefaults.standard.set(bannerAmplitude, forKey: "banner.amplitude") }
    }
    @Published var bannerFrequency: Double {
        didSet { UserDefaults.standard.set(bannerFrequency, forKey: "banner.frequency") }
    }
    @Published var bannerPhaseStep: Double {
        didSet { UserDefaults.standard.set(bannerPhaseStep, forKey: "banner.phaseStep") }
    }

    /// Single knob that scales BOTH the plane sprite and the banner uniformly.
    /// 1.0 = original size, 0.5 = half, etc. Applied at render time via SKNode.setScale,
    /// so pixel-art crispness is preserved (textures stay at their base resolution).
    @Published var displayScale: Double {
        didSet { UserDefaults.standard.set(displayScale, forKey: "displayScale") }
    }

    /// Horizontal flight speed in points/second. Read each frame so the slider tunes
    /// live while a plane is on-screen.
    @Published var flightSpeed: Double {
        didSet { UserDefaults.standard.set(flightSpeed, forKey: "flightSpeed") }
    }

    @Published var audioEnabled: Bool {
        didSet { UserDefaults.standard.set(audioEnabled, forKey: "audio.enabled") }
    }

    // MARK: - Calendar

    @Published var calendarEnabled: Bool {
        didSet { UserDefaults.standard.set(calendarEnabled, forKey: "calendar.enabled") }
    }
    /// EKCalendar.calendarIdentifier values that should be watched.
    @Published var selectedCalendarIdentifiers: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(selectedCalendarIdentifiers), forKey: "calendar.selectedIdentifiers")
        }
    }
    /// Minutes-before-start at which to fire a plane. e.g. `[10, 5, 0]` → three planes per event.
    @Published var alertOffsetsMinutes: [Int] {
        didSet { UserDefaults.standard.set(alertOffsetsMinutes, forKey: "calendar.alertOffsetsMinutes") }
    }

    private init() {
        let d = UserDefaults.standard
        self.showPhysicsBounds = d.bool(forKey: "debug.showPhysicsBounds")
        self.bannerAmplitude = d.object(forKey: "banner.amplitude") as? Double ?? Defaults.bannerAmplitude
        self.bannerFrequency = d.object(forKey: "banner.frequency") as? Double ?? Defaults.bannerFrequency
        self.bannerPhaseStep = d.object(forKey: "banner.phaseStep") as? Double ?? Defaults.bannerPhaseStep
        self.displayScale = d.object(forKey: "displayScale") as? Double ?? Defaults.displayScale
        self.audioEnabled = d.object(forKey: "audio.enabled") as? Bool ?? Defaults.audioEnabled
        self.flightSpeed = d.object(forKey: "flightSpeed") as? Double ?? Defaults.flightSpeed
        self.calendarEnabled = d.object(forKey: "calendar.enabled") as? Bool ?? Defaults.calendarEnabled
        if let arr = d.array(forKey: "calendar.selectedIdentifiers") as? [String] {
            self.selectedCalendarIdentifiers = Set(arr)
        } else {
            self.selectedCalendarIdentifiers = []
        }
        if let arr = d.array(forKey: "calendar.alertOffsetsMinutes") as? [Int], !arr.isEmpty {
            self.alertOffsetsMinutes = arr
        } else {
            self.alertOffsetsMinutes = Defaults.alertOffsetsMinutes
        }
    }

    /// Restore visual/audio settings to their original defaults. Does NOT touch
    /// custom reminders (user data) or launch-at-login (system-managed).
    func resetToDefaults() {
        showPhysicsBounds = false
        bannerAmplitude = Defaults.bannerAmplitude
        bannerFrequency = Defaults.bannerFrequency
        bannerPhaseStep = Defaults.bannerPhaseStep
        displayScale = Defaults.displayScale
        audioEnabled = Defaults.audioEnabled
        flightSpeed = Defaults.flightSpeed
        calendarEnabled = Defaults.calendarEnabled
        alertOffsetsMinutes = Defaults.alertOffsetsMinutes
        // Intentionally NOT resetting selectedCalendarIdentifiers — preserve the user's
        // calendar selection across a reset of visual prefs.
    }

    private enum Defaults {
        static let bannerAmplitude: Double = 1.6
        static let bannerFrequency: Double = 3.0
        static let bannerPhaseStep: Double = 0.18
        static let displayScale: Double = 0.55
        static let audioEnabled: Bool = true
        static let flightSpeed: Double = 110
        static let calendarEnabled: Bool = false
        static let alertOffsetsMinutes: [Int] = [10, 5, 0]
    }
}
