import AppKit
import Combine

/// The named profiles the user has kept, persisted as JSON in `UserDefaults`.
///
/// Profiles are snapshots, not documents. Applying one copies its values into
/// the live settings and nothing stays linked afterwards, so editing a setting
/// never quietly rewrites a saved profile.
@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    @Published private(set) var profiles: [NamedProfile] = []

    private let store: UserDefaults
    private let key = "profiles"

    init(store: UserDefaults = .standard) {
        self.store = store
        guard let data = store.data(forKey: key),
              let decoded = try? JSONDecoder().decode([NamedProfile].self, from: data)
        else { return }
        profiles = decoded
    }

    // MARK: - Managing the list

    @discardableResult
    func save(name: String, profile: SparkleProfile) -> NamedProfile {
        let saved = NamedProfile(name: uniqueName(from: name), profile: profile)
        profiles.append(saved)
        persist()
        return saved
    }

    func update(_ id: UUID, to profile: SparkleProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].profile = profile
        persist()
    }

    func rename(_ id: UUID, to name: String) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != profiles[index].name else { return }
        profiles[index].name = uniqueName(from: trimmed, ignoring: id)
        persist()
    }

    func delete(_ id: UUID) {
        profiles.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        store.set(data, forKey: key)
    }

    /// Keeps names distinct so two entries in the menu never read the same.
    private func uniqueName(from name: String, ignoring id: UUID? = nil) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Untitled" : trimmed
        let taken = Set(profiles.filter { $0.id != id }.map(\.name))
        guard taken.contains(base) else { return base }

        var suffix = 2
        while taken.contains("\(base) \(suffix)") { suffix += 1 }
        return "\(base) \(suffix)"
    }

    // MARK: - Sharing

    enum ImportError: LocalizedError {
        case unreadable
        case notAProfile
        case tooNew(Int)

        var errorDescription: String? {
            switch self {
            case .unreadable:
                return "That file is not a Sparkle Trail profile."
            case .notAProfile:
                return "That file holds something other than a Sparkle Trail profile."
            case .tooNew(let version):
                return "That profile was saved by a newer version of Sparkle Trail (format \(version))."
            }
        }
    }

    /// Writes the profile to the Downloads folder and selects it in the Finder,
    /// so the file never lands somewhere the user has to go hunting for.
    @discardableResult
    func export(name: String, profile: SparkleProfile, to directory: URL? = nil) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(ExportedProfile(name: name, profile: profile))

        let url = try Self.destinationURL(for: name, in: directory ?? Self.downloads())
        try data.write(to: url)
        if directory == nil { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        return url
    }

    @discardableResult
    func importProfile(from url: URL) throws -> NamedProfile {
        guard let data = try? Data(contentsOf: url) else { throw ImportError.unreadable }
        guard let decoded = try? JSONDecoder().decode(ExportedProfile.self, from: data),
              decoded.app == ExportedProfile.currentApp
        else { throw ImportError.notAProfile }
        guard decoded.version <= ExportedProfile.currentVersion else {
            throw ImportError.tooNew(decoded.version)
        }
        return save(name: decoded.name, profile: decoded.profile)
    }

    private static func downloads() throws -> URL {
        try FileManager.default.url(
            for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }

    /// Strips anything that would make an awkward filename, then counts up
    /// rather than overwriting a file already sitting there.
    static func destinationURL(for name: String, in directory: URL) -> URL {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let cleaned = name.unicodeScalars.filter(allowed.contains).map(Character.init)
        let stem = String(cleaned).trimmingCharacters(in: .whitespaces)
        let base = stem.isEmpty ? "Sparkle Trail profile" : stem

        var candidate = directory.appendingPathComponent("\(base).sparkletrail.json")
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base) \(suffix).sparkletrail.json")
            suffix += 1
        }
        return candidate
    }
}
