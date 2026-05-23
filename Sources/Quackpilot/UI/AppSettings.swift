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

    private init() {
        let d = UserDefaults.standard
        self.showPhysicsBounds = d.bool(forKey: "debug.showPhysicsBounds")
        self.bannerAmplitude = d.object(forKey: "banner.amplitude") as? Double ?? 1.6
        self.bannerFrequency = d.object(forKey: "banner.frequency") as? Double ?? 3.0
        self.bannerPhaseStep = d.object(forKey: "banner.phaseStep") as? Double ?? 0.18
        self.displayScale = d.object(forKey: "displayScale") as? Double ?? 0.55
        self.audioEnabled = d.object(forKey: "audio.enabled") as? Bool ?? true
        self.flightSpeed = d.object(forKey: "flightSpeed") as? Double ?? 110
    }
}
