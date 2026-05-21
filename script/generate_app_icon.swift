#!/usr/bin/env swift

import AppKit
import Foundation

struct IconSlot {
    let points: Int
    let scale: Int

    var pixels: Int { points * scale }
    var filename: String {
        scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@\(scale)x.png"
    }
}

let slots = [
    IconSlot(points: 16, scale: 1),
    IconSlot(points: 16, scale: 2),
    IconSlot(points: 32, scale: 1),
    IconSlot(points: 32, scale: 2),
    IconSlot(points: 128, scale: 1),
    IconSlot(points: 128, scale: 2),
    IconSlot(points: 256, scale: 1),
    IconSlot(points: 256, scale: 2),
    IconSlot(points: 512, scale: 1),
    IconSlot(points: 512, scale: 2)
]

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let assets = resources.appendingPathComponent("Assets.xcassets", isDirectory: true)
let appIconSet = assets.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
let accentColorSet = assets.appendingPathComponent("AccentColor.colorset", isDirectory: true)
let generated = root.appendingPathComponent(".build/generated-icons", isDirectory: true)
let icnsIconSet = generated.appendingPathComponent("CTTPulse.iconset", isDirectory: true)
let icnsFile = resources.appendingPathComponent("CTTPulse.icns")

func writeJSON(_ object: Any, to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url)
}

func c(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

func drawArc(in context: CGContext, center: CGPoint, radius: CGFloat, start: CGFloat, end: CGFloat, width: CGFloat, color: NSColor) {
    context.saveGState()
    context.setLineCap(.round)
    context.setLineWidth(width)
    context.setStrokeColor(color.cgColor)
    context.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
    context.strokePath()
    context.restoreGState()
}

func drawIcon(pixels: Int) throws -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "CTTPulseIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create bitmap rep."])
    }

    rep.size = NSSize(width: pixels, height: pixels)

    guard let graphics = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(domain: "CTTPulseIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create graphics context."])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics

    let context = graphics.cgContext
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))

    let s = CGFloat(pixels) / 1024.0
    func v(_ value: CGFloat) -> CGFloat { value * s }

    let baseRect = NSRect(x: v(72), y: v(70), width: v(880), height: v(884))
    let baseRadius = v(218)
    let basePath = NSBezierPath(roundedRect: baseRect, xRadius: baseRadius, yRadius: baseRadius)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.48)
    shadow.shadowOffset = NSSize(width: 0, height: -v(22))
    shadow.shadowBlurRadius = v(56)
    shadow.set()
    c(0.01, 0.015, 0.018, 0.88).setFill()
    basePath.fill()

    context.setShadow(offset: .zero, blur: 0)
    context.saveGState()
    basePath.addClip()

    let baseGradient = NSGradient(colorsAndLocations:
        (c(0.012, 0.028, 0.035), 0.0),
        (c(0.026, 0.105, 0.105), 0.48),
        (c(0.005, 0.018, 0.026), 1.0)
    )
    baseGradient?.draw(in: basePath, angle: -36)

    let upperGlow = NSBezierPath(ovalIn: NSRect(x: v(-80), y: v(612), width: v(1184), height: v(520)))
    NSGradient(colorsAndLocations:
        (c(1.0, 1.0, 0.82, 0.34), 0.0),
        (c(0.65, 1.0, 0.95, 0.14), 0.46),
        (c(1.0, 1.0, 1.0, 0.0), 1.0)
    )?.draw(in: upperGlow, angle: -88)

    let lowerCoolGlow = NSBezierPath(ovalIn: NSRect(x: v(90), y: v(72), width: v(840), height: v(460)))
    NSGradient(colorsAndLocations:
        (c(0.0, 0.78, 0.88, 0.21), 0.0),
        (c(0.0, 0.22, 0.28, 0.03), 1.0)
    )?.draw(in: lowerCoolGlow, angle: 90)

    let notchRect = NSRect(x: v(300), y: v(792), width: v(424), height: v(104))
    let notchPath = NSBezierPath(roundedRect: notchRect, xRadius: v(52), yRadius: v(52))
    NSGradient(colorsAndLocations:
        (c(0.0, 0.0, 0.0, 0.98), 0.0),
        (c(0.035, 0.045, 0.05, 0.95), 0.58),
        (c(0.0, 0.0, 0.0, 0.99), 1.0)
    )?.draw(in: notchPath, angle: -90)
    notchPath.lineWidth = v(3)
    c(0.78, 1.0, 0.96, 0.2).setStroke()
    notchPath.stroke()

    let pulse = NSBezierPath()
    pulse.move(to: NSPoint(x: v(236), y: v(426)))
    pulse.curve(
        to: NSPoint(x: v(366), y: v(426)),
        controlPoint1: NSPoint(x: v(284), y: v(492)),
        controlPoint2: NSPoint(x: v(312), y: v(362))
    )
    pulse.curve(
        to: NSPoint(x: v(474), y: v(426)),
        controlPoint1: NSPoint(x: v(408), y: v(476)),
        controlPoint2: NSPoint(x: v(426), y: v(386))
    )
    pulse.curve(
        to: NSPoint(x: v(656), y: v(426)),
        controlPoint1: NSPoint(x: v(532), y: v(492)),
        controlPoint2: NSPoint(x: v(586), y: v(362))
    )
    pulse.curve(
        to: NSPoint(x: v(788), y: v(426)),
        controlPoint1: NSPoint(x: v(708), y: v(480)),
        controlPoint2: NSPoint(x: v(740), y: v(380))
    )
    pulse.lineWidth = v(17)
    c(0.15, 0.92, 0.84, 0.33).setStroke()
    pulse.stroke()

    let center = CGPoint(x: v(512), y: v(518))
    for index in 0..<3 {
        let radius = v(CGFloat(120 + index * 86))
        let width = v(CGFloat(28 - index * 4))
        let alpha = CGFloat(0.74 - Double(index) * 0.16)
        drawArc(in: context, center: center, radius: radius, start: -0.62, end: 0.62, width: width, color: c(0.78, 1.0, 0.96, alpha))
        drawArc(in: context, center: center, radius: radius, start: .pi - 0.62, end: .pi + 0.62, width: width, color: c(0.78, 1.0, 0.96, alpha))
    }

    let dotShadow = NSShadow()
    dotShadow.shadowColor = c(0.0, 0.88, 0.76, 0.65)
    dotShadow.shadowBlurRadius = v(38)
    dotShadow.shadowOffset = .zero
    dotShadow.set()

    let outerDot = NSBezierPath(ovalIn: NSRect(x: v(425), y: v(431), width: v(174), height: v(174)))
    c(0.68, 1.0, 0.9, 0.88).setFill()
    outerDot.fill()

    context.setShadow(offset: .zero, blur: 0)
    let dot = NSBezierPath(ovalIn: NSRect(x: v(452), y: v(458), width: v(120), height: v(120)))
    NSGradient(colorsAndLocations:
        (c(0.0, 0.92, 0.62), 0.0),
        (c(0.0, 0.58, 0.77), 1.0)
    )?.draw(in: dot, angle: -35)

    let dotHighlight = NSBezierPath(ovalIn: NSRect(x: v(474), y: v(524), width: v(46), height: v(32)))
    c(1.0, 1.0, 1.0, 0.42).setFill()
    dotHighlight.fill()

    let smallFix = NSBezierPath(ovalIn: NSRect(x: v(658), y: v(270), width: v(42), height: v(42)))
    c(0.86, 1.0, 0.42, 0.78).setFill()
    smallFix.fill()
    let route = NSBezierPath()
    route.move(to: NSPoint(x: v(512), y: v(458)))
    route.curve(
        to: NSPoint(x: v(679), y: v(292)),
        controlPoint1: NSPoint(x: v(560), y: v(392)),
        controlPoint2: NSPoint(x: v(610), y: v(312))
    )
    route.lineWidth = v(10)
    c(0.88, 1.0, 0.96, 0.46).setStroke()
    route.stroke()

    context.restoreGState()

    let innerStroke = NSBezierPath(roundedRect: baseRect.insetBy(dx: v(18), dy: v(18)), xRadius: v(200), yRadius: v(200))
    innerStroke.lineWidth = v(3)
    c(1.0, 1.0, 1.0, 0.22).setStroke()
    innerStroke.stroke()

    basePath.lineWidth = v(6)
    c(0.72, 1.0, 0.94, 0.26).setStroke()
    basePath.stroke()

    graphics.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

try fileManager.createDirectory(at: resources, withIntermediateDirectories: true)
try? fileManager.removeItem(at: appIconSet)
try? fileManager.removeItem(at: accentColorSet)
try? fileManager.removeItem(at: icnsIconSet)
try? fileManager.removeItem(at: icnsFile)
try fileManager.createDirectory(at: assets, withIntermediateDirectories: true)
try fileManager.createDirectory(at: generated, withIntermediateDirectories: true)
try fileManager.createDirectory(at: appIconSet, withIntermediateDirectories: true)
try fileManager.createDirectory(at: accentColorSet, withIntermediateDirectories: true)
try fileManager.createDirectory(at: icnsIconSet, withIntermediateDirectories: true)

try writeJSON([
    "info": [
        "author": "xcode",
        "version": 1
    ]
], to: assets.appendingPathComponent("Contents.json"))

try writeJSON([
    "colors": [[
        "idiom": "universal",
        "color": [
            "color-space": "srgb",
            "components": [
                "red": "0.000",
                "green": "0.720",
                "blue": "0.680",
                "alpha": "1.000"
            ]
        ]
    ]],
    "info": [
        "author": "xcode",
        "version": 1
    ]
], to: accentColorSet.appendingPathComponent("Contents.json"))

let appIconImages = slots.map { slot in
    [
        "filename": slot.filename,
        "idiom": "mac",
        "scale": "\(slot.scale)x",
        "size": "\(slot.points)x\(slot.points)"
    ]
}

try writeJSON([
    "images": appIconImages,
    "info": [
        "author": "xcode",
        "version": 1
    ]
], to: appIconSet.appendingPathComponent("Contents.json"))

for slot in slots {
    let rep = try drawIcon(pixels: slot.pixels)
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "CTTPulseIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not encode \(slot.filename)."])
    }

    let appIconURL = appIconSet.appendingPathComponent(slot.filename)
    let icnsURL = icnsIconSet.appendingPathComponent(slot.filename)
    try pngData.write(to: appIconURL)
    try pngData.write(to: icnsURL)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", icnsIconSet.path, "-o", icnsFile.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    throw NSError(domain: "CTTPulseIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed."])
}

print("Generated \(appIconSet.path)")
print("Generated \(icnsFile.path)")
