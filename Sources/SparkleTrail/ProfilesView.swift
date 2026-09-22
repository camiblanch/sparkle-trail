import AppKit
import SwiftUI

/// The compact profile control in the menu bar panel: pick a saved look, or
/// keep the current one under a name.
struct ProfileMenu: View {
    @ObservedObject var settings: SparkleSettings
    @ObservedObject private var store = ProfileStore.shared

    @State private var naming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Menu {
                    if store.profiles.isEmpty {
                        Text("No saved profiles")
                    } else {
                        ForEach(store.profiles) { saved in
                            Button {
                                settings.replaceProfile(with: saved.profile)
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
                .accessibilityLabel("Saved profiles")

                if !settings.undoStack.isEmpty {
                    Button {
                        settings.undoLastChange()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.borderless)
                    .help("Put back the settings from before the last profile change")
                    .accessibilityLabel("Undo the last profile change")
                }

                Spacer()

                Button(naming ? "Cancel" : "Save current…") { naming.toggle() }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }

            if naming {
                SaveProfileField(placeholder: "Profile name", buttonTitle: "Save") { name in
                    store.save(name: name, profile: settings.profile)
                    naming = false
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
    }

    private func matchesCurrent(_ saved: NamedProfile) -> Bool {
        saved.profile == settings.profile
    }
}

/// The full profile list in the settings window, with sharing.
struct ProfilesSection: View {
    @ObservedObject var settings: SparkleSettings
    @ObservedObject private var store = ProfileStore.shared


    var body: some View {
        if store.profiles.isEmpty {
            Text("No profiles yet. Save the current settings below to make one.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        ForEach(store.profiles) { saved in
            HStack(spacing: 8) {
                ProfileNameField(profile: saved) { store.rename(saved.id, to: $0) }

                Button("Apply") { settings.replaceProfile(with: saved.profile) }
                    .disabled(saved.profile == settings.profile)

                Menu {
                    Button("Update to current settings") {
                        store.update(saved.id, to: settings.profile)
                    }
                    Button("Export to Downloads…") {
                        export(name: saved.name, profile: saved.profile)
                    }
                    Divider()
                    Button("Delete", role: .destructive) { confirmDelete(saved) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }

        SaveProfileField(placeholder: "New profile name", buttonTitle: "Save current") { name in
            store.save(name: name, profile: settings.profile)
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
            Alerts.report(error, title: "Could not export the profile")
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
            Alerts.report(error, title: "Could not import that profile")
        }
    }

    /// Deleting a profile cannot be undone: the undo stack holds looks, not the
    /// list of saved profiles.
    private func confirmDelete(_ saved: NamedProfile) {
        guard Alerts.confirmDestructive(
            "Delete the profile “\(saved.name)”?",
            detail: "This cannot be undone. The current settings do not change.",
            confirm: "Delete") else { return }
        store.delete(saved.id)
    }
}

/// Takes a name and hands back the trimmed, non-empty version. Owns the field
/// text so neither caller repeats the trimming and the empty check.
struct SaveProfileField: View {
    let placeholder: String
    let buttonTitle: String
    let save: (String) -> Void

    @State private var name = ""

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(commit)
            Button(buttonTitle, action: commit)
                .disabled(trimmed.isEmpty)
        }
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    private func commit() {
        guard !trimmed.isEmpty else { return }
        save(trimmed)
        name = ""
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
