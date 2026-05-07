# Swiftly

> Take notes as Swiftly as possible (ASAP)

A lightweight macOS menu bar app for capturing notes instantly. Press a global keyboard shortcut, type your thought, press it again to save. Literally the fastest possible way to write notes, with zero friction.

## How It Works

Swiftly lives in your menu bar — no Dock icon, no main window. The entire workflow is:

1. **Press `⌥Space`** — a floating note panel appears with the cursor ready to type.
2. **Type your note.**
3. **Press `⌥Space` again** (or `⌘Return`) — the note is saved and the panel disappears.

That's it. Press `Escape` to discard without saving. Empty notes are automatically discarded.

## Features

Of course, it isn't that simple. Swiftly has many features that makes notetaking so fast:

- **Global hotkeys** — capture a note (`⌥Space`) or view all notes (`⌥⇧Space`) from any app, any time. Both shortcuts are fully customizable.
- **Floating panel** — appears above all windows, auto-focused and ready to type. No clicking required.
- **Plain text storage** — notes are saved as `.txt` files (one per note, named by timestamp) in a folder you choose. No database, no proprietary format. Default location: `~/Documents/Swiftly/`.
- **Notes browser** — searchable list of all saved notes with full-text search, inline expansion, copy, and delete.
- **MarkDown support** - MarkDown strings are beautifully auto-formatted.
- **Smart autocomplete** - After saving a note, typing similar words in a new note makes an inline gray ghost suggestion appear. Can be turned off in Settings.
- **Configurable storage path** — change where notes are stored via Settings.
- **Launch at Login** — optional, toggled in Settings.
- **No dependencies** — pure Swift, SwiftUI, and AppKit. No third-party packages.

## Keyboard Shortcuts

| Action | Default Shortcut | Configurable |
|---|---|---|
| New note (toggle panel) | `⌥Space` | Yes |
| View all notes | `⌥⇧Space` | Yes |
| Save & close note | `⌘Return` | No |
| Discard & close note | `Escape` | No |

## Menu Bar

Click the bolt icon in the menu bar to access:

- **New Note** — opens the capture panel
- **View Notes** — opens the notes browser window
- **Settings** — configure hotkeys, storage location, launch at login
- **Quit Swiftly**

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+ to build from source

## Building

```bash
git clone <repo-url>
cd Swiftly
xcodebuild -project Swiftly.xcodeproj -scheme Swiftly -configuration Release build
```

Or open `Swiftly.xcodeproj` in Xcode and press `⌘R`.

## Project Structure

```
Swiftly/
├── SwiftlyApp.swift          App entry point, menu bar, AppDelegate
├── NotePanel.swift           Floating NSPanel subclass
├── NotePanelController.swift Panel lifecycle, show/hide/save logic
├── NoteStore.swift           Filesystem persistence (read/write/delete .txt)
├── NotesListView.swift       Notes browser with search and delete
├── HotkeyManager.swift       Global hotkey registration (Carbon API)
├── Settings.swift            UserDefaults persistence, HotkeyCombo model
├── SettingsView.swift        Settings UI with hotkey recorder and folder picker
└── Assets.xcassets/          App icon and accent color
```

## How Notes Are Stored

Each note is a plain text file named by its creation timestamp:

```
~/Documents/Swiftly/
├── 2026-05-06_14-32-07.txt
├── 2026-05-06_10-15-42.txt
└── 2026-05-05_18-48-01.txt
```

You can read, edit, or sync these files with any tool — they're just text. The storage folder is configurable in Settings.

## License

MIT
