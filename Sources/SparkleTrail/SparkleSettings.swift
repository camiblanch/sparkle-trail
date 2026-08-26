import AppKit
import Combine

@MainActor
final class SparkleSettings: ObservableObject {
    static let shared = SparkleSettings()

    private let store = UserDefaults.standard

    @Published var isActive: Bool { didSet { store.set(isActive, forKey: "isActive") } }
    @Published var paletteID: String { didSet { store.set(paletteID, forKey: "paletteID") } }
    @Published var customHexes: [String] {
        didSet {
            if customHexes.count > Palettes.maxCustomColors {
                customHexes = Array(customHexes.prefix(Palettes.maxCustomColors))
                return
            }
            store.set(customHexes, forKey: "customHexes")
        }
    }
    @Published var shapeID: String { didSet { store.set(shapeID, forKey: "shapeID") } }

    /// 0 = a sparkle every 48pt of travel, 1 = one every 3pt.
    @Published var density: Double { didSet { store.set(density, forKey: "density") } }
    @Published var maxSparkles: Double { didSet { store.set(maxSparkles, forKey: "maxSparkles") } }
    @Published var minSize: Double { didSet { store.set(minSize, forKey: "minSize") } }
    @Published var maxSize: Double { didSet { store.set(maxSize, forKey: "maxSize") } }
    @Published var lifetime: Double { didSet { store.set(lifetime, forKey: "lifetime") } }
    @Published var gravity: Double { didSet { store.set(gravity, forKey: "gravity") } }
    @Published var drift: Double { didSet { store.set(drift, forKey: "drift") } }
    @Published var lift: Double { didSet { store.set(lift, forKey: "lift") } }
    @Published var spin: Double { didSet { store.set(spin, forKey: "spin") } }
    @Published var opacity: Double { didSet { store.set(opacity, forKey: "opacity") } }
    @Published var glow: Bool { didSet { store.set(glow, forKey: "glow") } }
    @Published var clickBurst: Bool { didSet { store.set(clickBurst, forKey: "clickBurst") } }
    @Published var burstCount: Double { didSet { store.set(burstCount, forKey: "burstCount") } }
    @Published var respectReduceMotion: Bool { didSet { store.set(respectReduceMotion, forKey: "respectReduceMotion") } }

    private init() {
        store.register(defaults: Self.factoryDefaults)
        isActive = store.bool(forKey: "isActive")
        paletteID = store.string(forKey: "paletteID") ?? "soft-blush"
        customHexes = Array((store.stringArray(forKey: "customHexes") ?? Self.starterCustomHexes)
            .prefix(Palettes.maxCustomColors))
        shapeID = store.string(forKey: "shapeID") ?? SparkleShape.star.rawValue
        density = store.double(forKey: "density")
        maxSparkles = store.double(forKey: "maxSparkles")
        minSize = store.double(forKey: "minSize")
        maxSize = store.double(forKey: "maxSize")
        lifetime = store.double(forKey: "lifetime")
        gravity = store.double(forKey: "gravity")
        drift = store.double(forKey: "drift")
        lift = store.double(forKey: "lift")
        spin = store.double(forKey: "spin")
        opacity = store.double(forKey: "opacity")
        glow = store.bool(forKey: "glow")
        clickBurst = store.bool(forKey: "clickBurst")
        burstCount = store.double(forKey: "burstCount")
        respectReduceMotion = store.bool(forKey: "respectReduceMotion")
    }

    static let starterCustomHexes = ["#f48498", "#acd8aa", "#ffffff"]

    static let factoryDefaults: [String: Any] = [
        "isActive": true,
        "paletteID": "soft-blush",
        "shapeID": SparkleShape.star.rawValue,
        "density": 0.7,
        "maxSparkles": 500.0,
        "minSize": 8.0,
        "maxSize": 20.0,
        "lifetime": 900.0,
        "gravity": 200.0,
        "drift": 30.0,
        "lift": 40.0,
        "spin": 350.0,
        "opacity": 1.0,
        "glow": true,
        "clickBurst": true,
        "burstCount": 18.0,
        "respectReduceMotion": true,
    ]

    func restoreDefaults() {
        let wasActive = isActive
        for (key, _) in Self.factoryDefaults { store.removeObject(forKey: key) }
        store.removeObject(forKey: "customHexes")
        store.register(defaults: Self.factoryDefaults)
        paletteID = "soft-blush"
        customHexes = Self.starterCustomHexes
        shapeID = SparkleShape.star.rawValue
        density = 0.7
        maxSparkles = 500
        minSize = 8
        maxSize = 20
        lifetime = 900
        gravity = 200
        drift = 30
        lift = 40
        spin = 350
        opacity = 1
        glow = true
        clickBurst = true
        burstCount = 18
        respectReduceMotion = true
        isActive = wasActive
    }

    // MARK: - Derived values the renderer asks for

    var spawnDistance: CGFloat { CGFloat(3 + (1 - min(max(density, 0), 1)) * 45) }

    var shape: SparkleShape { SparkleShape(rawValue: shapeID) ?? .star }

    var palette: SparklePalette { Palettes.palette(id: paletteID) }

    var activeColors: [NSColor] {
        switch paletteID {
        case Palettes.customID:
            let colors = customHexes.compactMap(NSColor.init(hex:))
            return colors.isEmpty ? [.white] : colors
        case Palettes.rainbowID:
            return []
        default:
            let colors = palette.swatches
            return colors.isEmpty ? [.white] : colors
        }
    }

    var usesRainbow: Bool { paletteID == Palettes.rainbowID }

    var sizeRange: ClosedRange<CGFloat> {
        let low = CGFloat(min(minSize, maxSize))
        let high = CGFloat(max(minSize, maxSize))
        return low...max(high, low + 0.5)
    }
}
