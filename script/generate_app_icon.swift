#!/usr/bin/env swift

import AppKit
import CoreGraphics
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
let design = root.appendingPathComponent("Design", isDirectory: true)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let sourceIcon = design.appendingPathComponent("AppIconSource.png")
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

func loadSourceImage() throws -> CGImage {
    guard let image = NSImage(contentsOf: sourceIcon) else {
        throw NSError(
            domain: "CTTPulseIcon",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing source icon: \(sourceIcon.path)"]
        )
    }

    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw NSError(
            domain: "CTTPulseIcon",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Could not read source icon as a CGImage."]
        )
    }

    let side = min(cgImage.width, cgImage.height)
    let crop = CGRect(
        x: (cgImage.width - side) / 2,
        y: (cgImage.height - side) / 2,
        width: side,
        height: side
    )

    guard let cropped = cgImage.cropping(to: crop) else {
        throw NSError(
            domain: "CTTPulseIcon",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Could not crop source icon to a square."]
        )
    }

    return cropped
}

func resizedPNG(from source: CGImage, pixels: Int) throws -> Data {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
        throw NSError(
            domain: "CTTPulseIcon",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Could not create sRGB color space."]
        )
    }

    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(
            domain: "CTTPulseIcon",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "Could not create \(pixels)x\(pixels) icon context."]
        )
    }

    context.interpolationQuality = .high
    context.draw(source, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))

    guard let output = context.makeImage() else {
        throw NSError(
            domain: "CTTPulseIcon",
            code: 6,
            userInfo: [NSLocalizedDescriptionKey: "Could not render \(pixels)x\(pixels) icon."]
        )
    }

    let bitmap = NSBitmapImageRep(cgImage: output)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(
            domain: "CTTPulseIcon",
            code: 7,
            userInfo: [NSLocalizedDescriptionKey: "Could not encode \(pixels)x\(pixels) icon as PNG."]
        )
    }

    return data
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
                "green": "0.560",
                "blue": "0.690",
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

let source = try loadSourceImage()

for slot in slots {
    let pngData = try resizedPNG(from: source, pixels: slot.pixels)
    try pngData.write(to: appIconSet.appendingPathComponent(slot.filename))
    try pngData.write(to: icnsIconSet.appendingPathComponent(slot.filename))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", icnsIconSet.path, "-o", icnsFile.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    throw NSError(
        domain: "CTTPulseIcon",
        code: Int(process.terminationStatus),
        userInfo: [NSLocalizedDescriptionKey: "iconutil failed."]
    )
}

print("Generated \(appIconSet.path)")
print("Generated \(icnsFile.path)")
