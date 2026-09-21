import AppKit
import SwiftUI

/// The compact profile control in the menu bar panel: pick a saved look, or
/// keep the current one under a name.
struct ProfileMenu: View {
    @ObservedObject var settings: SparkleSettings
    @ObservedObject private var store = ProfileStore.shared

    @State private var naming = false
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Menu {
                    if store.profiles.isEmpty {
                        Text("No saved profiles")
                    } else {
                        ForEach(store.profiles) { saved in
                            Button {
                                settings.profile = saved.profile
                            } label: {
                                Text(matchesCurrent(saved) ? "✓ \(saved.name)" : saved.name)
                            }
                        }
                    }
                } label: {
                    Label("Profiles", systemImage: "square.stack")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Apply a saved profile")

                Spacer()

                Button(naming ? "Cancel" : "Save current…") {
                    naming.toggle()
                    newName = ""
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            if naming {
                HStack(spacing: 6) {
                    TextField("Profile name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .onSubmit(saveCurrent)
                    Button("Save", action: saveCurrent)
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func matchesCurrent(_ saved: NamedProfile) -> Bool {
        saved.profile == settings.profile
    }

    private func saveCurrent() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        store.save(name: name, profile: settings.profile)
        naming = false
        newName = ""
    }
}

/// The full profile list in the settings window, with sharing.
struct ProfilesSection: View {
    @ObservedObject var settings: SparkleSettings
    @ObservedObject private var store = ProfileStore.shared

    @State private var newName = ""

    var body: some View {
        if store.profiles.isEmpty {
            Text("No profiles yet. Save the current settings below to make one.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        ForEach(store.profiles) { saved in
            HStack(spacing: 8) {
                ProfileNameField(profile: saved) { store.rename(saved.id, to: $0) }

                Button("Apply") { settings.profile = saved.profile }
                    .disabled(saved.profile == settings.profile)

                Menu {
                    Button("Update to current settings") {
                        store.update(saved.id, to: settings.profile)
                    }
                    Button("Export to Downloads…") {
                        export(name: saved.name, profile: saved.profile)
                    }
                    Divider()
                    Button("Delete", role: .destructive) { store.delete(saved.id) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }

        HStack(spacing: 8) {
            TextField("New profile name", text: $newName)
                .textFieldStyle(.roundedBorder)
            Button("Save current") {
                let name = newName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                store.save(name: name, profile: settings.profile)
                newName = ""
            }
            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
        }

        HStack {
            Button("Export current…") {
                export(name: "Sparkle Trail profile", profile: settings.profile)
            }
            Spacer()
            Button("Import…", action: importProfile)
        }
    }

    private func export(name: String, profile: SparkleProfile) {
        do {
            try store.export(name: name, profile: profile)
        } catch {
            present(error: error, title: "Could not export the profile")
        }
    }

    private func importProfile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try store.importProfile(from: url)
        } catch {
            present(error: error, title: "Could not import that profile")
        }
    }

    private func present(error: Error, title: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}

/// Commits a rename on Return or when focus leaves, so a typed name is not lost
/// by clicking away, and renaming does not run on every keystroke.
private struct ProfileNameField: View {
    let profile: NamedProfile
    let commit: (String) -> Void

    @State private var text: String
    @FocusState private var focused: Bool

    init(profile: NamedProfile, commit: @escaping (String) -> Void) {
        self.profile = profile
        self.commit = commit
        _text = State(initialValue: profile.name)
    }

    var body: some View {
        TextField("Name", text: $text)
            .textFieldStyle(.roundedBorder)
            .focused($focused)
            .onSubmit { commit(text) }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit(text) }
            }
            .onChange(of: profile.name) { _, updated in
                if !focused { text = updated }
            }
    }
}
