import AppKit
import SwiftUI

struct NotePanelContent: View {
    @Binding var text: String
    var onSave: () -> Void
    var onDiscard: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .padding(8)

            HStack {
                Text("\(Settings.shared.hotkey.displayString) save · ⌘Return save · Esc discard")
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
        .onAppear { isFocused = true }
        .onKeyPress(.escape) {
            onDiscard()
            return .handled
        }
        .onKeyPress(phases: .down) { keyPress in
            if keyPress.key == .return && keyPress.modifiers.contains(.command) {
                onSave()
                return .handled
            }
            return .ignored
        }
    }
}

@Observable
final class NotePanelController {
    private var panel: NotePanel?
    private var noteStore: NoteStore
    private var currentText = ""

    var isVisible: Bool { panel?.isVisible ?? false }

    init(noteStore: NoteStore) {
        self.noteStore = noteStore
    }

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
            onSave: { [weak self] in self?.saveAndClose() },
            onDiscard: { [weak self] in self?.discardAndClose() }
        )

        panel.contentView = NSHostingView(rootView: content)
        centerOnActiveScreen(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.panel = panel

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

    private func findTextView(in view: NSView?) -> NSTextView? {
        guard let view else { return nil }
        if let textView = view as? NSTextView { return textView }
        for subview in view.subviews {
            if let found = findTextView(in: subview) { return found }
        }
        return nil
    }

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
