import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let noteStore = NoteStore()
    lazy var panelController = NotePanelController(noteStore: noteStore)
    let hotkeyManager = HotkeyManager()
    private var notesWindow: NSWindow?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotkeyManager.onNoteHotkey = { [weak self] in
            self?.panelController.toggle()
        }
        hotkeyManager.onViewNotesHotkey = { [weak self] in
            self?.showNotesWindow()
        }
        hotkeyManager.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.stop()
    }

    func showNotesWindow() {
        if let window = notesWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
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
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        notesWindow = window
    }

    func showSettingsWindow() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView(
            onHotkeysChanged: { [weak self] in
                self?.hotkeyManager.reregister()
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
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }
}

@main
struct SwiftlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Swiftly", systemImage: "bolt.fill") {
            Button("New Note  \(Settings.shared.hotkey.displayString)") {
                appDelegate.panelController.toggle()
            }

            Button("View Notes  \(Settings.shared.viewNotesHotkey.displayString)") {
                appDelegate.showNotesWindow()
            }

            Divider()

            Button("Settings...") {
                appDelegate.showSettingsWindow()
            }

            Button("Quit Swiftly") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
