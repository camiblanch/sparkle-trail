import AppKit
import Combine

@MainActor
final class SparkleSettings: ObservableObject {
    static let shared = SparkleSettings()

    private let store: UserDefaults

    /// The whole look, in one value. Views bind straight through it, as in
    /// `$settings.profile.density`, so adding a setting means adding it to
    /// `SparkleProfile` and nowhere else.
    @Published var profile: SparkleProfile {
        didSet { profile.write(to: store) }
    }

    // Kept out of the profile: these are app preferences, not part of a look.
    @Published var isActive: Bool { didSet { store.set(isActive, forKey: "isActive") } }
    @Published var respectReduceMotion: Bool { didSet { store.set(respectReduceMotion, forKey: "respectReduceMotion") } }

    /// Mirrors the system Reduce Motion setting. Published so the menu bar icon
    /// and the panel change the moment it is switched in System Settings.
    @Published private(set) var systemReducesMotion: Bool

    /// Whole-look replacements, newest last, so applying a profile over settings
    /// you never saved is recoverable.
    @Published private(set) var undoStack: [SparkleProfile] = []

    private static let undoDepth = 10

    init(store: UserDefaults = .standard) {
        self.store = store
        store.register(defaults: Self.factoryDefaults)
        profile = SparkleProfile(from: store).clampingCustomColorCount()
        isActive = store.bool(forKey: "isActive")
        respectReduceMotion = store.bool(forKey: "respectReduceMotion")
        systemReducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.systemReducesMotion =
                        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                }
            }
    }

    /// True when Reduce Motion is holding the trail back even though it is on.
    var motionSuppressed: Bool { respectReduceMotion && systemReducesMotion }

    /// What the menu bar icon and the panel header should report.
    var isDrawing: Bool { isActive && !motionSuppressed }

    // MARK: - Whole-look changes

    /// Replaces the look, keeping the old one for `undoLastChange()`.
    func replaceProfile(with new: SparkleProfile) {
        let clamped = new.clampingCustomColorCount()
        guard clamped != profile else { return }
        undoStack.append(profile)
        if undoStack.count > Self.undoDepth { undoStack.removeFirst() }
        profile = clamped
    }

    func undoLastChange() {
        guard let previous = undoStack.popLast() else { return }
        profile = previous
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
        replaceProfile(with: .factory)
        respectReduceMotion = true
    }

    // MARK: - Derived values the renderer asks for

    /// 0 = a sparkle every 48pt of travel, 1 = one every 3pt.
    var spawnDistance: CGFloat { CGFloat(3 + (1 - min(max(profile.density, 0), 1)) * 45) }

    var shape: SparkleShape { SparkleShape(rawValue: profile.shapeID) ?? .star }

    var palette: SparklePalette { Palettes.palette(id: profile.paletteID) }

    var paletteColors: PaletteColors { Palettes.colors(for: profile) }

    var sparkleLimit: Int { max(1, Int(profile.maxSparkles)) }

    var sizeRange: ClosedRange<CGFloat> {
        let low = CGFloat(min(profile.minSize, profile.maxSize))
        let high = CGFloat(max(profile.minSize, profile.maxSize))
        return low...max(high, low + 0.5)
    }
}
