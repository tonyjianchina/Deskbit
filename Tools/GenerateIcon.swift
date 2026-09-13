import AppKit

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else { exit(1) }

context.setShadow(offset: CGSize(width: 0, height: -18), blur: 38, color: NSColor.black.withAlphaComponent(0.22).cgColor)
let tile = NSBezierPath(roundedRect: NSRect(x: 92, y: 92, width: 840, height: 840), xRadius: 190, yRadius: 190)
let gradient = NSGradient(colors: [
    NSColor(red: 0.12, green: 0.15, blue: 0.17, alpha: 1),
    NSColor(red: 0.20, green: 0.24, blue: 0.25, alpha: 1)
])!
gradient.draw(in: tile, angle: -65)
context.setShadow(offset: .zero, blur: 0, color: nil)

let notes: [(NSRect, NSColor, CGFloat)] = [
    (NSRect(x: 220, y: 468, width: 390, height: 310), NSColor(red: 1.00, green: 0.89, blue: 0.43, alpha: 1), -8),
    (NSRect(x: 414, y: 260, width: 390, height: 310), NSColor(red: 0.68, green: 0.90, blue: 0.80, alpha: 1), 7)
]

for (rect, color, angle) in notes {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: rect.midX, yBy: rect.midY)
    transform.rotate(byDegrees: angle)
    transform.translateX(by: -rect.midX, yBy: -rect.midY)
    transform.concat()

    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: NSColor.black.withAlphaComponent(0.24).cgColor)
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: 34, yRadius: 34).fill()
    context.setShadow(offset: .zero, blur: 0, color: nil)

    NSColor.black.withAlphaComponent(0.13).setFill()
    NSBezierPath(rect: NSRect(x: rect.minX, y: rect.maxY - 72, width: rect.width, height: 2)).fill()
    for row in 0..<3 {
        for column in 0..<2 {
            NSBezierPath(ovalIn: NSRect(x: rect.minX + 30 + CGFloat(column * 13), y: rect.maxY - 43 - CGFloat(row * 13), width: 6, height: 6)).fill()
        }
    }
    NSGraphicsContext.restoreGraphicsState()
}

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let data = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: outputURL)
