import AppKit

enum MarkdownHighlighter {
    static let baseFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    private static let syntaxColor = NSColor.tertiaryLabelColor
    private static let codeBackground = NSColor.labelColor.withAlphaComponent(0.06)

    private static let codeBlockPattern = try! NSRegularExpression(pattern: "```[^\\n]*\\n[\\s\\S]*?```", options: [])
    private static let inlineCodePattern = try! NSRegularExpression(pattern: "`([^`\\n]+)`", options: [])
    private static let headingPattern = try! NSRegularExpression(pattern: "^(#{1,6})\\s+(.+)$", options: [.anchorsMatchLines])
    private static let boldStarPattern = try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: [])
    private static let boldUnderscorePattern = try! NSRegularExpression(pattern: "__(.+?)__", options: [])
    private static let italicStarPattern = try! NSRegularExpression(pattern: "(?<!\\*)\\*([^*\\n]+)\\*(?!\\*)", options: [])
    private static let italicUnderscorePattern = try! NSRegularExpression(pattern: "(?<!_)_([^_\\n]+)_(?!_)", options: [])
    private static let strikethroughPattern = try! NSRegularExpression(pattern: "~~(.+?)~~", options: [])
    private static let blockquotePattern = try! NSRegularExpression(pattern: "^(>)\\s?(.*)$", options: [.anchorsMatchLines])
    private static let listMarkerPattern = try! NSRegularExpression(pattern: "^(\\s*(?:[-*+]|\\d+\\.))\\s", options: [.anchorsMatchLines])
    private static let linkPattern = try! NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)", options: [])

    static func highlight(_ textStorage: NSTextStorage) {
        let string = textStorage.string
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        guard fullRange.length > 0 else { return }

        textStorage.beginEditing()

        textStorage.setAttributes([
            .font: baseFont,
            .foregroundColor: NSColor.textColor,
        ], range: fullRange)

        guard Settings.shared.markdownHighlighting else {
            textStorage.endEditing()
            return
        }

        var protected: [NSRange] = []
        applyCodeBlocks(textStorage, string: string, protected: &protected)
        applyInlineCode(textStorage, string: string, protected: &protected)
        applyHeadings(textStorage, string: string, protected: protected)
        applyBold(textStorage, string: string, protected: protected)
        applyItalic(textStorage, string: string, protected: protected)
        applyStrikethrough(textStorage, string: string, protected: protected)
        applyBlockquotes(textStorage, string: string, protected: protected)
        applyListMarkers(textStorage, string: string, protected: protected)
        applyLinks(textStorage, string: string, protected: protected)

        textStorage.endEditing()
    }

    static func attributedString(from text: String) -> NSAttributedString {
        let storage = NSTextStorage(string: text)
        highlight(storage)
        return NSAttributedString(attributedString: storage)
    }

    // MARK: - Protected range check

    private static func overlapsProtected(_ range: NSRange, _ protected: [NSRange]) -> Bool {
        protected.contains { NSIntersectionRange(range, $0).length > 0 }
    }

    // MARK: - Code

    private static func applyCodeBlocks(_ ts: NSTextStorage, string: String, protected: inout [NSRange]) {
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        for match in codeBlockPattern.matches(in: string, range: fullRange) {
            ts.addAttribute(.backgroundColor, value: codeBackground, range: match.range)
            protected.append(match.range)
        }
    }

    private static func applyInlineCode(_ ts: NSTextStorage, string: String, protected: inout [NSRange]) {
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        for match in inlineCodePattern.matches(in: string, range: fullRange) {
            guard !overlapsProtected(match.range, protected) else { continue }
            ts.addAttribute(.backgroundColor, value: codeBackground, range: match.range)
            ts.addAttribute(.foregroundColor, value: syntaxColor,
                            range: NSRange(location: match.range.location, length: 1))
            ts.addAttribute(.foregroundColor, value: syntaxColor,
                            range: NSRange(location: NSMaxRange(match.range) - 1, length: 1))
            protected.append(match.range)
        }
    }

    // MARK: - Headings

    private static func applyHeadings(_ ts: NSTextStorage, string: String, protected: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        let scales: [CGFloat] = [1.4, 1.25, 1.12, 1.0, 1.0, 1.0]
        for match in headingPattern.matches(in: string, range: fullRange) {
            guard !overlapsProtected(match.range, protected) else { continue }
            let hashRange = match.range(at: 1)
            let textRange = match.range(at: 2)
            let level = min(hashRange.length, 6)
            let size = baseFont.pointSize * scales[level - 1]
            let headingFont = NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
            ts.addAttribute(.foregroundColor, value: syntaxColor,
                            range: NSRange(location: hashRange.location,
                                           length: textRange.location - hashRange.location))
            ts.addAttribute(.font, value: headingFont, range: textRange)
        }
    }

    // MARK: - Bold / Italic / Strikethrough

    private static func applyBold(_ ts: NSTextStorage, string: String, protected: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        let boldFont = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .bold)
        for pattern in [boldStarPattern, boldUnderscorePattern] {
            for match in pattern.matches(in: string, range: fullRange) {
                guard !overlapsProtected(match.range, protected) else { continue }
                let content = match.range(at: 1)
                ts.addAttribute(.font, value: boldFont, range: content)
                let openLen = content.location - match.range.location
                let closeLen = NSMaxRange(match.range) - NSMaxRange(content)
                ts.addAttribute(.foregroundColor, value: syntaxColor,
                                range: NSRange(location: match.range.location, length: openLen))
                ts.addAttribute(.foregroundColor, value: syntaxColor,
                                range: NSRange(location: NSMaxRange(content), length: closeLen))
            }
        }
    }

    private static func applyItalic(_ ts: NSTextStorage, string: String, protected: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        for pattern in [italicStarPattern, italicUnderscorePattern] {
            for match in pattern.matches(in: string, range: fullRange) {
                guard !overlapsProtected(match.range, protected) else { continue }
                let content = match.range(at: 1)
                ts.addAttribute(.font, value: italicFont, range: content)
                ts.addAttribute(.foregroundColor, value: syntaxColor,
                                range: NSRange(location: match.range.location, length: 1))
                ts.addAttribute(.foregroundColor, value: syntaxColor,
                                range: NSRange(location: NSMaxRange(match.range) - 1, length: 1))
            }
        }
    }

    private static func applyStrikethrough(_ ts: NSTextStorage, string: String, protected: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        for match in strikethroughPattern.matches(in: string, range: fullRange) {
            guard !overlapsProtected(match.range, protected) else { continue }
            let content = match.range(at: 1)
            ts.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: content)
            ts.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: content)
            ts.addAttribute(.foregroundColor, value: syntaxColor,
                            range: NSRange(location: match.range.location, length: 2))
            ts.addAttribute(.foregroundColor, value: syntaxColor,
                            range: NSRange(location: NSMaxRange(match.range) - 2, length: 2))
        }
    }

    // MARK: - Block-level

    private static func applyBlockquotes(_ ts: NSTextStorage, string: String, protected: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        for match in blockquotePattern.matches(in: string, range: fullRange) {
            guard !overlapsProtected(match.range, protected) else { continue }
            ts.addAttribute(.foregroundColor, value: syntaxColor, range: match.range(at: 1))
            let textRange = match.range(at: 2)
            if textRange.length > 0 {
                ts.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: textRange)
            }
        }
    }

    private static func applyListMarkers(_ ts: NSTextStorage, string: String, protected: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        for match in listMarkerPattern.matches(in: string, range: fullRange) {
            guard !overlapsProtected(match.range, protected) else { continue }
            ts.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: match.range(at: 1))
        }
    }

    // MARK: - Links

    private static func applyLinks(_ ts: NSTextStorage, string: String, protected: [NSRange]) {
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        for match in linkPattern.matches(in: string, range: fullRange) {
            guard !overlapsProtected(match.range, protected) else { continue }
            let textRange = match.range(at: 1)
            let urlRange = match.range(at: 2)
            ts.addAttribute(.foregroundColor, value: NSColor.linkColor, range: textRange)
            ts.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: textRange)
            ts.addAttribute(.foregroundColor, value: syntaxColor, range: urlRange)
            ts.addAttribute(.foregroundColor, value: syntaxColor,
                            range: NSRange(location: match.range.location, length: 1))
            ts.addAttribute(.foregroundColor, value: syntaxColor,
                            range: NSRange(location: NSMaxRange(textRange), length: 2))
            ts.addAttribute(.foregroundColor, value: syntaxColor,
                            range: NSRange(location: NSMaxRange(match.range) - 1, length: 1))
        }
    }
}
