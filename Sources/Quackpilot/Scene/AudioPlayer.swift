import AVFoundation
import Foundation

final class PlaneAudioPlayer {
    private var player: AVAudioPlayer?

    init() {
        prepare()
    }

    private func prepare() {
        guard let url = Bundle.module.url(forResource: "plane", withExtension: "mp3") else {
            NSLog("plane.mp3 missing from bundle resources")
            return
        }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1 // loop indefinitely
            p.volume = 0.45
            p.prepareToPlay()
            player = p
        } catch {
            NSLog("AVAudioPlayer init failed: \(error)")
        }
    }

    func start() {
        guard AppSettings.shared.audioEnabled, let p = player else { return }
        if p.isPlaying { return }
        p.currentTime = 0
        p.volume = 0.45
        p.play()
    }

    /// Fade out quickly and stop. Used on natural exit and on click-dismiss.
    func stop() {
        guard let p = player, p.isPlaying else { return }
        let fadeDuration: TimeInterval = 0.35
        p.setVolume(0, fadeDuration: fadeDuration)
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration + 0.05) { [weak p] in
            p?.stop()
        }
    }
}
