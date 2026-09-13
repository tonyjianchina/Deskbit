import AppKit
import Foundation

// 生成 Deskbit 应用图标：黄色便签 + 图钉 + 四条文字横线
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no context") }
ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

// 便签主体（圆角矩形，黄色）
let noteRect = CGRect(x: 150, y: 140, width: 724, height: 744)
let notePath = NSBezierPath(roundedRect: noteRect, xRadius: 90, yRadius: 90)
NSColor(calibratedRed: 1.00, green: 0.955, blue: 0.60, alpha: 1.0).setFill()
notePath.fill()

// 顶部折叠角（右上）
let foldPath = NSBezierPath()
let corner: CGFloat = 170
foldPath.move(to: NSPoint(x: noteRect.maxX - corner, y: noteRect.maxY))
foldPath.line(to: NSPoint(x: noteRect.maxX, y: noteRect.maxY - corner))
foldPath.line(to: NSPoint(x: noteRect.maxX, y: noteRect.maxY))
foldPath.close()
NSColor(calibratedRed: 0.98, green: 0.92, blue: 0.55, alpha: 1.0).setFill()
foldPath.fill()

// 折叠角阴影线
NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.10).setStroke()
let foldLine = NSBezierPath()
foldLine.lineWidth = 10
foldLine.move(to: NSPoint(x: noteRect.maxX - corner, y: noteRect.maxY))
foldLine.line(to: NSPoint(x: noteRect.maxX, y: noteRect.maxY - corner))
foldLine.stroke()

// 图钉（红色）
let pinCenter = NSPoint(x: noteRect.midX, y: noteRect.maxY - 46)
let pinCylinder = NSRect(x: pinCenter.x - 66, y: pinCenter.y - 40, width: 132, height: 80)
NSColor(calibratedRed: 0.92, green: 0.30, blue: 0.28, alpha: 1.0).setFill()
NSBezierPath(roundedRect: pinCylinder, xRadius: 40, yRadius: 40).fill()
// 针尖
let needle = NSBezierPath()
needle.move(to: NSPoint(x: pinCenter.x - 12, y: pinCenter.y + 42))
needle.line(to: NSPoint(x: pinCenter.x + 12, y: pinCenter.y + 42))
needle.line(to: NSPoint(x: pinCenter.x, y: pinCenter.y + 84))
needle.close()
NSColor(calibratedRed: 0.72, green: 0.22, blue: 0.20, alpha: 1.0).setFill()
needle.fill()

// 文字横线（深棕）
NSColor(calibratedRed: 0.45, green: 0.38, blue: 0.10, alpha: 1.0).setFill()
let lineX: CGFloat = noteRect.minX + 120
let lineMaxX: CGFloat = noteRect.maxX - 120
let lineW: CGFloat = lineMaxX - lineX
let lineH: CGFloat = 40
let lineSpacing: CGFloat = 132
var lineY = noteRect.maxY - 290
for i in 0..<4 {
    var w = lineW
    if i == 3 { w = lineW * 0.6 }
    NSRect(x: lineX, y: lineY - CGFloat(i) * lineSpacing, width: w, height: lineH).fill()
    _ = lineY
}

// 底部四种颜色的彩条（呼应四色主题）
let stripY: CGFloat = noteRect.minY + 78
let stripW: CGFloat = noteRect.width - 240
let stripX: CGFloat = noteRect.minX + 120
let segW = stripW / 4
let segH: CGFloat = 56
let colors: [NSColor] = [
    NSColor(calibratedRed: 0.76, green: 0.95, blue: 0.82, alpha: 1.0), // mint
    NSColor(calibratedRed: 0.78, green: 0.90, blue: 1.00, alpha: 1.0), // blue
    NSColor(calibratedRed: 1.00, green: 0.83, blue: 0.87, alpha: 1.0), // pink
    NSColor(calibratedRed: 0.45, green: 0.38, blue: 0.10, alpha: 1.0), // accent
]
for (i, c) in colors.enumerated() {
    c.setFill()
    NSRect(x: stripX + CGFloat(i) * segW, y: stripY, width: segW + 1, height: segH).fill()
}

img.unlockFocus()

// 导出 iconset
let iconsetDir = URL(fileURLWithPath: "/tmp/Deskbit.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconsetDir)
try! FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let targets: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for (name, px) in targets {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: px, height: px),
             from: NSRect(x: 0, y: 0, width: size, height: size),
             operation: .copy, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: iconsetDir.appendingPathComponent(name))
    print("wrote", name, px)
}
print("DONE")
