import Foundation
import Carbon.HIToolbox
import ServiceManagement

struct HotkeyCombo: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyName(for: keyCode))
        return parts.joined()
    }

    static let `default` = HotkeyCombo(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))
    static let defaultViewNotes = HotkeyCombo(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey | shiftKey))

    private func keyName(for code: UInt32) -> String {
        switch Int(code) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_Escape: return "Esc"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: return "Key(\(code))"
        }
    }
}

final class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard
    private let hotkeyCodeKey = "hotkeyKeyCode"
    private let hotkeyModifiersKey = "hotkeyModifiers"
    private let viewNotesHotkeyCodeKey = "viewNotesHotkeyKeyCode"
    private let viewNotesHotkeyModifiersKey = "viewNotesHotkeyModifiers"
    private let storagePathKey = "storageDirectoryPath"
    private let markdownHighlightingKey = "markdownHighlighting"
    private let autocompleteKey = "autocomplete"

    var hotkey: HotkeyCombo {
        get {
            guard defaults.object(forKey: hotkeyCodeKey) != nil else { return .default }
            return HotkeyCombo(
                keyCode: UInt32(defaults.integer(forKey: hotkeyCodeKey)),
                modifiers: UInt32(defaults.integer(forKey: hotkeyModifiersKey))
            )
        }
        set {
            defaults.set(Int(newValue.keyCode), forKey: hotkeyCodeKey)
            defaults.set(Int(newValue.modifiers), forKey: hotkeyModifiersKey)
        }
    }

    var viewNotesHotkey: HotkeyCombo {
        get {
            guard defaults.object(forKey: viewNotesHotkeyCodeKey) != nil else { return .defaultViewNotes }
            return HotkeyCombo(
                keyCode: UInt32(defaults.integer(forKey: viewNotesHotkeyCodeKey)),
                modifiers: UInt32(defaults.integer(forKey: viewNotesHotkeyModifiersKey))
            )
        }
        set {
            defaults.set(Int(newValue.keyCode), forKey: viewNotesHotkeyCodeKey)
            defaults.set(Int(newValue.modifiers), forKey: viewNotesHotkeyModifiersKey)
        }
    }

    static let defaultStorageDirectory: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Swiftly", isDirectory: true)
    }()

    var storageDirectory: URL {
        get {
            guard let path = defaults.string(forKey: storagePathKey) else {
                return Self.defaultStorageDirectory
            }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        set {
            defaults.set(newValue.path, forKey: storagePathKey)
        }
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {}
        }
    }

    var markdownHighlighting: Bool {
        get {
            guard defaults.object(forKey: markdownHighlightingKey) != nil else { return true }
            return defaults.bool(forKey: markdownHighlightingKey)
        }
        set { defaults.set(newValue, forKey: markdownHighlightingKey) }
    }

    var autocomplete: Bool {
        get {
            guard defaults.object(forKey: autocompleteKey) != nil else { return true }
            return defaults.bool(forKey: autocompleteKey)
        }
        set { defaults.set(newValue, forKey: autocompleteKey) }
    }
}
