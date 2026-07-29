// CoreTend brand asset generator — the editable source of truth for every
// rendered mark in the product, the installer, and the website.
//
// Run from the repository root:
//   swift Resources/Brand/Sources/generate-brand-assets.swift
//
// Design: Living System, built on Orbital Ecology. A circular nucleus orbited
// by three asymmetric arcs, with a deliberate opening in the outer arc —
// the mark reads as something breathing, and as space that has been given
// back. No broom, no bin, no shield, no eraser, no rocket.
//
// Geometry mirrors Sources/DesignSystem/CoreBloom.swift (MCBloomGeometry) and
// colours mirror MCColor.LivingSystem, so the app, the icon, and the site
// cannot drift apart. Pure CoreGraphics + hand-written SVG — no Xcode, no
// raster sources, no external tooling.

import AppKit
import CoreGraphics

let out = URL(fileURLWithPath: "Resources/Brand/Generated", isDirectory: true)
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

// MARK: - Geometry (must match MCBloomGeometry)

let arcs: [(start: Double, span: Double, radius: CGFloat)] = [
    (-30, 150, 0.94),   // storage and care — outer, with the opening
    (105, 115, 0.72),   // privacy and protection — middle
    (250, 80, 0.50),    // activity and performance — inner
]
let nucleusFraction: CGFloat = 0.24

// MARK: - Living System palette

struct RGB: Equatable {
    let r, g, b: CGFloat
    var hex: String {
        String(format: "#%02X%02X%02X", Int(r * 255 + 0.5), Int(g * 255 + 0.5), Int(b * 255 + 0.5))
    }
}

let coreInk       = RGB(r: 0.043, g: 0.059, b: 0.078)   // #0B0F14
let softPorcelain = RGB(r: 0.957, g: 0.965, b: 0.953)   // #F4F6F3
let livingMoss    = RGB(r: 0.455, g: 0.643, b: 0.529)   // #74A487
let freshMint     = RGB(r: 0.659, g: 0.902, b: 0.757)   // #A8E6C1
let orbitIris     = RGB(r: 0.608, g: 0.541, b: 0.984)   // #9B8AFB
let warmAmber     = RGB(r: 0.957, g: 0.780, b: 0.420)   // #F4C76B
let mutedSlate    = RGB(r: 0.467, g: 0.506, b: 0.557)   // #77818E

// Light-surface siblings, so the mark stays legible on Soft Porcelain. Same
// hues, lower luminance — see the divergence note in Colors.swift.
let mossDeep  = RGB(r: 0.075, g: 0.404, b: 0.290)
let irisDeep  = RGB(r: 0.360, g: 0.330, b: 0.800)
let amberDeep = RGB(r: 0.580, g: 0.375, b: 0.040)
let slateDeep = RGB(r: 0.310, g: 0.345, b: 0.392)

let arcColorsDark  = [freshMint, orbitIris, warmAmber]
let arcColorsLight = [mossDeep, irisDeep, amberDeep]

func cgColor(_ c: RGB, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: a)
}

func rad(_ deg: Double) -> CGFloat { CGFloat((deg - 90) * .pi / 180) }

// MARK: - Raster drawing

/// Draws the mark centred in `rect`. `monochrome` overrides every colour, for
/// template and single-ink use.
func drawBloom(_ ctx: CGContext, rect: CGRect, lineWidthFraction: CGFloat,
               palette: [RGB] = arcColorsDark,
               monochrome: CGColor? = nil, glow: Bool = false) {
    let side = min(rect.width, rect.height)
    let c = CGPoint(x: rect.midX, y: rect.midY)
    let lw = max(1, side * lineWidthFraction)
    for (i, a) in arcs.enumerated() {
        let color = monochrome ?? cgColor(palette[i])
        if glow {
            ctx.setShadow(offset: .zero, blur: side * 0.05, color: cgColor(palette[i], 0.8))
        }
        ctx.setStrokeColor(color)
        ctx.setLineWidth(lw)
        ctx.setLineCap(.round)
        ctx.addArc(center: c, radius: side / 2 * a.radius,
                   startAngle: rad(a.start), endAngle: rad(a.start + a.span), clockwise: false)
        ctx.strokePath()
    }
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    let nd = side * nucleusFraction
    let nucleusRect = CGRect(x: c.x - nd / 2, y: c.y - nd / 2, width: nd, height: nd)
    if let monochrome {
        ctx.setFillColor(monochrome)
        ctx.fillEllipse(in: nucleusRect)
    } else {
        let onLight = palette == arcColorsLight
        let bright = onLight ? RGB(r: 0.180, g: 0.520, b: 0.380) : RGB(r: 0.780, g: 0.960, b: 0.870)
        let deep = onLight ? RGB(r: 0.040, g: 0.300, b: 0.220) : RGB(r: 0.180, g: 0.620, b: 0.520)
        let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [cgColor(bright), cgColor(deep)] as CFArray,
                              locations: [0, 1])!
        ctx.saveGState()
        ctx.addEllipse(in: nucleusRect)
        ctx.clip()
        ctx.drawRadialGradient(grad,
            startCenter: CGPoint(x: c.x - nd * 0.18, y: c.y + nd * 0.2), startRadius: 0,
            endCenter: c, endRadius: nd * 0.75, options: [.drawsAfterEndLocation])
        ctx.restoreGState()
    }
}

func makeContext(_ w: Int, _ h: Int) -> CGContext {
    CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func makeContext(_ px: Int) -> CGContext { makeContext(px, px) }

func savePNG(_ image: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

// MARK: - Wordmark

/// The wordmark is drawn from a real system face rather than traced outlines,
/// so it stays crisp at every size and needs no font shipped alongside it.
/// Tracking opens at small sizes, which is what keeps "CoreTend" from closing
/// up into a single shape when it is only a dozen pixels tall.
func wordmarkAttributed(pointSize: CGFloat, color: RGB) -> NSAttributedString {
    let tracking = pointSize < 24 ? pointSize * 0.045 : pointSize * 0.015
    let font = NSFont.systemFont(ofSize: pointSize, weight: .semibold)
    return NSAttributedString(string: "CoreTend", attributes: [
        .font: font,
        .foregroundColor: NSColor(cgColor: cgColor(color))!,
        .kern: tracking,
    ])
}

@discardableResult
func drawWordmark(_ ctx: CGContext, at origin: CGPoint, pointSize: CGFloat, color: RGB) -> CGSize {
    let text = wordmarkAttributed(pointSize: pointSize, color: color)
    let gc = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gc
    text.draw(at: origin)
    NSGraphicsContext.restoreGraphicsState()
    return text.size()
}

func drawText(_ ctx: CGContext, _ string: String, at origin: CGPoint,
              size: CGFloat, weight: NSFont.Weight, color: RGB) -> CGSize {
    let text = NSAttributedString(string: string, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor(cgColor: cgColor(color))!,
    ])
    let gc = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gc
    text.draw(at: origin)
    NSGraphicsContext.restoreGraphicsState()
    return text.size()
}

// MARK: - App icon

/// macOS app icon: rounded plate on a transparent canvas, mineral depth,
/// outer halo, arcs, nucleus. The stroke thickens at small sizes because a
/// hairline arc disappears entirely at 16 px.
func appIcon(px: Int) -> CGImage {
    let ctx = makeContext(px)
    let s = CGFloat(px)
    let inset = s * 0.098          // Apple macOS icon grid margin
    let iconRect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = iconRect.width * 0.225

    let path = CGPath(roundedRect: iconRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path)
    ctx.clip()
    let bg = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                        colors: [CGColor(srgbRed: 0.086, green: 0.118, blue: 0.145, alpha: 1),
                                 cgColor(coreInk)] as CFArray,
                        locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

    let haloGrad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [cgColor(freshMint, 0.20), cgColor(freshMint, 0)] as CFArray,
                              locations: [0, 1])!
    ctx.drawRadialGradient(haloGrad,
        startCenter: CGPoint(x: s / 2, y: s / 2), startRadius: 0,
        endCenter: CGPoint(x: s / 2, y: s / 2), endRadius: iconRect.width * 0.52, options: [])

    let bloomRect = iconRect.insetBy(dx: iconRect.width * 0.16, dy: iconRect.height * 0.16)
    drawBloom(ctx, rect: bloomRect, lineWidthFraction: px < 64 ? 0.12 : 0.075, glow: px >= 128)

    let sheen = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                           colors: [CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.07),
                                    CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
                           locations: [0, 1])!
    ctx.drawLinearGradient(sheen, start: CGPoint(x: 0, y: s),
                           end: CGPoint(x: 0, y: s * 0.55), options: [])
    return ctx.makeImage()!
}

/// Menu bar template: monochrome black, transparent background. macOS
/// recolours it for light/dark menu bars, so it must contain no colour of its
/// own — the arcs' shapes carry the whole identity here.
func menubarTemplate(px: Int) -> CGImage {
    let ctx = makeContext(px)
    let rect = CGRect(x: 0, y: 0, width: px, height: px).insetBy(dx: CGFloat(px) * 0.08, dy: CGFloat(px) * 0.08)
    drawBloom(ctx, rect: rect, lineWidthFraction: 0.11, monochrome: CGColor(gray: 0, alpha: 1))
    return ctx.makeImage()!
}

/// Favicon: no plate, no halo, no gradient. At 16 px the plate swallows the
/// mark, so the mark alone on transparency reads better in a browser tab.
func favicon(px: Int) -> CGImage {
    let ctx = makeContext(px)
    let rect = CGRect(x: 0, y: 0, width: px, height: px).insetBy(dx: CGFloat(px) * 0.06, dy: CGFloat(px) * 0.06)
    drawBloom(ctx, rect: rect, lineWidthFraction: px < 48 ? 0.13 : 0.085)
    return ctx.makeImage()!
}

// MARK: - Lockups

enum Surface {
    case dark, light

    var background: RGB { self == .dark ? coreInk : softPorcelain }
    var palette: [RGB] { self == .dark ? arcColorsDark : arcColorsLight }
    var wordmarkColor: RGB { self == .dark ? softPorcelain : coreInk }
    var subtitleColor: RGB { self == .dark ? mutedSlate : slateDeep }
    var name: String { self == .dark ? "dark" : "light" }
}

/// Horizontal lockup: mark, then wordmark, on a filled plate.
func horizontalLogo(height px: Int, surface: Surface, monochrome: RGB? = nil) -> CGImage {
    let h = CGFloat(px)
    let markSide = h * 0.78
    let pointSize = h * 0.46
    let gap = h * 0.24
    let textSize = wordmarkAttributed(pointSize: pointSize, color: surface.wordmarkColor).size()
    let w = Int((h * 0.28 + markSide + gap + textSize.width + h * 0.32).rounded(.up))

    let ctx = makeContext(w, px)
    ctx.setFillColor(cgColor(surface.background))
    ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(w), height: h))

    let markRect = CGRect(x: h * 0.28, y: (h - markSide) / 2, width: markSide, height: markSide)
    if let monochrome {
        drawBloom(ctx, rect: markRect, lineWidthFraction: 0.085, monochrome: cgColor(monochrome))
    } else {
        drawBloom(ctx, rect: markRect, lineWidthFraction: 0.085, palette: surface.palette)
    }
    drawWordmark(ctx, at: CGPoint(x: markRect.maxX + gap, y: (h - textSize.height) / 2 + h * 0.02),
                 pointSize: pointSize, color: monochrome ?? surface.wordmarkColor)
    return ctx.makeImage()!
}

/// Compact lockup: mark over wordmark, for square placements.
func compactLogo(side px: Int, surface: Surface) -> CGImage {
    let s = CGFloat(px)
    let ctx = makeContext(px)
    ctx.setFillColor(cgColor(surface.background))
    ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))
    let markSide = s * 0.52
    let markRect = CGRect(x: (s - markSide) / 2, y: s * 0.30, width: markSide, height: markSide)
    drawBloom(ctx, rect: markRect, lineWidthFraction: 0.085, palette: surface.palette)
    let pointSize = s * 0.135
    let ts = wordmarkAttributed(pointSize: pointSize, color: surface.wordmarkColor).size()
    drawWordmark(ctx, at: CGPoint(x: (s - ts.width) / 2, y: s * 0.13),
                 pointSize: pointSize, color: surface.wordmarkColor)
    return ctx.makeImage()!
}

/// Open Graph card, 1200x630. This is the image a link preview shows, so it
/// has to say what the product is without the reader clicking anything.
func openGraph() -> CGImage {
    let w = 1200, h = 630
    let ctx = makeContext(w, h)
    ctx.setFillColor(cgColor(coreInk))
    ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))

    // Off-centre halo, echoing the mark's own asymmetry.
    let halo = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                          colors: [cgColor(freshMint, 0.16), cgColor(freshMint, 0)] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(halo, startCenter: CGPoint(x: 900, y: 430), startRadius: 0,
                           endCenter: CGPoint(x: 900, y: 430), endRadius: 520, options: [])

    drawBloom(ctx, rect: CGRect(x: 760, y: 175, width: 340, height: 340),
              lineWidthFraction: 0.075, glow: true)

    drawWordmark(ctx, at: CGPoint(x: 96, y: 386), pointSize: 96, color: softPorcelain)
    _ = drawText(ctx, "A lighter Mac. Always under control.", at: CGPoint(x: 96, y: 300),
                 size: 40, weight: .medium, color: freshMint)
    _ = drawText(ctx, "Local, transparent and reversible care for macOS.", at: CGPoint(x: 96, y: 240),
                 size: 28, weight: .regular, color: mutedSlate)
    return ctx.makeImage()!
}

/// DMG window background, 600x400 points (1200x800 at @2x).
///
/// Carries the same paper/ink/cobalt palette as the website and the portfolio,
/// not the dark Living System surface — the installer is the first thing a
/// visitor sees after the landing page, so the two have to read as one system.
///
/// Everything is positioned against the icon centres the .DS_Store records:
/// CoreTend at (170, 215) and Applications at (430, 215) in Finder's
/// top-left-origin space, which is y = 185 here because CoreGraphics counts
/// from the bottom. Change one and you must change the other, or the artwork
/// stops lining up with the icons it is drawn around.
let dmgIconY: CGFloat = 215          // Finder space, from the top
let dmgAppX: CGFloat = 170
let dmgApplicationsX: CGFloat = 430
let dmgCanvas = CGSize(width: 600, height: 400)

func dmgBackground(scale: Int = 1) -> CGImage {
    let w = Int(dmgCanvas.width) * scale, h = Int(dmgCanvas.height) * scale
    let f = CGFloat(scale)
    let ctx = makeContext(w, h)

    // Paper, very slightly warmer at the top so the surface is not dead flat.
    let paper = RGB(r: 0.957, g: 0.957, b: 0.941)   // #F4F4F0, --paper
    let card  = RGB(r: 0.988, g: 0.988, b: 0.980)   // #FCFCFA, --card
    let ink   = RGB(r: 0.090, g: 0.098, b: 0.114)   // #17191D, --ink
    let sub   = RGB(r: 0.286, g: 0.306, b: 0.341)   // #494E57, --sub
    let dim   = RGB(r: 0.420, g: 0.440, b: 0.475)   // #6B7079, --dim
    let cobalt = RGB(r: 0.133, g: 0.251, b: 0.886)  // #2240E2, --cobalt

    let bg = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                        colors: [cgColor(card), cgColor(paper)] as CFArray,
                        locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: CGFloat(h)), end: CGPoint(x: 0, y: 0), options: [])

    // Cobalt halo behind the app icon — the eye should land there first, since
    // that is the thing the user has to pick up.
    // Two wells, one under each icon, joined by the guide line. A diffuse radial
    // halo was tried first and rejected: at the low alpha paper needs, cobalt
    // desaturates into a grey bruise. A bounded disc with a hairline ring keeps
    // the hue and reads as a deliberate slot for the icon to sit in.
    let iconCGY = (dmgCanvas.height - dmgIconY) * f
    // Wide enough to contain a 104pt icon *and* its label. At r=74 the ring cut
    // straight through the "CoreTend" and "Applications" text — verified by
    // mounting the image and looking at it, which is the only way to catch this.
    let wellR: CGFloat = 86 * f

    func drawWell(centerX: CGFloat, tint: RGB, fillAlpha: CGFloat, ringAlpha: CGFloat) {
        let c = CGPoint(x: centerX * f, y: iconCGY)
        let soft = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [cgColor(tint, fillAlpha), cgColor(tint, 0)] as CFArray,
                              locations: [0, 1])!
        ctx.saveGState()
        ctx.addEllipse(in: CGRect(x: c.x - wellR, y: c.y - wellR, width: wellR * 2, height: wellR * 2))
        ctx.clip()
        ctx.drawRadialGradient(soft, startCenter: c, startRadius: 0,
                               endCenter: c, endRadius: wellR, options: [])
        ctx.restoreGState()
        ctx.setStrokeColor(cgColor(tint, ringAlpha))
        ctx.setLineWidth(1 * f)
        ctx.strokeEllipse(in: CGRect(x: c.x - wellR, y: c.y - wellR,
                                     width: wellR * 2, height: wellR * 2))
    }

    // The source well carries the cobalt; the destination stays neutral, so the
    // colour itself points at the thing the user has to pick up.
    drawWell(centerX: dmgAppX, tint: cobalt, fillAlpha: 0.10, ringAlpha: 0.28)
    drawWell(centerX: dmgApplicationsX, tint: dim, fillAlpha: 0.05, ringAlpha: 0.20)

    // Mark and wordmark, top centre, small. The installer is not a poster.
    drawBloom(ctx, rect: CGRect(x: 276 * f, y: 322 * f, width: 48 * f, height: 48 * f),
              lineWidthFraction: 0.09, palette: arcColorsLight)
    let ws = wordmarkAttributed(pointSize: 19 * f, color: ink).size()
    drawWordmark(ctx, at: CGPoint(x: (CGFloat(w) - ws.width) / 2, y: 296 * f),
                 pointSize: 19 * f, color: ink)

    // The guide line runs between the two icon centres, stopping clear of both
    // so it never collides with an icon or its label. Dashed, hairline, cobalt:
    // it should read as direction, not as decoration.
    let lineStart = dmgAppX * f + wellR + 12 * f
    let lineEnd = dmgApplicationsX * f - wellR - 12 * f
    ctx.saveGState()
    ctx.setStrokeColor(cgColor(cobalt, 0.42))
    ctx.setLineWidth(1.5 * f)
    ctx.setLineCap(.round)
    ctx.setLineDash(phase: 0, lengths: [1.5 * f, 6 * f])
    ctx.move(to: CGPoint(x: lineStart, y: iconCGY))
    ctx.addLine(to: CGPoint(x: lineEnd - 10 * f, y: iconCGY))
    ctx.strokePath()
    ctx.restoreGState()

    // One chevron at the end of the line. Drawn as strokes rather than typed as
    // a character, so it cannot depend on a font being installed.
    ctx.setStrokeColor(cgColor(cobalt, 0.85))
    ctx.setLineWidth(2 * f)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: lineEnd - 9 * f, y: iconCGY + 6 * f))
    ctx.addLine(to: CGPoint(x: lineEnd, y: iconCGY))
    ctx.addLine(to: CGPoint(x: lineEnd - 9 * f, y: iconCGY - 6 * f))
    ctx.strokePath()

    // Minimal instruction, well below the icon labels.
    let hint = "Drag CoreTend to Applications"
    let hs = NSAttributedString(string: hint, attributes: [
        .font: NSFont.systemFont(ofSize: 13 * f, weight: .medium)]).size()
    _ = drawText(ctx, hint, at: CGPoint(x: (CGFloat(w) - hs.width) / 2, y: 56 * f),
                 size: 13 * f, weight: .medium, color: sub)

    let note = "Unsigned build — first launch needs System Settings › Privacy & Security"
    let ns = NSAttributedString(string: note, attributes: [
        .font: NSFont.systemFont(ofSize: 10 * f, weight: .regular)]).size()
    _ = drawText(ctx, note, at: CGPoint(x: (CGFloat(w) - ns.width) / 2, y: 34 * f),
                 size: 10 * f, weight: .regular, color: dim)

    drawPaperGrain(ctx, width: w, height: h)
    return ctx.makeImage()!
}

/// Fixed-seed value noise. Deterministic on purpose: the DMG is checksummed and
/// signed, so two builds of the same commit have to produce identical bytes.
func drawPaperGrain(_ ctx: CGContext, width: Int, height: Int) {
    var seed: UInt64 = 0x00C0_FFEE_CAFE_D00D
    func next() -> Double {
        seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
        return Double(seed % 10_000) / 10_000
    }
    ctx.saveGState()
    for _ in 0..<(width * height / 90) {
        let x = next() * Double(width), y = next() * Double(height)
        let dark = next() < 0.5
        ctx.setFillColor(CGColor(gray: dark ? 0 : 1, alpha: dark ? 0.030 : 0.045))
        ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
    }
    ctx.restoreGState()
}

// MARK: - Vector output (SVG + PDF)

/// Arc endpoints for an SVG `A` command. SVG has no "arc by angle", so the
/// sweep is expressed as start point, end point, a large-arc flag and a sweep
/// flag — this converts from the same (start, span) the app animates.
///
/// Two coordinate details decide whether the SVG matches the raster, and the
/// mark is asymmetric enough that getting either wrong is immediately visible:
/// SVG's y axis grows downward where CoreGraphics' grows upward, so y is
/// mirrored; and once y is mirrored, CoreGraphics' increasing-angle sweep
/// reads as the opposite direction, so the sweep flag is 0, not 1.
func svgArcPath(cx: Double, cy: Double, r: Double, start: Double, span: Double) -> String {
    func point(_ deg: Double) -> (Double, Double) {
        let a = (deg - 90) * .pi / 180
        return (cx + r * cos(a), cy - r * sin(a))
    }
    let (x0, y0) = point(start)
    let (x1, y1) = point(start + span)
    let largeArc = span > 180 ? 1 : 0
    return String(format: "M %.3f %.3f A %.3f %.3f 0 %d 0 %.3f %.3f", x0, y0, r, r, largeArc, x1, y1)
}

/// The mark as SVG. This is the vector source of truth: every raster above is
/// a rendering of the same numbers, and this is the file a designer opens.
func markSVG(surface: Surface, monochrome: String? = nil, side: Double = 512) -> String {
    let palette = surface.palette
    let c = side / 2
    let lw = side * 0.075
    var body = ""
    for (i, a) in arcs.enumerated() {
        let stroke = monochrome ?? palette[i].hex
        let path = svgArcPath(cx: c, cy: c, r: side / 2 * Double(a.radius), start: a.start, span: a.span)
        body += "  <path d=\"\(path)\" fill=\"none\" stroke=\"\(stroke)\" "
        body += "stroke-width=\"\(String(format: "%.2f", lw))\" stroke-linecap=\"round\"/>\n"
    }
    let nucleusR = side * Double(nucleusFraction) / 2
    let nucleusFill = monochrome ?? (surface == .dark ? freshMint.hex : mossDeep.hex)
    body += "  <circle cx=\"\(String(format: "%.2f", c))\" cy=\"\(String(format: "%.2f", c))\" "
    body += "r=\"\(String(format: "%.2f", nucleusR))\" fill=\"\(nucleusFill)\"/>\n"

    return """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(Int(side)) \(Int(side))" \
    width="\(Int(side))" height="\(Int(side))" role="img" aria-label="CoreTend">
      <title>CoreTend</title>
    \(body)</svg>

    """
}

/// Vector PDF of the mark, for print and for any tool that prefers PDF.
func writeMarkPDF(to url: URL, surface: Surface) {
    let side: CGFloat = 512
    var box = CGRect(x: 0, y: 0, width: side, height: side)
    guard let consumer = CGDataConsumer(url: url as CFURL),
          let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
    ctx.beginPDFPage(nil)
    drawBloom(ctx, rect: box, lineWidthFraction: 0.075, palette: surface.palette)
    ctx.endPDFPage()
    ctx.closePDF()
}

// MARK: - Emit everything

let iconset = out.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    savePNG(appIcon(px: size), to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    savePNG(appIcon(px: size * 2), to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
savePNG(appIcon(px: 1024), to: out.appendingPathComponent("AppIcon-1024.png"))

savePNG(menubarTemplate(px: 18), to: out.appendingPathComponent("MenuBarTemplate.png"))
savePNG(menubarTemplate(px: 36), to: out.appendingPathComponent("MenuBarTemplate@2x.png"))

for size in [16, 32, 48, 180, 512] {
    savePNG(favicon(px: size), to: out.appendingPathComponent("Favicon-\(size).png"))
}

for surface in [Surface.dark, .light] {
    savePNG(horizontalLogo(height: 128, surface: surface),
            to: out.appendingPathComponent("Logo-Horizontal-\(surface.name).png"))
    savePNG(horizontalLogo(height: 256, surface: surface),
            to: out.appendingPathComponent("Logo-Horizontal-\(surface.name)@2x.png"))
    savePNG(compactLogo(side: 512, surface: surface),
            to: out.appendingPathComponent("Logo-Compact-\(surface.name).png"))
}
savePNG(horizontalLogo(height: 128, surface: .dark, monochrome: softPorcelain),
        to: out.appendingPathComponent("Logo-Horizontal-mono-light-ink.png"))
savePNG(horizontalLogo(height: 128, surface: .light, monochrome: coreInk),
        to: out.appendingPathComponent("Logo-Horizontal-mono-dark-ink.png"))

savePNG(compactLogo(side: 768, surface: .dark),
        to: out.appendingPathComponent("Onboarding-Hero.png"))

savePNG(openGraph(), to: out.appendingPathComponent("OpenGraph-1200x630.png"))
savePNG(dmgBackground(), to: out.appendingPathComponent("DMG-Background.png"))
savePNG(dmgBackground(scale: 2), to: out.appendingPathComponent("DMG-Background@2x.png"))

for surface in [Surface.dark, .light] {
    try! markSVG(surface: surface).write(
        to: out.appendingPathComponent("Mark-\(surface.name).svg"), atomically: true, encoding: .utf8)
    writeMarkPDF(to: out.appendingPathComponent("Mark-\(surface.name).pdf"), surface: surface)
}
try! markSVG(surface: .dark, monochrome: "currentColor").write(
    to: out.appendingPathComponent("Mark-monochrome.svg"), atomically: true, encoding: .utf8)

print("Generated in \(out.path)")
