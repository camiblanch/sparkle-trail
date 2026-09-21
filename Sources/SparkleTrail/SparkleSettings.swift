import AppKit
import Combine

@MainActor
final class SparkleSettings: ObservableObject {
    static let shared = SparkleSettings()

    private let store = UserDefaults.standard

    /// The whole look, in one value. Views bind straight through it, as in
    /// `$settings.profile.density`, so adding a setting means adding it to
    /// `SparkleProfile` and nowhere else.
    @Published var profile: SparkleProfile {
        didSet {
            if profile.customHexes.count > Palettes.maxCustomColors {
                profile.customHexes = Array(profile.customHexes.prefix(Palettes.maxCustomColors))
                return
            }
            profile.write(to: store)
        }
    }

    // Kept out of the profile: these are app preferences, not part of a look.
    @Published var isActive: Bool { didSet { store.set(isActive, forKey: "isActive") } }
    @Published var respectReduceMotion: Bool { didSet { store.set(respectReduceMotion, forKey: "respectReduceMotion") } }

    private init() {
        store.register(defaults: Self.factoryDefaults)
        profile = SparkleProfile(from: store)
        isActive = store.bool(forKey: "isActive")
        respectReduceMotion = store.bool(forKey: "respectReduceMotion")
    }

    /// Derived from `SparkleProfile.factory` so the look-affecting defaults are
    /// written down once. Only the settings a profile leaves out are added here.
    static var factoryDefaults: [String: Any] {
        var defaults = SparkleProfile.factory.registrationDictionary
        defaults["isActive"] = true
        defaults["respectReduceMotion"] = true
        return defaults
    }

    func restoreDefaults() {
        profile = .factory
        respectReduceMotion = true
    }

    // MARK: - Derived values the renderer asks for

    /// 0 = a sparkle every 48pt of travel, 1 = one every 3pt.
    var spawnDistance: CGFloat { CGFloat(3 + (1 - min(max(profile.density, 0), 1)) * 45) }

    var shape: SparkleShape { SparkleShape(rawValue: profile.shapeID) ?? .star }

    var palette: SparklePalette { Palettes.palette(id: profile.paletteID) }

    var activeColors: [NSColor] {
        switch profile.paletteID {
        case Palettes.customID:
            let colors = profile.customHexes.compactMap(NSColor.init(hex:))
            return colors.isEmpty ? [.white] : colors
        case Palettes.rainbowID:
            return []
        default:
            let colors = palette.swatches
            return colors.isEmpty ? [.white] : colors
        }
    }

    var usesRainbow: Bool { profile.paletteID == Palettes.rainbowID }

    var sizeRange: ClosedRange<CGFloat> {
        let low = CGFloat(min(profile.minSize, profile.maxSize))
        let high = CGFloat(max(profile.minSize, profile.maxSize))
        return low...max(high, low + 0.5)
    }
}
