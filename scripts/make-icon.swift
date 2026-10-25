#!/usr/bin/env swift
// Renders the dotlocal app icon and menu bar template image from the spec.
//
//   swift scripts/make-icon.swift
//
// The mark is two colours: one flat background and one circle with three
// server units cut out of it, lights on the circle's centre line. Geometry is
// defined on a 1024-unit plate and scaled into Apple's 824-of-1024 icon grid.
// Nothing else is drawn: no gradient, no stroke, no shadow.

import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let appIconDir = root.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset")
let menuBarDir = root.appendingPathComponent("Resources/Assets.xcassets/MenuBarIcon.imageset")

let background = CGColor(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF4 / 255, alpha: 1)  // #f2f2f4
let ink = CGColor(red: 0x2B / 255, green: 0x2B / 255, blue: 0x2F / 255, alpha: 1)         // #2b2b2f

/// Spec in 1024 plate units.
struct Mark {
    var circleCenter = CGPoint(x: 524, y: 512)
    var circleRadius: CGFloat = 430
    var unitsLeft: CGFloat = 432        // lights sit on the circle's centre line
    var unitsHeight: CGFloat = 912      // overshoots the circle; the circle clips the corners
    var gap: CGFloat = 48
    var cornerRadius: CGFloat = 32
    var lightRadius: CGFloat = 24
}

/// Draws the mark (ink on transparent) into `ctx`, which must already be scaled
/// so that one unit of `plate` maps onto the plate's coordinate space.
func drawMark(_ m: Mark, in ctx: CGContext, plate: CGFloat, ink: CGColor) {
    ctx.saveGState()
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    let circle = CGRect(x: m.circleCenter.x - m.circleRadius, y: m.circleCenter.y - m.circleRadius,
                        width: m.circleRadius * 2, height: m.circleRadius * 2)
    ctx.setFillColor(ink)
    ctx.fillEllipse(in: circle)
    // No clip here on purpose: outside the circle the layer is already
    // transparent, and clipping would leave the circle's anti-aliased edge
    // pixels half-cleared inside the cuts, which shows as a hairline ring.
    let unitHeight = (m.unitsHeight - 2 * m.gap) / 3
    let top = m.circleCenter.y - m.unitsHeight / 2
    ctx.setBlendMode(.clear)
    for k in 0..<3 {
        let y = top + CGFloat(k) * (unitHeight + m.gap)
        let rect = CGRect(x: m.unitsLeft, y: y, width: plate, height: unitHeight)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: m.cornerRadius, cornerHeight: m.cornerRadius, transform: nil))
        ctx.fillPath()
    }
    ctx.setBlendMode(.normal)
    ctx.setFillColor(ink)
    for k in 0..<3 {
        let cy = top + CGFloat(k) * (unitHeight + m.gap) + unitHeight / 2
        ctx.fillEllipse(in: CGRect(x: m.circleCenter.x - m.lightRadius, y: cy - m.lightRadius,
                                   width: m.lightRadius * 2, height: m.lightRadius * 2))
    }
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

func makeContext(_ px: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Flip so y grows downwards, matching the spec.
    ctx.translateBy(x: 0, y: CGFloat(px))
    ctx.scaleBy(x: 1, y: -1)
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    return ctx
}

func writePNG(_ ctx: CGContext, to url: URL) {
    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: image.width, height: image.height)
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: url)
    print("wrote \(url.lastPathComponent) (\(image.width)px)")
}

/// App icon: Apple's macOS grid puts the plate at 824 of 1024, centred.
func renderAppIcon(px: Int, to url: URL) {
    let ctx = makeContext(px)
    let s = CGFloat(px) / 1024
    ctx.scaleBy(x: s, y: s)
    let plateRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let plateRadius: CGFloat = 824 * 0.2237
    ctx.setFillColor(background)
    ctx.addPath(CGPath(roundedRect: plateRect, cornerWidth: plateRadius, cornerHeight: plateRadius, transform: nil))
    ctx.fillPath()
    ctx.translateBy(x: 100, y: 100)
    ctx.scaleBy(x: 824 / 1024, y: 824 / 1024)
    drawMark(Mark(), in: ctx, plate: 1024, ink: ink)
    writePNG(ctx, to: url)
}

/// Menu bar template image: the same mark on an 18 pt grid, black on transparent.
func renderMenuBar(scale: Int, to url: URL) {
    let pt: CGFloat = 18
    let px = Int(pt) * scale
    let ctx = makeContext(px)
    ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    var m = Mark()
    m.circleCenter = CGPoint(x: 9, y: 9.5)
    m.circleRadius = 7.8
    m.unitsLeft = 9 - 1.9
    m.unitsHeight = 15.6
    m.gap = 1.0
    m.cornerRadius = 0.9
    m.lightRadius = 0.75
    drawMark(m, in: ctx, plate: pt, ink: CGColor(gray: 0, alpha: 1))
    writePNG(ctx, to: url)
}

let fm = FileManager.default
try? fm.createDirectory(at: menuBarDir, withIntermediateDirectories: true)

for (size, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    renderAppIcon(px: size * scale, to: appIconDir.appendingPathComponent("icon_\(size)x\(size)@\(scale)x.png"))
}
renderMenuBar(scale: 1, to: menuBarDir.appendingPathComponent("menubar.png"))
renderMenuBar(scale: 2, to: menuBarDir.appendingPathComponent("menubar@2x.png"))
