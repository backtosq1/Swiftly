import SwiftUI
import Sparkle

// MARK: - App Delegate

/// Owns the shared instances (NoteStore, HotkeyManager, NotePanelController)
/// and manages the notes and settings windows.
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let noteStore = NoteStore()
    lazy var panelController = NotePanelController(noteStore: noteStore)
    let hotkeyManager = HotkeyManager()
    let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    @Published var noteHotkeyDisplay: String = Settings.shared.hotkey.displayString
    @Published var viewNotesHotkeyDisplay: String = Settings.shared.viewNotesHotkey.displayString
    private var notesWindow: NSWindow?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotkeyManager.onNoteHotkey = { [weak self] in
            self?.panelController.toggle()
        }
        hotkeyManager.onViewNotesHotkey = { [weak self] in
            self?.toggleNotesWindow()
        }
        hotkeyManager.start()

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(spaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.stop()
    }

    @objc private func spaceDidChange() {
        DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
            guard let self else { return }
            if self.panelController.isVisible {
                NSApp.activate(ignoringOtherApps: true)
                self.panelController.refocus()
            } else if let window = self.notesWindow, window.isVisible {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            } else if let window = self.settingsWindow, window.isVisible {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    // MARK: - Notes window

    /// Toggle the notes browser: close if visible, otherwise create and show.
    func toggleNotesWindow() {
        if let window = notesWindow, window.isVisible {
            window.close()
            return
        }

        let view = NotesListView(noteStore: noteStore)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Notes"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 320, height: 300)
        window.collectionBehavior = [.canJoinAllSpaces]
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        notesWindow = window

        // Focus the search bar after the hosting view has laid out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let textField = Self.findFirstTextField(in: window.contentView) {
                window.makeFirstResponder(textField)
            }
        }
    }

    /// Walk the view hierarchy to find the first editable NSTextField (the search bar).
    private static func findFirstTextField(in view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let tf = view as? NSTextField, tf.isEditable { return tf }
        for subview in view.subviews {
            if let found = findFirstTextField(in: subview) { return found }
        }
        return nil
    }

    // MARK: - Settings window

    func showSettingsWindow() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView(
            onHotkeysChanged: { [weak self] in
                self?.hotkeyManager.reregister()
                self?.noteHotkeyDisplay = Settings.shared.hotkey.displayString
                self?.viewNotesHotkeyDisplay = Settings.shared.viewNotesHotkey.displayString
            },
            onStorageChanged: { [weak self] url in
                self?.noteStore.updateStorageDirectory(url)
            }
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Swiftly Settings"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces]
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }
}

// MARK: - SwiftUI App entry point

@main
struct SwiftlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Swiftly", systemImage: "bolt.fill") {
            Button("New Note  \(appDelegate.noteHotkeyDisplay)") {
                appDelegate.panelController.toggle()
            }

            Button("View Notes  \(appDelegate.viewNotesHotkeyDisplay)") {
                appDelegate.toggleNotesWindow()
            }

            Divider()

            Button("Settings...") {
                appDelegate.showSettingsWindow()
            }

            Button("Check for Updates...") {
                appDelegate.updaterController.checkForUpdates(nil)
            }

            Button("Quit Swiftly") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
