import Foundation
import Testing

@testable import SparkleTrail

@MainActor
private func emptyStore(_ name: String = #function) -> ProfileStore {
    let suite = "sparkletrail.tests.\(name).\(UUID().uuidString)"
    UserDefaults.standard.removePersistentDomain(forName: suite)
    return ProfileStore(store: UserDefaults(suiteName: suite)!)
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("sparkletrail-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Suite("Profile names")
@MainActor
struct ProfileNameTests {
    @Test("A repeated name gets a counting suffix")
    func suffixesDuplicates() {
        let store = emptyStore()

        #expect(store.save(name: "Sparkly", profile: .factory).name == "Sparkly")
        #expect(store.save(name: "Sparkly", profile: .factory).name == "Sparkly 2")
        #expect(store.save(name: "Sparkly", profile: .factory).name == "Sparkly 3")
    }

    @Test("The suffix skips names already taken")
    func skipsTakenSuffixes() {
        let store = emptyStore()
        store.save(name: "Sparkly", profile: .factory)
        store.save(name: "Sparkly 2", profile: .factory)

        #expect(store.save(name: "Sparkly", profile: .factory).name == "Sparkly 3")
    }

    @Test("A blank name becomes Untitled")
    func blankNameFallsBack() {
        let store = emptyStore()

        #expect(store.save(name: "   ", profile: .factory).name == "Untitled")
    }

    @Test("Names are trimmed before they are compared")
    func namesAreTrimmed() {
        let store = emptyStore()
        store.save(name: "Sparkly", profile: .factory)

        #expect(store.save(name: "  Sparkly  ", profile: .factory).name == "Sparkly 2")
    }

    @Test("Renaming onto a taken name gets a suffix, and onto itself is a no-op")
    func renameKeepsNamesDistinct() {
        let store = emptyStore()
        let first = store.save(name: "One", profile: .factory)
        let second = store.save(name: "Two", profile: .factory)

        store.rename(second.id, to: "One")
        #expect(store.profiles.last?.name == "One 2")

        store.rename(first.id, to: "One")
        #expect(store.profiles.first?.name == "One")
    }

    @Test("An empty rename is ignored")
    func emptyRenameIgnored() {
        let store = emptyStore()
        let saved = store.save(name: "Keep me", profile: .factory)

        store.rename(saved.id, to: "  ")
        #expect(store.profiles.first?.name == "Keep me")
    }
}

@Suite("Profile sharing")
@MainActor
struct ProfileSharingTests {
    @Test("An exported profile imports back with its name and values")
    func exportImportRoundTrip() throws {
        let store = emptyStore()
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        var profile = SparkleProfile.factory
        profile.spin = 123
        let url = try store.export(name: "Round trip", profile: profile, to: directory)

        let imported = try store.importProfile(from: url)
        #expect(imported.name == "Round trip")
        #expect(imported.profile == profile)
    }

    @Test("Exporting the same name twice does not overwrite the first file")
    func exportAvoidsCollisions() throws {
        let store = emptyStore()
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = try store.export(name: "Same", profile: .factory, to: directory)
        let second = try store.export(name: "Same", profile: .factory, to: directory)

        #expect(first != second)
        #expect(FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: second.path))
    }

    @Test("A filename drops characters that do not belong in one")
    func filenameIsSanitised() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = ProfileStore.destinationURL(for: "my/../sparkles:*?", in: directory)
        #expect(url.lastPathComponent == "mysparkles.sparkletrail.json")
        #expect(url.deletingLastPathComponent().path == directory.path)
    }

    @Test("A nameless export still gets a filename")
    func namelessExportHasAFilename() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = ProfileStore.destinationURL(for: "///", in: directory)
        #expect(url.lastPathComponent == "Sparkle Trail profile.sparkletrail.json")
    }

    @Test("A file that is not a profile is refused")
    func refusesForeignFiles() throws {
        let store = emptyStore()
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("other.json")
        try #"{"app":"something-else","version":1}"#.write(to: url, atomically: true, encoding: .utf8)

        #expect(throws: ProfileStore.ImportError.self) {
            try store.importProfile(from: url)
        }
    }

    @Test("A profile from a newer release is refused by version")
    func refusesNewerFormats() throws {
        let store = emptyStore()
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = try store.export(name: "Future", profile: .factory, to: directory)
        let bumped = try String(contentsOf: url, encoding: .utf8)
            .replacingOccurrences(of: "\"version\" : 1", with: "\"version\" : 99")
        try bumped.write(to: url, atomically: true, encoding: .utf8)

        #expect(throws: ProfileStore.ImportError.self) {
            try store.importProfile(from: url)
        }
    }

    @Test("A missing file is refused")
    func refusesMissingFiles() {
        let store = emptyStore()
        let url = URL(fileURLWithPath: "/nowhere/at/all.sparkletrail.json")

        #expect(throws: ProfileStore.ImportError.self) {
            try store.importProfile(from: url)
        }
    }

    @Test("Saved profiles survive a reload")
    func profilesPersist() {
        let suite = "sparkletrail.tests.persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        ProfileStore(store: defaults).save(name: "Kept", profile: .factory)

        #expect(ProfileStore(store: defaults).profiles.map(\.name) == ["Kept"])
    }
}
