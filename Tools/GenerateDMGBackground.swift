#!/usr/bin/swift

import AppKit
import Foundation

let canvasSize = NSSize(width: 720, height: 460)

guard CommandLine.arguments.count == 2 else {
    fputs("usage: GenerateDMGBackground.swift <output.png>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasSize.width),
    pixelsHigh: Int(canvasSize.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("failed to allocate the DMG background canvas\n", stderr)
    exit(1)
}

bitmap.size = canvasSize
guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("failed to create the DMG background context\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext

NSColor(calibratedRed: 0.976, green: 0.973, blue: 0.992, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()

// Subtle sticky-note shapes tie the installer back to the Deskbit icon.
let mintShape = NSBezierPath()
mintShape.move(to: NSPoint(x: 0, y: 0))
mintShape.line(to: NSPoint(x: 250, y: 0))
mintShape.line(to: NSPoint(x: 0, y: 116))
mintShape.close()
NSColor(calibratedRed: 0.76, green: 0.94, blue: 0.87, alpha: 0.72).setFill()
mintShape.fill()

let yellowShape = NSBezierPath()
yellowShape.move(to: NSPoint(x: 0, y: 0))
yellowShape.line(to: NSPoint(x: 145, y: 0))
yellowShape.line(to: NSPoint(x: 0, y: 68))
yellowShape.close()
NSColor(calibratedRed: 1.0, green: 0.88, blue: 0.40, alpha: 0.55).setFill()
yellowShape.fill()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 26, weight: .semibold),
    .foregroundColor: NSColor(calibratedWhite: 0.15, alpha: 1),
    .paragraphStyle: paragraph,
]

let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 15, weight: .regular),
    .foregroundColor: NSColor(calibratedWhite: 0.38, alpha: 1),
    .paragraphStyle: paragraph,
]

("Drag Deskbit to Applications" as NSString).draw(
    in: NSRect(x: 60, y: 380, width: 600, height: 36),
    withAttributes: titleAttributes
)
("Drag the app onto the folder to install" as NSString).draw(
    in: NSRect(x: 60, y: 352, width: 600, height: 24),
    withAttributes: subtitleAttributes
)

let arrowColor = NSColor(calibratedRed: 0.42, green: 0.35, blue: 0.86, alpha: 0.92)
arrowColor.setStroke()

for offset in [0.0, 31.0, 62.0] {
    let chevron = NSBezierPath()
    chevron.lineWidth = 8
    chevron.lineCapStyle = .round
    chevron.lineJoinStyle = .round
    chevron.move(to: NSPoint(x: 311 + offset, y: 209))
    chevron.line(to: NSPoint(x: 329 + offset, y: 228))
    chevron.line(to: NSPoint(x: 311 + offset, y: 247))
    chevron.stroke()
}

graphicsContext.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("failed to render the DMG background\n", stderr)
    exit(1)
}

do {
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try pngData.write(to: outputURL, options: .atomic)
} catch {
    fputs("failed to write DMG background: \(error)\n", stderr)
    exit(1)
}
