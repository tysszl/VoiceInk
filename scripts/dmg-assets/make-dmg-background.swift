#!/usr/bin/env swift
import AppKit

// Renders the VoiceInk installer DMG background: a light gradient, a title,
// and an arrow pointing from the app icon toward the Applications folder.
// Icon positions are fixed in settings.py (icon_locations), so the arrow
// geometry here is hand-aligned to match.
//
// Usage: swift make-dmg-background.swift <output.png> <scale>
//   scale 1 -> 660x400 (dmg-background.png)
//   scale 2 -> 1320x800 ([email protected], used on Retina)

let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "dmg-background.png"
let scale = args.count > 2 ? CGFloat(Double(args[2]) ?? 1) : 1

// Window content size in points. Must match window_rect in settings.py.
let W: CGFloat = 660, H: CGFloat = 400
let pxW = Int(W * scale), pxH = Int(H * scale)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: pxW, pixelsHigh: pxH,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
), let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
    FileHandle.standardError.write(Data("Failed to create bitmap context\n".utf8))
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx
ctx.cgContext.scaleBy(x: scale, y: scale) // draw in logical points; output in pixels

// Background gradient (top lighter -> bottom slightly cooler/darker).
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.98, green: 0.985, blue: 0.99, alpha: 1),
    NSColor(calibratedRed: 0.90, green: 0.92, blue: 0.95, alpha: 1)
])!
gradient.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

// Title + subtitle, centered near the top (origin is bottom-left).
let center = NSMutableParagraphStyle(); center.alignment = .center
NSAttributedString(string: "Install VoiceInk", attributes: [
    .font: NSFont.systemFont(ofSize: 26, weight: .bold),
    .foregroundColor: NSColor(white: 0.13, alpha: 1),
    .paragraphStyle: center
]).draw(in: NSRect(x: 0, y: H - 80, width: W, height: 36))

NSAttributedString(string: "Drag the VoiceInk icon onto the Applications folder.", attributes: [
    .font: NSFont.systemFont(ofSize: 13, weight: .regular),
    .foregroundColor: NSColor(white: 0.40, alpha: 1),
    .paragraphStyle: center
]).draw(in: NSRect(x: 0, y: H - 106, width: W, height: 20))

// Arrow at the icons' vertical center (y = 200), spanning the gap between
// the app icon (center x = 165) and the Applications folder (center x = 495).
let y: CGFloat = 200, x1: CGFloat = 258, x2: CGFloat = 402
let arrowColor = NSColor(calibratedRed: 0.45, green: 0.50, blue: 0.58, alpha: 0.9)
arrowColor.setStroke(); arrowColor.setFill()

let shaft = NSBezierPath()
shaft.lineWidth = 4
shaft.lineCapStyle = .round
shaft.move(to: NSPoint(x: x1, y: y))
shaft.line(to: NSPoint(x: x2 - 8, y: y))
shaft.stroke()

let head = NSBezierPath()
head.move(to: NSPoint(x: x2 + 8, y: y))
head.line(to: NSPoint(x: x2 - 12, y: y + 12))
head.line(to: NSPoint(x: x2 - 12, y: y - 12))
head.close()
head.fill()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Failed to encode PNG\n".utf8))
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath) (\(pxW)x\(pxH))")
