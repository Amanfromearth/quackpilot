import AppKit
import SpriteKit

/// Procedurally-rendered pixel-art banner. The banner's width adapts to the
/// text length up to `maxBitmapWidth`; longer text wraps to a 2-line banner
/// (taller). Two-pass render each frame:
///   1) Draw a "flat" banner (body + border + stripes + 1 or 2 lines of text)
///      into a bottom-up RGBA buffer, cached until the text changes.
///   2) Copy each column into the output buffer shifted by a sine offset so the
///      whole banner — text included — rides the wave together.
///
/// Output is upscaled by `pixelScale` with nearest-neighbor filtering to keep
/// pixel-art edges crisp.
final class BannerRibbon: SKSpriteNode {
    // MARK: - Layout constants (logical bitmap pixels, pre-upscale)

    private let pixelScale: CGFloat = 4
    /// Smallest banner width so very short text still has visible body around it.
    private let minBitmapWidth = 44
    /// Largest single-line banner width — text wider than this wraps to 2 lines.
    private let maxBitmapWidth = 160
    /// Banner height for a 1-line banner.
    private let singleLineHeight = 22
    /// Banner height for a 2-line banner.
    private let twoLineHeight = 36
    /// Horizontal padding inside the banner body (each side).
    private let horizontalPad = 6
    /// Font size used for the bitmap text. Press Start 2P glyphs are 8px at 8pt.
    private let fontSize: CGFloat = 8

    // MARK: - State

    private var bitmapWidth: Int = 44
    private var bitmapHeight: Int = 22
    /// One or two strings depending on whether wrapping was needed.
    private var lines: [String] = []
    private var flatBufferRGBA: [UInt8] = []
    private var startTime: TimeInterval = 0
    private(set) var text: String = ""

    // MARK: - Init

    init(text: String) {
        super.init(texture: nil, color: .clear, size: .zero)
        // Anchor at the RIGHT edge (vertical center): the banner attaches to the rope tip
        // on its right side and trails to the LEFT as the plane flies left-to-right.
        anchorPoint = CGPoint(x: 1.0, y: 0.5)
        setText(text)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setText(_ newText: String) {
        guard newText != text || flatBufferRGBA.isEmpty else { return }
        text = newText
        relayoutAndRender()
    }

    private func relayoutAndRender() {
        let layout = computeLayout(for: text)
        lines = layout.lines
        bitmapWidth = layout.width
        bitmapHeight = layout.height
        flatBufferRGBA = renderFlatBanner()
        size = CGSize(
            width: CGFloat(bitmapWidth) * pixelScale,
            height: CGFloat(bitmapHeight) * pixelScale
        )
    }

    func tick(currentTime: TimeInterval) {
        if startTime == 0 { startTime = currentTime }
        if flatBufferRGBA.isEmpty { relayoutAndRender() }
        let t = currentTime - startTime
        texture = renderWavedTexture(time: t)
    }

    // MARK: - Layout

    private struct Layout {
        let width: Int
        let height: Int
        let lines: [String]
    }

    private func computeLayout(for text: String) -> Layout {
        let pad = horizontalPad * 2
        let singleW = max(minBitmapWidth, measureWidth(text) + pad)

        if singleW <= maxBitmapWidth {
            return Layout(width: singleW, height: singleLineHeight, lines: [text])
        }

        // Wrap to two lines, prefer breaking at a space near the middle.
        var (l1, l2) = splitForTwoLines(text)
        let maxInnerW = maxBitmapWidth - pad

        // If a line is still too long after wrapping, truncate with an ellipsis.
        if measureWidth(l1) > maxInnerW {
            l1 = truncate(l1, toFit: maxInnerW)
        }
        if measureWidth(l2) > maxInnerW {
            l2 = truncate(l2, toFit: maxInnerW)
        }

        let widest = max(measureWidth(l1), measureWidth(l2))
        let w = min(maxBitmapWidth, max(minBitmapWidth, widest + pad))
        return Layout(width: w, height: twoLineHeight, lines: [l1, l2])
    }

    private func splitForTwoLines(_ text: String) -> (String, String) {
        let chars = Array(text)
        let mid = chars.count / 2

        // Find the space closest to the midpoint.
        var bestIdx: Int? = nil
        var bestDelta = Int.max
        for (i, ch) in chars.enumerated() where ch == " " {
            let delta = abs(i - mid)
            if delta < bestDelta {
                bestDelta = delta
                bestIdx = i
            }
        }

        if let idx = bestIdx {
            let line1 = String(chars[0..<idx])
            let line2 = String(chars[(idx + 1)...])
            return (line1, line2)
        }
        // No spaces — hard split at the midpoint.
        let line1 = String(chars[0..<mid])
        let line2 = String(chars[mid...])
        return (line1, line2)
    }

    private func truncate(_ s: String, toFit maxWidth: Int) -> String {
        var trimmed = s
        while !trimmed.isEmpty && measureWidth(trimmed + "…") > maxWidth {
            trimmed.removeLast()
        }
        return trimmed + "…"
    }

    /// Measure the typographic width of `text` in logical pixels using the
    /// banner's pixel font.
    private func measureWidth(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: SpriteAssets.pixelFont(size: fontSize),
            .kern: 1
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
        let bounds = CTLineGetImageBounds(line, nil)
        return Int(ceil(bounds.width + bounds.origin.x))
    }

    // MARK: - Pass 1: flat banner

    private struct RGBA { var r, g, b, a: UInt8 }

    private let bodyColor    = RGBA(r: 0xFB, g: 0xEE, b: 0xC8, a: 0xFF) // cream
    private let stripeColor  = RGBA(r: 0xE4, g: 0x3A, b: 0x3A, a: 0xFF) // red
    private let borderDark   = RGBA(r: 0x6B, g: 0x21, b: 0x21, a: 0xFF) // dark red
    private let shadowColor  = RGBA(r: 0xC4, g: 0x9A, b: 0x6C, a: 0xFF) // tan shadow
    private let textColor    = RGBA(r: 0x1F, g: 0x12, b: 0x12, a: 0xFF) // near-black

    private func renderFlatBanner() -> [UInt8] {
        let w = bitmapWidth, h = bitmapHeight
        let bodyTop = h - 3
        let bodyBottom = 2
        var buf = [UInt8](repeating: 0, count: w * h * 4)

        for x in 0..<w {
            for y in 0..<h {
                guard y >= bodyBottom && y <= bodyTop else { continue }
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

        // Stamp text mask (1 or 2 lines) over the body.
        let textMask = renderTextMask()
        for x in 0..<w {
            for y in 0..<h {
                guard textMask[x + y * w] else { continue }
                guard y >= bodyBottom + 1 && y <= bodyTop - 1 else { continue }
                writePixel(&buf, x: x, y: y, w: w, h: h, color: textColor)
            }
        }

        return buf
    }

    /// Render the (already-wrapped) lines into a w×h boolean grid using CoreText.
    /// Returned mask is stored bottom-up (matches the flat-buffer Y convention).
    private func renderTextMask() -> [Bool] {
        let w = bitmapWidth, h = bitmapHeight
        var mask = [Bool](repeating: false, count: w * h)
        guard !lines.isEmpty, !lines.allSatisfy({ $0.isEmpty }) else { return mask }

        let cs = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w,
            space: cs, bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return mask }
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        let attrs: [NSAttributedString.Key: Any] = [
            .font: SpriteAssets.pixelFont(size: fontSize),
            .foregroundColor: NSColor.white,
            .kern: 1
        ]

        let bodyCenterY = CGFloat(2 + (h - 3 - 2)) / 2 + 1
        let lineHeight: CGFloat = 10 // 8px glyph + 2px gap

        for (i, lineText) in lines.enumerated() where !lineText.isEmpty {
            let str = NSAttributedString(string: lineText, attributes: attrs)
            let ct = CTLineCreateWithAttributedString(str)
            let bounds = CTLineGetImageBounds(ct, ctx)

            // Center horizontally inside the body.
            let leftPad = CGFloat(horizontalPad)
            let availableW = CGFloat(w) - 2 * leftPad
            let xPos = leftPad + max(0, (availableW - bounds.width) / 2) - bounds.origin.x

            // Vertical placement:
            //   1 line  → centered on bodyCenterY
            //   2 lines → line[0] above center, line[1] below
            let baselineCenter: CGFloat
            if lines.count == 1 {
                baselineCenter = bodyCenterY
            } else {
                // i=0 is the FIRST line (visually on top → higher Y in bottom-up coords)
                baselineCenter = bodyCenterY + (CGFloat(lines.count - 1) / 2 - CGFloat(i)) * lineHeight
            }
            let yPos = baselineCenter - bounds.height / 2 - bounds.origin.y

            ctx.textPosition = CGPoint(x: round(xPos), y: round(yPos))
            CTLineDraw(ct, ctx)
        }

        guard let data = ctx.data else { return mask }
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        // CG memory rows are top-down; convert to bottom-up so it matches the flat buffer.
        for y in 0..<h {
            for x in 0..<w {
                let srcRow = h - 1 - y
                let v = bytes[x + srcRow * w]
                mask[x + y * w] = v > 96
            }
        }
        return mask
    }

    private func writePixel(_ buf: inout [UInt8], x: Int, y: Int, w: Int, h: Int, color: RGBA) {
        let i = (y * w + x) * 4
        buf[i] = color.r
        buf[i + 1] = color.g
        buf[i + 2] = color.b
        buf[i + 3] = color.a
    }

    // MARK: - Pass 2: wave shear

    private func renderWavedTexture(time: TimeInterval) -> SKTexture {
        let w = bitmapWidth, h = bitmapHeight
        let amplitude: CGFloat = max(0, CGFloat(AppSettings.shared.bannerAmplitude))
        let frequency: CGFloat = max(0.1, CGFloat(AppSettings.shared.bannerFrequency))
        let phaseStep: CGFloat = CGFloat(AppSettings.shared.bannerPhaseStep)

        var out = [UInt8](repeating: 0, count: w * h * 4)
        for x in 0..<w {
            let phase = CGFloat(time) * frequency + CGFloat(x) * phaseStep
            let yOff = Int(round(amplitude * sin(phase)))
            for y in 0..<h {
                let srcY = y - yOff
                guard srcY >= 0 && srcY < h else { continue }
                let srcI = (srcY * w + x) * 4
                let dstRow = h - 1 - y
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
