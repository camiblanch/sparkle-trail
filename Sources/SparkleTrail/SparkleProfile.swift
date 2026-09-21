import Foundation

/// Every setting that shapes how the trail looks.
///
/// Pause state, the Reduce Motion preference and the login item stay out. Those
/// are app preferences rather than part of a look, so applying a profile while
/// the trail is paused leaves it paused.
///
/// The property names match the `UserDefaults` keys, which is what lets
/// `factoryDefaults` fall out of `factory` instead of repeating every value.
struct SparkleProfile: Codable, Equatable {
    var paletteID: String
    var customHexes: [String]
    var shapeID: String
    var density: Double
    var maxSparkles: Double
    var minSize: Double
    var maxSize: Double
    var lifetime: Double
    var gravity: Double
    var drift: Double
    var lift: Double
    var spin: Double
    var opacity: Double
    var glow: Bool
    var clickBurst: Bool
    var burstCount: Double

    static let factory = SparkleProfile(
        paletteID: "soft-blush",
        customHexes: ["#f48498", "#acd8aa", "#ffffff"],
        shapeID: SparkleShape.star.rawValue,
        density: 0.7,
        maxSparkles: 500,
        minSize: 8,
        maxSize: 20,
        lifetime: 900,
        gravity: 200,
        drift: 30,
        lift: 40,
        spin: 350,
        opacity: 1,
        glow: true,
        clickBurst: true,
        burstCount: 18)

    /// The same values shaped for `UserDefaults`, keyed by property name.
    var registrationDictionary: [String: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return object
    }

}

// In an extension so the memberwise initialiser survives.
extension SparkleProfile {
    /// Reads one key per property, the layout the app has always stored, so an
    /// existing installation keeps its settings. Anything missing or unreadable
    /// falls back to the factory value for that key.
    init(from defaults: UserDefaults) {
        var raw = SparkleProfile.factory.registrationDictionary
        for key in raw.keys {
            if let stored = defaults.object(forKey: key) { raw[key] = stored }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: raw),
              let decoded = try? JSONDecoder().decode(SparkleProfile.self, from: data)
        else {
            self = .factory
            return
        }
        self = decoded
    }

    func write(to defaults: UserDefaults) {
        for (key, value) in registrationDictionary { defaults.set(value, forKey: key) }
    }
}

/// A profile the user named and kept.
struct NamedProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var profile: SparkleProfile

    init(id: UUID = UUID(), name: String, profile: SparkleProfile) {
        self.id = id
        self.name = name
        self.profile = profile
    }
}

/// The on-disk shape of an exported profile. `app` and `version` are there so a
/// file from a later release can be refused with a clear message rather than
/// decoded into nonsense.
struct ExportedProfile: Codable {
    static let currentApp = "sparkle-trail"
    static let currentVersion = 1

    var app: String
    var version: Int
    var name: String
    var profile: SparkleProfile

    init(name: String, profile: SparkleProfile) {
        self.app = Self.currentApp
        self.version = Self.currentVersion
        self.name = name
        self.profile = profile
    }
}
