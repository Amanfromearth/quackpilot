import SpriteKit

final class PlaneNode: SKSpriteNode {
    init() {
        let texture = SpriteAssets.planeTexture()
        let aspect = texture.size().height / max(texture.size().width, 1)
        let size = CGSize(
            width: SpriteAssets.planeDisplayWidth,
            height: SpriteAssets.planeDisplayWidth * aspect
        )
        super.init(texture: texture, color: .clear, size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        startIdleBob()
    }

    required init?(coder: NSCoder) { fatalError() }

    func startIdleBob() {
        let up = SKAction.moveBy(x: 0, y: 6, duration: 0.55)
        up.timingMode = .easeInEaseOut
        let down = up.reversed()
        run(.repeatForever(.sequence([up, down])), withKey: "bob")
    }

    func ropeTipPosition() -> CGPoint {
        let offset = SpriteAssets.planeRopeTipOffset(displaySize: size)
        return CGPoint(x: position.x + offset.x, y: position.y + offset.y)
    }
}
