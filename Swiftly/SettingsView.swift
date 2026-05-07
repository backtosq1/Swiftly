import SwiftUI
import Carbon.HIToolbox

struct SettingsView: View {
    @State private var isRecordingNote = false
    @State private var isRecordingViewNotes = false
    @State private var noteHotkey: HotkeyCombo = Settings.shared.hotkey
    @State private var viewNotesHotkey: HotkeyCombo = Settings.shared.viewNotesHotkey
    @State private var launchAtLogin: Bool = Settings.shared.launchAtLogin
    @State private var markdownHighlighting: Bool = Settings.shared.markdownHighlighting
    @State private var autocomplete: Bool = Settings.shared.autocomplete
    @State private var storagePath: String = Settings.shared.storageDirectory.path
    var onHotkeysChanged: (() -> Void)?
    var onStorageChanged: ((URL) -> Void)?

    var body: some View {
        Form {
            Section("Hotkeys") {
                HStack {
                    Text("New note:")
                    Spacer()
                    hotkeyRecorderButton(
                        isRecording: $isRecordingNote,
                        combo: $noteHotkey,
                        onRecord: { combo in
                            Settings.shared.hotkey = combo
                            onHotkeysChanged?()
                        }
                    )
                }

                HStack {
                    Text("View all notes:")
                    Spacer()
                    hotkeyRecorderButton(
                        isRecording: $isRecordingViewNotes,
                        combo: $viewNotesHotkey,
                        onRecord: { combo in
                            Settings.shared.viewNotesHotkey = combo
                            onHotkeysChanged?()
                        }
                    )
                }

                Button("Reset All to Defaults") {
                    noteHotkey = .default
                    viewNotesHotkey = .defaultViewNotes
                    Settings.shared.hotkey = .default
                    Settings.shared.viewNotesHotkey = .defaultViewNotes
                    onHotkeysChanged?()
                }
                .disabled(noteHotkey == .default && viewNotesHotkey == .defaultViewNotes)
            }

            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        Settings.shared.launchAtLogin = newValue
                    }
                Toggle("Markdown Highlighting", isOn: $markdownHighlighting)
                    .onChange(of: markdownHighlighting) { _, newValue in
                        Settings.shared.markdownHighlighting = newValue
                    }
                Toggle("Autocomplete", isOn: $autocomplete)
                    .onChange(of: autocomplete) { _, newValue in
                        Settings.shared.autocomplete = newValue
                    }
            }

            Section("Storage") {
                HStack {
                    Text("Notes folder:")
                    Spacer()
                    Text(displayPath(storagePath))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(storagePath)
                }

                HStack {
                    Button("Change...") {
                        pickFolder()
                    }
                    Button("Open in Finder") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: storagePath))
                    }
                    Spacer()
                    if storagePath != Settings.defaultStorageDirectory.path {
                        Button("Reset") {
                            let url = Settings.defaultStorageDirectory
                            storagePath = url.path
                            onStorageChanged?(url)
                        }
                    }
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 420)
    }

    private func hotkeyRecorderButton(
        isRecording: Binding<Bool>,
        combo: Binding<HotkeyCombo>,
        onRecord: @escaping (HotkeyCombo) -> Void
    ) -> some View {
        Button {
            isRecordingNote = false
            isRecordingViewNotes = false
            isRecording.wrappedValue = true
        } label: {
            if isRecording.wrappedValue {
                Text("Press a key combo...")
                    .foregroundStyle(.orange)
                    .frame(minWidth: 140)
            } else {
                Text(combo.wrappedValue.displayString)
                    .frame(minWidth: 140)
            }
        }
        .buttonStyle(.bordered)
        .background {
            if isRecording.wrappedValue {
                HotkeyRecorderView { newCombo in
                    combo.wrappedValue = newCombo
                    isRecording.wrappedValue = false
                    onRecord(newCombo)
                } onCancel: {
                    isRecording.wrappedValue = false
                }
            }
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: storagePath)
        panel.prompt = "Choose"
        panel.message = "Select a folder to store your notes"

        if panel.runModal() == .OK, let url = panel.url {
            storagePath = url.path
            onStorageChanged?(url)
        }
    }

    private func displayPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

struct HotkeyRecorderView: NSViewRepresentable {
    var onRecord: (HotkeyCombo) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.onRecord = onRecord
        view.onCancel = onCancel
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {}
}

final class HotkeyRecorderNSView: NSView {
    var onRecord: ((HotkeyCombo) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            onCancel?()
            return
        }

        let carbonModifiers = carbonModifiers(from: event.modifierFlags)
        guard carbonModifiers != 0 else { return }

        let combo = HotkeyCombo(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers)
        onRecord?(combo)
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        return result
    }
}
