import AppKit
import SwiftUI

// MARK: - Floating note panel (NSPanel subclass)

/// A floating, always-on-top panel for quick note capture.
/// Configured to stay visible across all spaces and above other windows.
final class NotePanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 260),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        title = "Swiftly"
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .visible
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    // Required so the panel can accept keyboard input
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
