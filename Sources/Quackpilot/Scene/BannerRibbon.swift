import AppKit
import SpriteKit

/// Procedurally-rendered pixel-art banner. Two-pass render each frame:
///   1) Draw a "flat" banner (body + border + stripes + text) into an RGBA buffer.
///   2) Copy each column into the output buffer shifted by a sine offset so the
///      whole banner — text included — rides the wave together.
///
/// Output is upscaled by `pixelScale` with nearest-neighbor filtering to keep
/// pixel-art edges crisp.
final class BannerRibbon: SKSpriteNode {
    private let bitmapWidth: Int
    private let bitmapHeight: Int
    private let pixelScale: CGFloat = 4
    private var startTime: TimeInterval = 0
    private(set) var text: String = ""

    /// Cached flat banner buffer; invalidated when `text` changes.
    private var flatBufferRGBA: [UInt8] = []

    init(text: String, widthPixels: Int = 128, heightPixels: Int = 28) {
        self.bitmapWidth = widthPixels
        self.bitmapHeight = heightPixels
        let displaySize = CGSize(
            width: CGFloat(widthPixels) * pixelScale,
            height: CGFloat(heightPixels) * pixelScale
        )
        super.init(texture: nil, color: .clear, size: displaySize)
        // Anchor at the RIGHT edge (vertical center): the banner attaches to the rope tip
        // on its right side and trails to the LEFT as the plane flies left-to-right.
        anchorPoint = CGPoint(x: 1.0, y: 0.5)
        setText(text)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setText(_ newText: String) {
        guard newText != text else { return }
        text = newText
        flatBufferRGBA = renderFlatBanner()
    }

    func tick(currentTime: TimeInterval) {
        if startTime == 0 { startTime = currentTime }
        if flatBufferRGBA.isEmpty { flatBufferRGBA = renderFlatBanner() }
        let t = currentTime - startTime
        texture = renderWavedTexture(time: t)
    }

    // MARK: - Pass 1: flat banner

    private struct RGBA { var r, g, b, a: UInt8 }

    private let bodyColor    = RGBA(r: 0xFB, g: 0xEE, b: 0xC8, a: 0xFF) // cream
    private let stripeColor  = RGBA(r: 0xE4, g: 0x3A, b: 0x3A, a: 0xFF) // red
    private let borderDark   = RGBA(r: 0x6B, g: 0x21, b: 0x21, a: 0xFF) // dark red
    private let shadowColor  = RGBA(r: 0xC4, g: 0x9A, b: 0x6C, a: 0xFF) // tan shadow
    private let textColor    = RGBA(r: 0x1F, g: 0x12, b: 0x12, a: 0xFF) // near-black
    private let clearColor   = RGBA(r: 0, g: 0, b: 0, a: 0)

    private func renderFlatBanner() -> [UInt8] {
        let w = bitmapWidth, h = bitmapHeight
        // Leave 2px margin top + 2px bottom for wave excursion — banner body
        // occupies the middle (h-4) rows.
        let bodyTop = h - 3
        let bodyBottom = 2
        var buf = [UInt8](repeating: 0, count: w * h * 4)

        // Body + border + stripes
        for x in 0..<w {
            for y in 0..<h {
                let inBody = (y >= bodyBottom && y <= bodyTop)
                guard inBody else { continue }
                let isTopBorder = (y == bodyTop)
                let isBottomBorder = (y == bodyBottom)
                let isRightFringe = (x == w - 1)
                let isLeftFringe = (x == 0)
                let color: RGBA
                if isTopBorder || isBottomBorder || isRightFringe || isLeftFringe {
                    color = borderDark
                } else if y == bodyBottom + 1 {
                    color = shadowColor
                } else {
                    let stripePhase = (x - y) % 8
                    color = (stripePhase == 0 || stripePhase == 1) ? stripeColor : bodyColor
                }
                writePixel(&buf, x: x, y: y, w: w, h: h, color: color)
            }
        }

        // Text rendered with CoreText into a temporary buffer (also stored bottom-up
        // so it lines up with the flat banner's bottom-up Y convention).
        let textMask = renderTextMask()
        for x in 0..<w {
            for y in 0..<h {
                guard textMask[x + y * w] else { continue }
                // Only stamp text where banner body exists
                guard y >= bodyBottom + 1 && y <= bodyTop - 1 else { continue }
                writePixel(&buf, x: x, y: y, w: w, h: h, color: textColor)
            }
        }

        return buf
    }

    /// Render the banner text into a top-down w×h boolean grid using CoreText with
    /// Press Start 2P. Returns flattened array where true = ink pixel.
    private func renderTextMask() -> [Bool] {
        let w = bitmapWidth, h = bitmapHeight
        var mask = [Bool](repeating: false, count: w * h)
        guard !text.isEmpty else { return mask }

        let cs = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w,
            space: cs, bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return mask }
        // Clear to black
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        // Banner is 28px tall, with body height ~24. Press Start 2P glyph is 8px at native size.
        // We want chunky, readable text — render at 8pt (font's native size).
        let fontSize: CGFloat = 8
        let font = SpriteAssets.pixelFont(size: fontSize)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .kern: 1
        ]

        // Truncate text if too long: estimate ~7 px/char at 8pt PSP
        let maxChars = max(1, (w - 12) / 7)
        let displayed: String
        if text.count > maxChars {
            displayed = String(text.prefix(maxChars - 1)) + "…"
        } else {
            displayed = text
        }
        let str = NSAttributedString(string: displayed, attributes: attrs)
        let line = CTLineCreateWithAttributedString(str)
        let bounds = CTLineGetImageBounds(line, ctx)

        // Center horizontally and vertically inside the body area.
        let leftPad: CGFloat = 4
        let rightPad: CGFloat = 4
        let availableW = CGFloat(w) - leftPad - rightPad
        let xPos = leftPad + max(0, (availableW - bounds.width) / 2) - bounds.origin.x
        // The body sits between y=3 and y=h-4 in bottom-up coords (matching renderFlatBanner).
        let bodyCenterY = CGFloat(2 + (h - 3 - 2)) / 2 + 1
        let yPos = bodyCenterY - bounds.height / 2 - bounds.origin.y

        ctx.textPosition = CGPoint(x: round(xPos), y: round(yPos))
        CTLineDraw(line, ctx)

        guard let data = ctx.data else { return mask }
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        // CGContext rows are top-down in memory regardless of CG's bottom-up coord system.
        // We want a top-down mask, so flip Y to match.
        for y in 0..<h {
            for x in 0..<w {
                let srcRow = h - 1 - y // flip
                let v = bytes[x + srcRow * w]
                mask[x + y * w] = v > 96
            }
        }
        return mask
    }

    private func writePixel(_ buf: inout [UInt8], x: Int, y: Int, w: Int, h: Int, color: RGBA) {
        // We store bottom-up in our flat buffer so it lines up with CG's bottom-up coords
        // when we hand it to a CGContext. Index = (y*w + x)*4 with y measured from bottom.
        let i = (y * w + x) * 4
        buf[i] = color.r
        buf[i + 1] = color.g
        buf[i + 2] = color.b
        buf[i + 3] = color.a
    }

    // MARK: - Pass 2: wave shear

    private func renderWavedTexture(time: TimeInterval) -> SKTexture {
        let w = bitmapWidth, h = bitmapHeight
        let amplitude: CGFloat = max(0, CGFloat(DebugSettings.shared.bannerAmplitude))
        let frequency: CGFloat = max(0.1, CGFloat(DebugSettings.shared.bannerFrequency))
        let phaseStep: CGFloat = CGFloat(DebugSettings.shared.bannerPhaseStep)

        // `flatBufferRGBA` is stored bottom-up. We sample it column-by-column shifted
        // vertically by sin(...) to produce the wave, then write the result top-down
        // for CGImage consumption.
        var out = [UInt8](repeating: 0, count: w * h * 4)
        for x in 0..<w {
            let phase = CGFloat(time) * frequency + CGFloat(x) * phaseStep
            let yOff = Int(round(amplitude * sin(phase)))
            for y in 0..<h {
                let srcY = y - yOff
                guard srcY >= 0 && srcY < h else { continue }
                let srcI = (srcY * w + x) * 4              // bottom-up in flat buffer
                let dstRow = h - 1 - y                      // flip Y for top-down output
                let dstI = (dstRow * w + x) * 4
                out[dstI]     = flatBufferRGBA[srcI]
                out[dstI + 1] = flatBufferRGBA[srcI + 1]
                out[dstI + 2] = flatBufferRGBA[srcI + 2]
                out[dstI + 3] = flatBufferRGBA[srcI + 3]
            }
        }

        let cs = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: NSData(bytes: out, length: out.count)) else {
            return SKTexture()
        }
        guard let cg = CGImage(
            width: w, height: h,
            bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: w * 4,
            space: cs,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil, shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return SKTexture() }
        let t = SKTexture(cgImage: cg)
        t.filteringMode = .nearest
        return t
    }
}
