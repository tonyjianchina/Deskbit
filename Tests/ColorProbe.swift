import AppKit

@main
struct ColorProbe {
    static func main() {
        let expected: [(NoteColor, String, [CGFloat], [CGFloat])] = [
            (.yellow, "黄色", [254 / 255, 244 / 255, 156 / 255], [253 / 255, 234 / 255, 61 / 255]),
            (.blue, "蓝色", [173 / 255, 244 / 255, 1], [137 / 255, 241 / 255, 1]),
            (.mint, "绿色", [178 / 255, 1, 161 / 255], [131 / 255, 254 / 255, 131 / 255]),
            (.pink, "粉色", [1, 199 / 255, 199 / 255], [1, 179 / 255, 178 / 255])
        ]

        guard NoteColor.allCases == expected.map(\.0) else { exit(1) }
        for (color, title, backgroundComponents, swatchComponents) in expected {
            guard color.title == title,
                  let background = color.background.usingColorSpace(.sRGB),
                  let swatch = color.swatch.usingColorSpace(.sRGB) else { exit(2) }
            let actualBackground = [background.redComponent, background.greenComponent, background.blueComponent]
            let actualSwatch = [swatch.redComponent, swatch.greenComponent, swatch.blueComponent]
            guard zip(actualBackground, backgroundComponents).allSatisfy({ abs($0 - $1) < 0.0001 }),
                  zip(actualSwatch, swatchComponents).allSatisfy({ abs($0 - $1) < 0.0001 }) else { exit(3) }
        }

        print("stickies background colors: pass")
    }
}
