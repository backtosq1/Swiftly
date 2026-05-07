# Swiftly

A macOS utility for capturing notes instantly via a global keyboard shortcut. Press a key combo to pop open a note, type your thought, press the combo again to save and dismiss. Zero friction.

## Core Concept

Swiftly lives in the menu bar. It has no main window. The entire interaction is:

1. Press global hotkey (default: `⌥ + Space`) → a small floating text panel appears, focused and ready for typing.
2. Type your note.
3. Press the same hotkey (or `⌘ + Return`) → the note is saved, the panel disappears.

That's it. Speed is the point — no titles, no categories, no formatting. Just raw capture.

## Architecture

- **Platform:** macOS (SwiftUI, AppKit for global hotkey and menu bar)
- **Minimum target:** macOS 14 (Sonoma)
- **Persistence:** Plain text files stored in `~/Documents/Swiftly/`, one file per note, named by timestamp (`2026-05-06_14-32-07.txt`). No database.
- **State management:** `@Observable` classes; no external dependencies.

### Components

| File | Purpose |
|---|---|
| `SwiftlyApp.swift` | App entry point. Sets up as menu bar–only app (`MenuBarExtra`). Registers the global hotkey listener. |
| `NotePanel.swift` | The floating panel (`NSPanel`) that appears on hotkey press. Contains a single `TextEditor`. Autofocuses on appear. |
| `NotePanelController.swift` | Manages panel lifecycle — show, hide, save-on-dismiss. Owns the toggle logic (press hotkey once to open, again to close+save). |
| `NoteStore.swift` | Reads/writes note files to `~/Documents/Swiftly/`. Lists all saved notes sorted by date descending. Deletes notes. |
| `NotesListView.swift` | SwiftUI view showing all previous notes in a scrollable list. Opened from the menu bar icon. Supports search and delete. |
| `SettingsView.swift` | Lets the user change the global hotkey and choose the storage directory. |
| `HotkeyManager.swift` | Registers and unregisters the global hotkey using `CGEvent` tap or `NSEvent.addGlobalMonitorForEvents`. Handles Accessibility permissions prompt. |
| `Assets.xcassets` | Menu bar icon and app icon. |

### Data Flow

```
HotkeyManager (global key event)
    │
    ▼
NotePanelController.toggle()
    ├── panel hidden? → create/show NotePanel, focus TextEditor
    └── panel visible? → grab text, call NoteStore.save(), hide panel
```

## Features

### MVP (v1)

- [ ] Menu bar–only app (no Dock icon)
- [ ] Global hotkey (`⌥ + Space` default) toggles a floating note panel
- [ ] Panel appears centered on the active screen, floating above all windows
- [ ] Single `TextEditor` — no title field, no formatting
- [ ] Pressing the hotkey again (or `⌘ + Return`) saves and dismisses
- [ ] Pressing `Escape` dismisses without saving
- [ ] Notes saved as plain `.txt` files in `~/Documents/Swiftly/`
- [ ] "View Notes" menu item opens a list of all saved notes
- [ ] Notes list supports search (full-text substring match)
- [ ] Notes list supports delete (with confirmation)
- [ ] Click a note in the list to view its full content
- [ ] "Settings" menu item to configure the hotkey
- [ ] Request Accessibility permission on first launch (required for global hotkey)

### Non-Goals (keep it simple)

- No rich text, Markdown rendering, or formatting toolbar
- No tags, folders, or categories
- No sync, cloud, or network features
- No iOS/iPadOS version
- No Spotlight or Shortcuts integration

## UI

### Menu Bar

```
[ 📝 ▾ ]
├── New Note          (⌥ Space)
├── View Notes...     (⌘ ⇧ N)
├── ─────────────
├── Settings...       (⌘ ,)
└── Quit Swiftly      (⌘ Q)
```

### Note Panel

```
┌──────────────────────────────────┐
│  Swiftly                    ── □ │
│ ┌──────────────────────────────┐ │
│ │                              │ │
│ │  (blinking cursor, ready)    │ │
│ │                              │ │
│ │                              │ │
│ └──────────────────────────────┘ │
│  ⌥Space save · Esc discard      │
└──────────────────────────────────┘
```

Dimensions: ~480×260 pt. No resize handle. Floating level (`NSWindow.Level.floating`).

### Notes List

```
┌──────────────────────────────────────┐
│  Notes                         ✕     │
│ ┌──────────────────────────────────┐ │
│ │ 🔍 Search...                     │ │
│ └──────────────────────────────────┘ │
│ ┌──────────────────────────────────┐ │
│ │ May 6, 2026 2:32 PM             │ │
│ │ Remember to call the dentist...  │ │
│ ├──────────────────────────────────┤ │
│ │ May 6, 2026 10:15 AM            │ │
│ │ API endpoint: /v2/users/me ...   │ │
│ ├──────────────────────────────────┤ │
│ │ May 5, 2026 6:48 PM             │ │
│ │ Grocery list: eggs, bread...     │ │
│ └──────────────────────────────────┘ │
└──────────────────────────────────────┘
```

Each row shows the date and a one-line preview (first 80 characters). Clicking a row expands it inline or opens a detail view.

## Implementation Order

1. **Scaffold** — Create Xcode project, configure as menu bar–only (set `LSUIElement = YES`), add `MenuBarExtra`.
2. **NoteStore** — Implement save/load/delete/list against the filesystem.
3. **NotePanel + Controller** — Build the floating panel, wire up show/hide/save.
4. **HotkeyManager** — Register global hotkey, request Accessibility, wire to controller toggle.
5. **NotesListView** — Build the notes browser with search and delete.
6. **SettingsView** — Hotkey customization and storage directory picker.
7. **Polish** — App icon, menu bar icon, launch-at-login option, edge cases (empty note discard, very long notes).
