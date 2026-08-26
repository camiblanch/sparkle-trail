import AppKit

struct SparklePalette: Identifiable, Hashable {
    let id: String
    let name: String
    let hexes: [String]

    var swatches: [NSColor] { hexes.compactMap(NSColor.init(hex:)) }
}

enum Palettes {
    static let rainbowID = "rainbow"
    static let customID = "custom"
    static let maxCustomColors = 6

    // Soft Blush is the palette the original web trail shipped with. The page
    // background colour is deliberately absent from it; white is the twinkle.
    static let builtIn: [SparklePalette] = [
        SparklePalette(id: "soft-blush", name: "Soft Blush",
                       hexes: ["#f48498", "#e78f8e", "#f2ccc3", "#acd8aa", "#ffffff"]),
        SparklePalette(id: "aurora", name: "Aurora",
                       hexes: ["#7ef9d1", "#5ec8f8", "#8b7bf7", "#c084fc", "#ffffff"]),
        SparklePalette(id: "sunset", name: "Sunset",
                       hexes: ["#ff8a4c", "#ff5f6d", "#ffc371", "#ffd86f", "#fff2cc"]),
        SparklePalette(id: "neon", name: "Neon",
                       hexes: ["#ff2fd0", "#00f5d4", "#00bbf9", "#fee440", "#ffffff"]),
        SparklePalette(id: "gold", name: "Gold Dust",
                       hexes: ["#ffd700", "#ffb800", "#ffe9a8", "#fff6d5", "#ffffff"]),
        SparklePalette(id: "ice", name: "Ice",
                       hexes: ["#bfe9ff", "#8ecae6", "#dff6ff", "#a8dadc", "#ffffff"]),
        SparklePalette(id: "ember", name: "Ember",
                       hexes: ["#ff4d00", "#ff7b00", "#ffb703", "#ffe0b5", "#ffffff"]),
        SparklePalette(id: "mono", name: "Monochrome",
                       hexes: ["#ffffff", "#e6e6e6", "#bfbfbf", "#8c8c8c"]),
        SparklePalette(id: rainbowID, name: "Rainbow", hexes: []),
        SparklePalette(id: customID, name: "Custom", hexes: []),
    ]

    static func palette(id: String) -> SparklePalette {
        builtIn.first { $0.id == id } ?? builtIn[0]
    }
}

enum SparkleShape: String, CaseIterable, Identifiable {
    case star
    case fourPoint
    case diamond
    case circle
    case heart

    var id: String { rawValue }

    var label: String {
        switch self {
        case .star: return "Eight-point star"
        case .fourPoint: return "Sparkle"
        case .diamond: return "Diamond"
        case .circle: return "Dot"
        case .heart: return "Heart"
        }
    }

    /// Path drawn inside the unit square, y-up to match the non-flipped view the
    /// sparkles live in. Layers are sized in points and the path is baked in at
    /// that size, so only rotation and the grow/shrink scale ride on the
    /// transform and the geometry stays crisp.
    var unitPath: CGPath {
        let path = CGMutablePath()
        switch self {
        case .star:
            // The polygon() clip-path from the web version, point for point.
            let points: [(CGFloat, CGFloat)] = [
                (0.50, 0.00), (0.61, 0.39), (1.00, 0.50), (0.61, 0.61),
                (0.50, 1.00), (0.39, 0.61), (0.00, 0.50), (0.39, 0.39),
            ]
            path.addLines(between: points.map { CGPoint(x: $0.0, y: $0.1) })
        case .fourPoint:
            path.move(to: CGPoint(x: 0.5, y: 0))
            path.addCurve(to: CGPoint(x: 1, y: 0.5),
                          control1: CGPoint(x: 0.56, y: 0.32), control2: CGPoint(x: 0.68, y: 0.44))
            path.addCurve(to: CGPoint(x: 0.5, y: 1),
                          control1: CGPoint(x: 0.68, y: 0.56), control2: CGPoint(x: 0.56, y: 0.68))
            path.addCurve(to: CGPoint(x: 0, y: 0.5),
                          control1: CGPoint(x: 0.44, y: 0.68), control2: CGPoint(x: 0.32, y: 0.56))
            path.addCurve(to: CGPoint(x: 0.5, y: 0),
                          control1: CGPoint(x: 0.32, y: 0.44), control2: CGPoint(x: 0.44, y: 0.32))
        case .diamond:
            path.addLines(between: [
                CGPoint(x: 0.5, y: 0), CGPoint(x: 0.85, y: 0.5),
                CGPoint(x: 0.5, y: 1), CGPoint(x: 0.15, y: 0.5),
            ])
        case .circle:
            path.addEllipse(in: CGRect(x: 0, y: 0, width: 1, height: 1))
        case .heart:
            // Cusp at the bottom, two lobes at the top.
            path.move(to: CGPoint(x: 0.5, y: 0.78))
            path.addCurve(to: CGPoint(x: 0.03, y: 0.72),
                          control1: CGPoint(x: 0.42, y: 1.02), control2: CGPoint(x: 0.03, y: 1.00))
            path.addCurve(to: CGPoint(x: 0.5, y: 0.02),
                          control1: CGPoint(x: 0.03, y: 0.45), control2: CGPoint(x: 0.30, y: 0.26))
            path.addCurve(to: CGPoint(x: 0.97, y: 0.72),
                          control1: CGPoint(x: 0.70, y: 0.26), control2: CGPoint(x: 0.97, y: 0.45))
            path.addCurve(to: CGPoint(x: 0.5, y: 0.78),
                          control1: CGPoint(x: 0.97, y: 1.00), control2: CGPoint(x: 0.58, y: 1.02))
        }
        path.closeSubpath()
        return path
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        if text.count == 3 { text = text.map { "\($0)\($0)" }.joined() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((value >> 16) & 0xff) / 255,
                  green: CGFloat((value >> 8) & 0xff) / 255,
                  blue: CGFloat(value & 0xff) / 255,
                  alpha: 1)
    }

    var hexString: String {
        let rgb = usingColorSpace(.sRGB) ?? self
        let channel = { (value: CGFloat) in Int((max(0, min(1, value)) * 255).rounded()) }
        return String(format: "#%02x%02x%02x",
                      channel(rgb.redComponent), channel(rgb.greenComponent), channel(rgb.blueComponent))
    }
}
