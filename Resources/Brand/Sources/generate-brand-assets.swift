// Core Bloom brand asset generator — editable source of truth.
// Run: swift Resources/Brand/Sources/generate-brand-assets.swift
// Outputs to Resources/Brand/Generated/: AppIcon.icns, AppIcon.iconset,
// menubar template PNGs (16/32 @1x/@2x).
// Pure CoreGraphics — no Xcode, no raster sources.

import AppKit
import CoreGraphics

let out = URL(fileURLWithPath: "Resources/Brand/Generated", isDirectory: true)
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

// Geometry mirrors Sources/DesignSystem/CoreBloom.swift (MCBloomGeometry).
let arcs: [(start: Double, span: Double, radius: CGFloat)] = [
    (-30, 150, 0.94), (105, 115, 0.72), (250, 80, 0.50),
]
let nucleusFraction: CGFloat = 0.24

struct RGB { let r, g, b: CGFloat }
let mintDark = RGB(r: 0.30, g: 0.83, b: 0.75)
let violetDark = RGB(r: 0.60, g: 0.57, b: 0.96)
let amberDark = RGB(r: 0.95, g: 0.68, b: 0.26)
let arcColors = [mintDark, violetDark, amberDark]

func cgColor(_ c: RGB, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: a)
}

func rad(_ deg: Double) -> CGFloat { CGFloat((deg - 90) * .pi / 180) }

/// Draws the Core Bloom mark centered in `rect` (arcs + nucleus).
func drawBloom(_ ctx: CGContext, rect: CGRect, lineWidthFraction: CGFloat,
               monochrome: CGColor? = nil, glow: Bool = false) {
    let side = min(rect.width, rect.height)
    let c = CGPoint(x: rect.midX, y: rect.midY)
    let lw = max(1, side * lineWidthFraction)
    for (i, a) in arcs.enumerated() {
        let color = monochrome ?? cgColor(arcColors[i])
        if glow {
            ctx.setShadow(offset: .zero, blur: side * 0.05, color: cgColor(arcColors[i], 0.8))
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
        // Mint nucleus with soft radial highlight.
        let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [cgColor(RGB(r: 0.55, g: 0.95, b: 0.88)),
                                       cgColor(RGB(r: 0.10, g: 0.62, b: 0.55))] as CFArray,
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

func makeContext(_ px: Int) -> CGContext {
    CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func savePNG(_ image: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

/// macOS app icon: squircle-ish rounded rect on transparent canvas,
/// mineral depth gradient, outer halo, arcs, nucleus.
func appIcon(px: Int) -> CGImage {
    let ctx = makeContext(px)
    let s = CGFloat(px)
    let inset = s * 0.098          // Apple macOS icon grid margin
    let iconRect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = iconRect.width * 0.225

    // Base shape + mineral gradient (deep graphite blue-green).
    let path = CGPath(roundedRect: iconRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path)
    ctx.clip()
    let bg = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                        colors: [CGColor(srgbRed: 0.10, green: 0.14, blue: 0.17, alpha: 1),
                                 CGColor(srgbRed: 0.045, green: 0.065, blue: 0.09, alpha: 1)] as CFArray,
                        locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

    // Outer halo behind the bloom.
    let haloGrad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [cgColor(mintDark, 0.20), cgColor(mintDark, 0)] as CFArray,
                              locations: [0, 1])!
    ctx.drawRadialGradient(haloGrad,
        startCenter: CGPoint(x: s / 2, y: s / 2), startRadius: 0,
        endCenter: CGPoint(x: s / 2, y: s / 2), endRadius: iconRect.width * 0.52, options: [])

    // Bloom, slightly smaller than the plate.
    let bloomRect = iconRect.insetBy(dx: iconRect.width * 0.16, dy: iconRect.height * 0.16)
    drawBloom(ctx, rect: bloomRect, lineWidthFraction: px < 64 ? 0.12 : 0.075, glow: px >= 128)

    // Top light: subtle sheen.
    let sheen = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                           colors: [CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.07),
                                    CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
                           locations: [0, 1])!
    ctx.drawLinearGradient(sheen, start: CGPoint(x: 0, y: s),
                           end: CGPoint(x: 0, y: s * 0.55), options: [])
    return ctx.makeImage()!
}

/// Menu bar template: monochrome black bloom on transparent bg.
func menubarTemplate(px: Int) -> CGImage {
    let ctx = makeContext(px)
    let rect = CGRect(x: 0, y: 0, width: px, height: px).insetBy(dx: CGFloat(px) * 0.08, dy: CGFloat(px) * 0.08)
    drawBloom(ctx, rect: rect, lineWidthFraction: 0.11, monochrome: CGColor(gray: 0, alpha: 1))
    return ctx.makeImage()!
}

// --- iconset ---
let iconset = out.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    savePNG(appIcon(px: size), to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    savePNG(appIcon(px: size * 2), to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}

// --- menubar templates ---
savePNG(menubarTemplate(px: 18), to: out.appendingPathComponent("MenuBarTemplate.png"))
savePNG(menubarTemplate(px: 36), to: out.appendingPathComponent("MenuBarTemplate@2x.png"))

// --- standalone logo exports ---
savePNG(appIcon(px: 1024), to: out.appendingPathComponent("AppIcon-1024.png"))

print("Generated in \(out.path)")
