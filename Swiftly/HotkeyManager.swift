import AppKit
import Carbon.HIToolbox

@Observable
final class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var noteHotKey: EventHotKeyRef?
    private var viewNotesHotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onNoteHotkey: (() -> Void)?
    var onViewNotesHotkey: (() -> Void)?

    private static let noteHotkeyID: UInt32 = 1
    private static let viewNotesHotkeyID: UInt32 = 2

    func start() {
        stop()
        let noteCombo = Settings.shared.hotkey
        let viewCombo = Settings.shared.viewNotesHotkey
        registerCarbonHotkeys(noteCombo: noteCombo, viewNotesCombo: viewCombo)
    }

    func stop() {
        if let ref = noteHotKey {
            UnregisterEventHotKey(ref)
            noteHotKey = nil
        }
        if let ref = viewNotesHotKey {
            UnregisterEventHotKey(ref)
            viewNotesHotKey = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    func reregister() {
        stop()
        let noteCombo = Settings.shared.hotkey
        let viewCombo = Settings.shared.viewNotesHotkey
        registerCarbonHotkeys(noteCombo: noteCombo, viewNotesCombo: viewCombo)
    }

    private func registerCarbonHotkeys(noteCombo: HotkeyCombo, viewNotesCombo: HotkeyCombo) {
        var noteID = EventHotKeyID()
        noteID.signature = OSType(0x5357_4654)
        noteID.id = Self.noteHotkeyID

        var noteRef: EventHotKeyRef?
        let noteStatus = RegisterEventHotKey(
            noteCombo.keyCode, noteCombo.modifiers, noteID,
            GetApplicationEventTarget(), 0, &noteRef
        )
        if noteStatus == noErr { noteHotKey = noteRef }

        var viewID = EventHotKeyID()
        viewID.signature = OSType(0x5357_4654)
        viewID.id = Self.viewNotesHotkeyID

        var viewRef: EventHotKeyRef?
        let viewStatus = RegisterEventHotKey(
            viewNotesCombo.keyCode, viewNotesCombo.modifiers, viewID,
            GetApplicationEventTarget(), 0, &viewRef
        )
        if viewStatus == noErr { viewNotesHotKey = viewRef }

        if noteHotKey == nil && viewNotesHotKey == nil {
            fallbackToNSEventMonitors(noteCombo: noteCombo, viewNotesCombo: viewNotesCombo)
            return
        }

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var handlerRef: EventHandlerRef?
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let userData, let event else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)

            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                switch hotKeyID.id {
                case HotkeyManager.noteHotkeyID:
                    manager.onNoteHotkey?()
                case HotkeyManager.viewNotesHotkeyID:
                    manager.onViewNotesHotkey?()
                default:
                    break
                }
            }
            return noErr
        }, 1, &eventSpec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
        eventHandler = handlerRef
    }

    private func fallbackToNSEventMonitors(noteCombo: HotkeyCombo, viewNotesCombo: HotkeyCombo) {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.matchesEvent(event, combo: noteCombo) == true {
                DispatchQueue.main.async { self?.onNoteHotkey?() }
            } else if self?.matchesEvent(event, combo: viewNotesCombo) == true {
                DispatchQueue.main.async { self?.onViewNotesHotkey?() }
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.matchesEvent(event, combo: noteCombo) == true {
                DispatchQueue.main.async { self?.onNoteHotkey?() }
                return nil
            } else if self?.matchesEvent(event, combo: viewNotesCombo) == true {
                DispatchQueue.main.async { self?.onViewNotesHotkey?() }
                return nil
            }
            return event
        }
    }

    private func matchesEvent(_ event: NSEvent, combo: HotkeyCombo) -> Bool {
        guard event.keyCode == UInt16(combo.keyCode) else { return false }
        if combo.modifiers & UInt32(optionKey) != 0 && !event.modifierFlags.contains(.option) { return false }
        if combo.modifiers & UInt32(cmdKey) != 0 && !event.modifierFlags.contains(.command) { return false }
        if combo.modifiers & UInt32(shiftKey) != 0 && !event.modifierFlags.contains(.shift) { return false }
        if combo.modifiers & UInt32(controlKey) != 0 && !event.modifierFlags.contains(.control) { return false }
        return true
    }
}
