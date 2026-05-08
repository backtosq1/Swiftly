import AppKit
import SwiftUI

// MARK: - Note panel content (SwiftUI view)

/// The SwiftUI content hosted inside the floating NotePanel.
/// Contains a monospaced TextEditor with keyboard shortcut hints.
struct NotePanelContent: View {
    @Binding var text: String
    var completionProvider: CompletionProvider
    var onSave: () -> Void
    var onDiscard: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            MarkdownTextView(text: $text, completionProvider: completionProvider,
                             onSave: onSave, onDiscard: onDiscard)

            HStack {
                Text("Tab to autocomplete · \(Settings.shared.hotkey.displayString) or ⌘Return to save · Esc to discard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(text.count) chars")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - Panel controller

/// Manages the note panel lifecycle: show, hide, save, discard.
/// The hotkey toggle calls `toggle()` which opens or saves+closes.
@Observable
final class NotePanelController {
    private var panel: NotePanel?
    private var noteStore: NoteStore
    private var currentText = ""

    var isVisible: Bool { panel?.isVisible ?? false }

    func refocus() {
        panel?.makeKeyAndOrderFront(nil)
    }

    init(noteStore: NoteStore) {
        self.noteStore = noteStore
    }

    /// Toggle the panel: if visible, save and close; if hidden, open a fresh panel.
    func toggle() {
        if isVisible {
            saveAndClose()
        } else {
            show()
        }
    }

    func show() {
        currentText = ""
        let panel = NotePanel()

        let content = NotePanelContent(
            text: Binding(
                get: { [weak self] in self?.currentText ?? "" },
                set: { [weak self] in self?.currentText = $0 }
            ),
            completionProvider: noteStore.completionProvider,
            onSave: { [weak self] in self?.saveAndClose() },
            onDiscard: { [weak self] in self?.discardAndClose() }
        )

        panel.contentView = NSHostingView(rootView: content)
        centerOnActiveScreen(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.panel = panel

        // Focus the TextEditor's underlying NSTextView after the view hierarchy is ready
        DispatchQueue.main.async {
            if let textView = self.findTextView(in: panel.contentView) {
                panel.makeFirstResponder(textView)
            }
        }
    }

    func saveAndClose() {
        noteStore.save(currentText)
        close()
    }

    func discardAndClose() {
        close()
    }

    private func close() {
        panel?.close()
        panel = nil
        currentText = ""
    }

    /// Walk the AppKit view hierarchy to find the NSTextView backing SwiftUI's TextEditor.
    private func findTextView(in view: NSView?) -> NSTextView? {
        guard let view else { return nil }
        if let textView = view as? NSTextView { return textView }
        for subview in view.subviews {
            if let found = findTextView(in: subview) { return found }
        }
        return nil
    }

    /// Position the panel slightly above center on the currently active screen.
    private func centerOnActiveScreen(_ panel: NotePanel) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else {
            panel.center()
            return
        }
        let panelFrame = panel.frame
        let x = visibleFrame.midX - panelFrame.width / 2
        let y = visibleFrame.midY - panelFrame.height / 2 + visibleFrame.height * 0.1
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
