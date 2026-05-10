import AppKit
import SwiftUI

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var completionProvider: CompletionProvider
    var onSave: () -> Void
    var onDiscard: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        let textView = MarkdownNSTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.font = MarkdownHighlighter.baseFont
        textView.textColor = .textColor
        textView.insertionPointColor = .textColor
        textView.drawsBackground = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.onSave = onSave
        textView.onDiscard = onDiscard
        textView.completionProvider = completionProvider

        context.coordinator.textView = textView

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = textView
        scrollView.autohidesScrollers = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }
        textView.onSave = onSave
        textView.onDiscard = onDiscard
        textView.completionProvider = completionProvider

        if textView.string != text {
            context.coordinator.isUpdating = true
            textView.string = text
            if let ts = textView.textStorage {
                MarkdownHighlighter.highlight(ts)
            }
            context.coordinator.isUpdating = false
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView
        weak var textView: MarkdownNSTextView?
        var isUpdating = false

        init(parent: MarkdownTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = notification.object as? MarkdownNSTextView else { return }
            parent.text = textView.string
            textView.undoManager?.disableUndoRegistration()
            if let ts = textView.textStorage {
                MarkdownHighlighter.highlight(ts)
            }
            textView.typingAttributes = [
                .font: MarkdownHighlighter.baseFont,
                .foregroundColor: NSColor.textColor,
            ]
            textView.undoManager?.enableUndoRegistration()
            textView.updateCompletion()
        }
    }
}

// MARK: - NSTextView subclass with ghost-text autocomplete

final class MarkdownNSTextView: NSTextView {
    var onSave: (() -> Void)?
    var onDiscard: (() -> Void)?
    var completionProvider: CompletionProvider?
    private(set) var ghostSuggestion: String?

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawGhostText()
    }

    private func drawGhostText() {
        guard let ghost = ghostSuggestion, !ghost.isEmpty else { return }
        guard let origin = ghostTextOrigin() else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font ?? MarkdownHighlighter.baseFont,
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]
        NSAttributedString(string: ghost, attributes: attrs).draw(at: origin)
    }

    private func ghostTextOrigin() -> NSPoint? {
        guard let lm = layoutManager, let tc = textContainer else { return nil }
        let nsString = string as NSString
        let textLength = nsString.length
        let cursor = selectedRange().location
        guard cursor > 0, cursor <= textLength else { return nil }

        let prevChar = nsString.character(at: cursor - 1)
        let isNewline = prevChar == 0x0A || prevChar == 0x0D

        if isNewline {
            if cursor < textLength {
                let glyphRange = lm.glyphRange(forCharacterRange: NSRange(location: cursor, length: 1),
                                               actualCharacterRange: nil)
                guard glyphRange.location != NSNotFound else { return nil }
                let rect = lm.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
                return NSPoint(x: textContainerOrigin.x + tc.lineFragmentPadding,
                               y: textContainerOrigin.y + rect.minY)
            } else {
                let rect = lm.extraLineFragmentRect
                guard rect != .zero else { return nil }
                return NSPoint(x: textContainerOrigin.x + rect.minX + tc.lineFragmentPadding,
                               y: textContainerOrigin.y + rect.minY)
            }
        }

        let charRange = NSRange(location: cursor - 1, length: 1)
        let glyphRange = lm.glyphRange(forCharacterRange: charRange, actualCharacterRange: nil)
        guard glyphRange.location != NSNotFound else { return nil }
        let lineRect = lm.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        let boundingRect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
        return NSPoint(x: textContainerOrigin.x + boundingRect.maxX,
                       y: textContainerOrigin.y + lineRect.minY)
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 0x30, ghostSuggestion != nil {
            acceptGhostText()
            return
        }
        if event.keyCode == 0x35 {
            if ghostSuggestion != nil {
                ghostSuggestion = nil
                needsDisplay = true
                return
            }
            onDiscard?()
            return
        }
        if event.keyCode == 0x24, event.modifierFlags.contains(.command) {
            onSave?()
            return
        }
        ghostSuggestion = nil
        super.keyDown(with: event)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        ghostSuggestion = nil
        needsDisplay = true
        super.mouseDown(with: event)
    }

    override func paste(_ sender: Any?) {
        ghostSuggestion = nil
        pasteAsPlainText(sender)
    }

    // MARK: - Completion logic

    func updateCompletion() {
        let old = ghostSuggestion
        ghostSuggestion = computeSuggestion()
        if ghostSuggestion != old {
            needsDisplay = true
        }
    }

    private func computeSuggestion() -> String? {
        guard Settings.shared.autocomplete, let provider = completionProvider else { return nil }
        guard selectedRange().length == 0 else { return nil }

        let cursor = selectedRange().location
        let nsString = string as NSString
        let textLength = nsString.length
        if cursor < textLength {
            let nextRange = NSRange(location: cursor, length: 1)
            let nextChar = nsString.substring(with: nextRange)
            if let scalar = nextChar.unicodeScalars.first,
               CharacterSet.alphanumerics.contains(scalar) {
                return nil
            }
        }

        guard let prefix = currentWordPrefix() else { return nil }
        return provider.complete(prefix: prefix)
    }

    private func acceptGhostText() {
        guard let ghost = ghostSuggestion else { return }
        ghostSuggestion = nil
        insertText(ghost, replacementRange: selectedRange())
    }

    private func currentWordPrefix() -> String? {
        let nsString = string as NSString
        let cursor = selectedRange().location
        guard cursor > 0 else { return nil }
        var start = cursor
        while start > 0 {
            let range = NSRange(location: start - 1, length: 1)
            let char = nsString.substring(with: range)
            guard let scalar = char.unicodeScalars.first,
                  CharacterSet.alphanumerics.contains(scalar) else { break }
            start -= 1
        }
        guard start < cursor else { return nil }
        return nsString.substring(with: NSRange(location: start, length: cursor - start))
    }
}
