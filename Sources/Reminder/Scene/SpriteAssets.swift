import AppKit
import CoreText
import SpriteKit

enum SpriteAssets {
    /// Logical display width of the plane sprite on screen, in points.
    /// The supplied PNG is 809×308; we render at ~240pt wide for an arcade feel.
    static let planeDisplayWidth: CGFloat = 240

    /// The plane PNG has a thin rope extending from its left side. Empirically
    /// (sampled by scanning brown rope pixels in the supplied image) the rope tip
    /// sits at the LEFT edge of the image at about 43.5% from the bottom.
    static func planeRopeTipOffset(displaySize: CGSize) -> CGPoint {
        let relX: CGFloat = 0.00
        let relY: CGFloat = 0.435
        return CGPoint(
            x: (relX - 0.5) * displaySize.width,
            y: (relY - 0.5) * displaySize.height
        )
    }

    private static var cachedPlaneTexture: SKTexture?

    static func planeTexture() -> SKTexture {
        if let t = cachedPlaneTexture { return t }
        guard let url = Bundle.module.url(forResource: "plane", withExtension: "png") else {
            fatalError("plane image missing from bundle resources")
        }
        // The user's file may actually be a JPEG (no alpha) with a black background.
        // We chroma-key near-black pixels to transparent so the plane reads cleanly
        // against the desktop instead of inside a black rectangle.
        let cg = loadAndChromaKey(url: url)
        let t = SKTexture(cgImage: cg)
        t.filteringMode = .nearest
        cachedPlaneTexture = t
        return t
    }

    private static func loadAndChromaKey(url: URL) -> CGImage {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            fatalError("could not decode plane image at \(url)")
        }
        let w = cg.width, h = cg.height
        let bytesPerRow = w * 4
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        let bmpInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: &buffer,
            width: w, height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: cs,
            bitmapInfo: bmpInfo
        ) else {
            return cg
        }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        // Threshold: pixels with R,G,B all below this become transparent.
        let blackThreshold: UInt8 = 20
        var i = 0
        while i < buffer.count {
            let r = buffer[i]
            let g = buffer[i + 1]
            let b = buffer[i + 2]
            if r < blackThreshold && g < blackThreshold && b < blackThreshold {
                buffer[i] = 0
                buffer[i + 1] = 0
                buffer[i + 2] = 0
                buffer[i + 3] = 0
            }
            i += 4
        }
        guard let outCtx = CGContext(
            data: &buffer,
            width: w, height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: cs,
            bitmapInfo: bmpInfo
        ), let result = outCtx.makeImage() else {
            return cg
        }
        return result
    }

    static func reloadFromDisk() {
        cachedPlaneTexture = nil
    }

    // MARK: - Pixel font

    static let pixelFontName = "PressStart2P-Regular"
    private static var fontRegistered = false

    static func registerPixelFont() {
        guard !fontRegistered else { return }
        fontRegistered = true
        guard let url = Bundle.module.url(forResource: "PressStart2P", withExtension: "ttf") else {
            NSLog("PressStart2P.ttf missing from bundle resources")
            return
        }
        var err: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &err) {
            if let e = err?.takeRetainedValue() {
                NSLog("font registration failed: \(e)")
            }
        }
    }

    static func pixelFont(size: CGFloat) -> NSFont {
        registerPixelFont()
        return NSFont(name: pixelFontName, size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
    }
}
