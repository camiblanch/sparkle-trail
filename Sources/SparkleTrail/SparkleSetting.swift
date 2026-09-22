import Foundation

/// One numeric setting: where it lives on the profile, the range it may take,
/// and how its value reads.
///
/// The menu bar panel and the advanced window both show some of these. Holding
/// the range and the format here means the two cannot disagree about what the
/// same slider does.
struct SparkleSetting {
    let title: String
    let keyPath: WritableKeyPath<SparkleProfile, Double>
    let range: ClosedRange<Double>
    /// Only the settings whose effect is not obvious carry one. Captioning
    /// every slider would bury the few that need the explanation.
    let caption: String?
    let format: (Double) -> String

    init(title: String,
         keyPath: WritableKeyPath<SparkleProfile, Double>,
         range: ClosedRange<Double>,
         caption: String? = nil,
         format: @escaping (Double) -> String) {
        self.title = title
        self.keyPath = keyPath
        self.range = range
        self.caption = caption
        self.format = format
    }
}

extension SparkleSetting {
    private static func percent(_ value: Double) -> String { "\(Int(value * 100))%" }
    private static func whole(_ value: Double) -> String { "\(Int(value))" }
    private static func points(_ value: Double) -> String { "\(Int(value)) pt" }

    static let density = SparkleSetting(
        title: "Amount", keyPath: \.density, range: 0...1,
        caption: "How often a sparkle appears as the cursor moves.",
        format: percent)

    static let maxSparkles = SparkleSetting(
        title: "Maximum sparkles", keyPath: \.maxSparkles, range: 25...1500,
        caption: "The most that can be on screen at once. Raise it if fast movement looks thin.",
        format: whole)

    static let lifetime = SparkleSetting(
        title: "Lifetime", keyPath: \.lifetime, range: 250...3000,
        caption: "How long each sparkle lasts before it fades out.",
        format: { String(format: "%.2f s", $0 / 1000) })

    static let minSize = SparkleSetting(
        title: "Smallest", keyPath: \.minSize, range: 2...48,
        caption: "Each sparkle takes a random size between these two.",
        format: points)

    static let maxSize = SparkleSetting(
        title: "Largest", keyPath: \.maxSize, range: 2...48,
        format: points)

    static let opacity = SparkleSetting(
        title: "Opacity", keyPath: \.opacity, range: 0.1...1,
        format: percent)

    static let gravity = SparkleSetting(
        title: "Gravity", keyPath: \.gravity, range: -400...900,
        caption: "Below zero, sparkles rise instead of falling.",
        format: whole)

    static let drift = SparkleSetting(
        title: "Sideways drift", keyPath: \.drift, range: 0...240,
        caption: "Each sparkle gets a random sideways speed up to this.",
        format: whole)

    static let lift = SparkleSetting(
        title: "Upward kick", keyPath: \.lift, range: 0...240,
        caption: "Each sparkle gets a random upward speed up to this.",
        format: whole)

    static let spin = SparkleSetting(
        title: "Spin", keyPath: \.spin, range: 0...900,
        caption: "Each sparkle gets a random spin rate up to this, either direction.",
        format: { "\(Int($0))°/s" })

    static let burstCount = SparkleSetting(
        title: "Burst size", keyPath: \.burstCount, range: 4...60,
        format: whole)
}
