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

    let fullRect = NSRect(origin: .zero, size: size)

    // Rounded-rect clip for background
    let margin = CGFloat(pixels) * 0.06
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
    bgPath.addClip()

    // Background: vertical gradient #FFFFFF → #F6FAFF
    let bgGradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 1.00, green: 1.00, blue: 1.00, alpha: 1),
            NSColor(calibratedRed: 0.965, green: 0.980, blue: 1.00, alpha: 1)
        ],
        atLocations: [0.0, 1.0],
        colorSpace: .sRGB
    )
    bgGradient?.draw(in: bgRect, angle: -90)

    // Draw waveform symbol with shadow + gradient
    let symbolSize = CGFloat(pixels) * 0.72
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
        let config = NSImage.SymbolConfiguration(
            pointSize: symbolSize,
            weight: .semibold
        )
        guard let configured = symbol.withSymbolConfiguration(config) else { continue }

        // Render symbol into a mask image
        let maskImage = NSImage(size: size)
        maskImage.lockFocus()
        configured.draw(in: symbolRect)
        maskImage.unlockFocus()
        guard
            let maskTIFF = maskImage.tiffRepresentation,
            let maskRep = NSBitmapImageRep(data: maskTIFF),
            let maskCG = maskRep.cgImage
        else { continue }

        let ctx = NSGraphicsContext.current!.cgContext

        // Shadow pass: offset (2%, 2%) with shadow color
        let shadowDX = CGFloat(pixels) * 0.015
        let shadowDY = -CGFloat(pixels) * 0.015
        ctx.saveGState()
        let shadowRect = symbolRect.offsetBy(dx: shadowDX, dy: shadowDY)
        ctx.clip(to: shadowRect, mask: maskCG)
        NSColor(calibratedRed: 40/255, green: 80/255, blue: 140/255, alpha: 0.16).setFill()
        fullRect.fill()
        ctx.restoreGState()

        // Main gradient pass
        ctx.saveGState()
        ctx.clip(to: symbolRect, mask: maskCG)
        let mainGradient = NSGradient(
            colors: [
                NSColor(calibratedRed: 1.00, green: 0.435, blue: 0.718, alpha: 1),
                NSColor(calibratedRed: 0.31, green: 0.55, blue: 1.00, alpha: 1),
                NSColor(calibratedRed: 0.125, green: 0.84, blue: 0.78, alpha: 1)
            ],
            atLocations: [0.0, 1.0/3.0, 2.0/3.0],
            colorSpace: .sRGB
        )
        mainGradient?.draw(
            from: NSPoint(x: symbolRect.minX, y: symbolRect.maxY),
            to: NSPoint(x: symbolRect.maxX, y: symbolRect.minY),
            options: []
        )
        ctx.restoreGState()
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
