import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate-icon.swift <iconset-directory>\n", stderr)
    exit(EXIT_FAILURE)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(
    at: output,
    withIntermediateDirectories: true
)

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, pixels) in variants {
    let size = NSSize(width: pixels, height: pixels)
    let image = NSImage(size: size)
    image.lockFocus()

    let rect = NSRect(origin: .zero, size: size)

    // Background: rounded rectangle
    let margin = CGFloat(pixels) * 0.08
    let bgRect = NSRect(
        x: margin,
        y: margin,
        width: CGFloat(pixels) - margin * 2,
        height: CGFloat(pixels) - margin * 2
    )
    let bgPath = NSBezierPath(
        roundedRect: bgRect,
        xRadius: CGFloat(pixels) * 0.20,
        yRadius: CGFloat(pixels) * 0.20
    )
    NSColor(calibratedRed: 0.09, green: 0.38, blue: 0.80, alpha: 1).setFill()
    bgPath.fill()

    // SF Symbol: waveform.path.ecg
    let symbolSize = CGFloat(pixels) * 0.50
    let symbolRect = NSRect(
        x: (CGFloat(pixels) - symbolSize) / 2,
        y: (CGFloat(pixels) - symbolSize) / 2,
        width: symbolSize,
        height: symbolSize
    )
    if let symbol = NSImage(
        systemSymbolName: "waveform.path.ecg",
        accessibilityDescription: nil
    ) {
        let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .semibold)
            .applying(.init(paletteColors: [.white]))
        if let configured = symbol.withSymbolConfiguration(config) {
            configured.draw(in: symbolRect)
        }
    }

    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fputs("failed to render \(name)\n", stderr)
        exit(EXIT_FAILURE)
    }
    try png.write(to: output.appendingPathComponent(name), options: .atomic)
}
