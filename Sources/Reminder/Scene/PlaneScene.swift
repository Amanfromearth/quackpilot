import AppKit
import SpriteKit

final class PlaneScene: SKScene {
    private var activeFlight: ActiveFlight?
    private let audio = PlaneAudioPlayer()

    private struct ActiveFlight {
        let event: ReminderEvent
        let plane: PlaneNode
        let banner: BannerRibbon
        let startX: CGFloat
        let endX: CGFloat
        var paused: Bool
    }

    func spawn(event: ReminderEvent) {
        if let existing = activeFlight {
            existing.plane.removeFromParent()
            existing.banner.removeFromParent()
            activeFlight = nil
        }
        audio.stop()

        let plane = PlaneNode()
        let banner = BannerRibbon(text: event.title.uppercased())

        // The supplied sprite already faces RIGHT, so we fly LEFT → RIGHT and
        // do NOT mirror. The rope sits on the left (trailing) side of the plane.
        let scale = CGFloat(DebugSettings.shared.displayScale)
        plane.setScale(scale)
        banner.setScale(scale)

        // Compute visible plane width using the scaled frame.
        let visiblePlaneW = plane.frame.width
        let startX = -visiblePlaneW * 0.6
        let endX = size.width + visiblePlaneW * 0.6
        let y = size.height * CGFloat.random(in: 0.55...0.85)
        plane.position = CGPoint(x: startX, y: y)
        plane.zPosition = 10
        addChild(plane)

        banner.zPosition = 9
        addChild(banner)

        activeFlight = ActiveFlight(
            event: event,
            plane: plane,
            banner: banner,
            startX: startX,
            endX: endX,
            paused: false
        )

        audio.start()
    }

    override func update(_ currentTime: TimeInterval) {
        guard var flight = activeFlight else { return }

        // Live-tunable display scale via debug panel slider.
        let scale = CGFloat(DebugSettings.shared.displayScale)
        flight.plane.setScale(scale)
        flight.banner.setScale(scale)

        if !flight.paused {
            // Read speed each frame so the debug slider tunes flight speed live.
            let speed = CGFloat(max(0, DebugSettings.shared.flightSpeed))
            let dt = lastFrameDelta(currentTime: currentTime)
            flight.plane.position.x += speed * CGFloat(dt)

            if flight.plane.position.x >= flight.endX {
                flight.plane.removeFromParent()
                flight.banner.removeFromParent()
                activeFlight = nil
                audio.stop()
                return
            }
        }

        // Rope tip in scene coords. The rope tip on the sprite is on its LEFT side
        // (relX=0 of the original PNG). With no mirror, that's just -halfWidth in
        // scaled units from the plane's center, plus the small vertical offset.
        let visiblePlaneW = flight.plane.frame.width
        let visiblePlaneH = flight.plane.frame.height
        let ropeOffset = SpriteAssets.planeRopeTipOffset(
            displaySize: CGSize(width: visiblePlaneW, height: visiblePlaneH)
        )
        let tipX = flight.plane.position.x + ropeOffset.x
        let tipY = flight.plane.position.y + ropeOffset.y
        // Banner has right-edge anchor → its right edge sits at the rope tip,
        // extending LEFT (trailing the plane).
        flight.banner.position = CGPoint(x: tipX, y: tipY)
        flight.banner.tick(currentTime: currentTime)

        activeFlight = flight
    }

    private var lastFrameTime: TimeInterval = 0
    private func lastFrameDelta(currentTime: TimeInterval) -> TimeInterval {
        if lastFrameTime == 0 { lastFrameTime = currentTime; return 1.0 / 60.0 }
        let dt = currentTime - lastFrameTime
        lastFrameTime = currentTime
        return min(max(dt, 0), 0.05)
    }

    // MARK: - Hover / click

    func cursorIsOverInteractive(_ point: CGPoint) -> Bool {
        guard let flight = activeFlight else { return false }
        if flight.plane.frame.insetBy(dx: -4, dy: -4).contains(point) { return true }
        if flight.banner.frame.insetBy(dx: -2, dy: -4).contains(point) { return true }
        return false
    }

    override func mouseDown(with event: NSEvent) {
        guard let flight = activeFlight else { return }
        let pt = event.location(in: self)
        if cursorIsOverInteractive(pt) {
            openLinkAndDismiss(event: flight.event)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        guard var flight = activeFlight else { return }
        let pt = event.location(in: self)
        flight.paused = cursorIsOverInteractive(pt)
        activeFlight = flight
    }

    private func openLinkAndDismiss(event: ReminderEvent) {
        if let url = URL(string: event.urlString) {
            NSWorkspace.shared.open(url)
        }
        guard var flight = activeFlight else { return }
        let plane = flight.plane
        let banner = flight.banner
        let exit = SKAction.group([
            SKAction.moveBy(x: size.width * 0.7, y: size.height * 0.15, duration: 0.6),
            SKAction.fadeOut(withDuration: 0.6)
        ])
        plane.run(exit) {
            plane.removeFromParent()
            banner.removeFromParent()
        }
        banner.run(.fadeOut(withDuration: 0.6))
        flight.paused = true
        activeFlight = flight
        audio.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.activeFlight = nil
        }
    }

    func reloadAssets() {
        if let flight = activeFlight {
            flight.plane.texture = SpriteAssets.planeTexture()
        }
    }
}
