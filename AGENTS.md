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
- **State management:** `@Observable` classes.
- **Dependencies:** [Sparkle 2.x](https://github.com/sparkle-project/Sparkle) for auto-updates (via SPM).

### Components

| File | Purpose |
|---|---|
| `SwiftlyApp.swift` | App entry point. Sets up as menu bar–only app (`MenuBarExtra`). Registers the global hotkey listener. Initializes Sparkle updater. |
| `NotePanel.swift` | The floating panel (`NSPanel`) that appears on hotkey press. Autofocuses on appear. |
| `NotePanelController.swift` | Manages panel lifecycle — show, hide, save-on-dismiss. Owns the toggle logic (press hotkey once to open, again to close+save). |
| `NoteStore.swift` | Reads/writes note files to `~/Documents/Swiftly/`. Lists all saved notes sorted by date descending. Deletes notes. Owns `CompletionProvider`. |
| `NotesListView.swift` | SwiftUI view showing all previous notes in a scrollable list. Opened from the menu bar icon. Supports search and delete. |
| `SettingsView.swift` | Lets the user change the global hotkey, choose the storage directory, toggle Markdown highlighting and autocomplete. |
| `HotkeyManager.swift` | Registers and unregisters the global hotkey using `CGEvent` tap or `NSEvent.addGlobalMonitorForEvents`. Handles Accessibility permissions prompt. |
| `MarkdownTextView.swift` | `NSViewRepresentable` wrapping `NSTextView` with live Markdown highlighting and ghost-text autocomplete. |
| `MarkdownHighlighter.swift` | Regex-based Markdown parser. Applies inline styles to `NSTextStorage` (bold, italic, code, headings, links, etc.). |
| `CompletionProvider.swift` | Builds a frequency-sorted word index from saved notes. Provides prefix-based completion for ghost text. |
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

---

## Feature Plan: Markdown Support & Text Autocomplete

### Feasibility Assessment

Both features are **feasible** within the current architecture. The app already bridges SwiftUI and AppKit, and `NotePanelController` already walks the view hierarchy to access the underlying `NSTextView`. This gives us the AppKit hooks needed for both features. However, they require replacing the SwiftUI `TextEditor` with a direct `NSTextView` wrapper for full control.

### Feature 1: Live Markdown Syntax Highlighting

**Goal:** As the user types Markdown in the note panel, apply inline syntax highlighting (bold text appears bold, headings appear larger, code spans get a monospace background, etc.). The editing surface stays a single plain-text editor — no split pane, no separate preview. The raw Markdown characters remain visible and editable, but styled in place.

**Why not a preview pane?** Swiftly's core value is speed and zero friction. A preview pane doubles the UI surface and splits attention. Inline highlighting gives the user visual feedback without changing the interaction model.

**Approach:**

1. **Replace `TextEditor` with an `NSViewRepresentable` wrapping `NSTextView` directly.**
   - File: new `MarkdownTextView.swift`
   - The current `TextEditor` is a black box — we can't control its `NSTextStorage` or text attributes. A direct `NSTextView` gives us full access.
   - Wire the `@Binding var text: String` to `NSTextViewDelegate.textDidChange(_:)`.
   - Preserve existing behavior: monospaced font, scroll background hidden, padding, focus state.

2. **Add a lightweight Markdown parser using `apple/swift-markdown` (SPM).**
   - Apple's `swift-markdown` is a zero-dependency Swift package that parses CommonMark into a typed AST.
   - We walk the AST to extract source ranges for: **bold**, *italic*, `code spans`, ## headings, - list markers, > blockquotes, [links].
   - Output: an array of `(NSRange, [NSAttributedString.Key: Any])` style runs.

3. **Apply styles to `NSTextStorage` on every text change.**
   - File: new `MarkdownHighlighter.swift`
   - On `textDidChange`, re-parse and re-apply attributes.
   - Reset all attributes to the base style first (monospaced body font), then overlay Markdown styles.
   - Styles: bold → `.boldSystemFont`, italic → italic trait, code → slightly smaller monospaced + subtle background color, headings → larger font size, blockquotes → gray foreground, links → accent color + underline.
   - Optimization: for notes under ~5 KB (typical for Swiftly), full re-parse on every keystroke is negligible (<1 ms). No incremental parsing needed.

4. **Update `NoteStore` to save as `.md` instead of `.txt`.**
   - Change filename extension in `save()` from `.txt` to `.md`.
   - Update `loadNotes()` filter to accept both `.txt` and `.md` for backward compatibility.
   - No migration needed — existing `.txt` notes continue to load and display fine.

5. **Update `NotesListView` to render Markdown in the expanded note view.**
   - When a note is expanded in the list, render its content with the same `MarkdownHighlighter` styles (or a read-only attributed string view).

**Files changed:**
| File | Change |
|------|--------|
| `MarkdownTextView.swift` | **New.** `NSViewRepresentable` wrapping `NSTextView`. |
| `MarkdownHighlighter.swift` | **New.** Parses Markdown, returns attributed string styles. |
| `NotePanelContent` (in `NotePanelController.swift`) | Replace `TextEditor` with `MarkdownTextView`. |
| `NoteStore.swift` | `.md` extension for new notes; load both `.txt` and `.md`. |
| `NotesListView.swift` | Use styled text for expanded notes. |
| `Package.swift` or Xcode SPM | Add `apple/swift-markdown` dependency. |

**Risk:** Replacing `TextEditor` with a custom `NSTextView` wrapper is the biggest change. It requires re-implementing focus management, scroll behavior, and the two-way text binding. The existing `findTextView` hack in `NotePanelController` becomes unnecessary since we'll own the `NSTextView` directly.

---

### Feature 2: Text Autocomplete

**Goal:** As the user types, suggest completions from their previous notes. A lightweight, local-only autocomplete that helps with frequently used phrases, names, or terms.

**Approach:**

1. **Build a word/phrase index from saved notes.**
   - File: new `CompletionProvider.swift`
   - On app launch (and after each save), scan all notes and build a frequency-sorted word list.
   - Index multi-word phrases too: extract 2-grams and 3-grams that appear in 2+ notes.
   - Store in memory — for hundreds of notes this is trivially small.

2. **Hook into `NSTextView` completion system.**
   - `NSTextView` has a built-in completion mechanism via `complete(_:)` and `completions(forPartialWordRange:indexOfSelectedItem:)`.
   - Implement `NSTextViewDelegate` method to return matches from our index for the current partial word.
   - Trigger: the native macOS `Esc` or `F5` key triggers the completion popup. But since `Esc` is used to discard notes, we'll use `⌥Esc` (the macOS default text completion shortcut) or a custom trigger.

3. **Alternative: inline ghost text (more modern UX).**
   - Instead of (or in addition to) the dropdown, show a grayed-out completion suggestion inline after the cursor.
   - Press `Tab` to accept, keep typing to dismiss.
   - Requires drawing the suggestion text as a temporary overlay or appending it as a styled (gray, non-editable) range.
   - This is more complex but feels faster — aligns with Swiftly's speed-first ethos.

4. **Trigger heuristics.**
   - Only suggest after 3+ characters typed in the current word (avoids noise on every keystroke).
   - Debounce: 150 ms after the last keystroke before computing suggestions.
   - Don't suggest while the user is actively deleting text.

**Files changed:**
| File | Change |
|------|--------|
| `CompletionProvider.swift` | **New.** Builds and queries the word/phrase index. |
| `MarkdownTextView.swift` | Add completion delegate methods and ghost-text rendering. |
| `NoteStore.swift` | Notify `CompletionProvider` after save/load to rebuild index. |

**Risk:** The ghost-text approach requires careful cursor management — the suggestion text must not interfere with the user's typing or be included when saving. The native `NSTextView` completion popup is simpler but less elegant.

---

### Recommended Implementation Order

1. **Phase 1: `MarkdownTextView` (`NSViewRepresentable` wrapper)** — This is the foundation for both features. Replace `TextEditor` first, verify all existing behavior still works (focus, save, discard, key bindings).
2. **Phase 2: `MarkdownHighlighter`** — Add the parser and inline styling. Start with bold, italic, code, and headings. Add more elements incrementally.
3. **Phase 3: `CompletionProvider` + native completion popup** — Build the word index and wire it to `NSTextView`'s built-in completion. Ship the simple version first.
4. **Phase 4 (optional): Ghost-text autocomplete** — If the popup feels too intrusive for Swiftly's minimal aesthetic, add the inline ghost-text UX.

### Dependencies

- `apple/swift-markdown` — [github.com/apple/swift-markdown](https://github.com/apple/swift-markdown). MIT license, maintained by Apple, pure Swift, no transitive dependencies. Added via Swift Package Manager in Xcode.

### Settings Additions

- `Settings.swift`: Add `markdownHighlighting: Bool` (default `true`) and `autocomplete: Bool` (default `true`) toggles.
- `SettingsView.swift`: Add toggles in the settings UI so users can disable either feature if they prefer the original plain-text experience.

---

## Auto-Update (Sparkle)

Swiftly uses [Sparkle 2.x](https://github.com/sparkle-project/Sparkle) for auto-updates. The app is distributed directly (not via App Store).

### How it works

- `SPUStandardUpdaterController` is initialized in `AppDelegate` at launch with `startingUpdater: true`, which starts automatic background update checks.
- A "Check for Updates..." menu item in the menu bar dropdown triggers a manual check via `updaterController.checkForUpdates(nil)`.
- Sparkle reads `SUFeedURL` from `Info.plist` to find the appcast.
- On first launch, Sparkle prompts the user to opt in to automatic update checks.

### Setup for publishing updates

1. **Set the feed URL** — Replace `YOUR_USERNAME` in `Info.plist`'s `SUFeedURL` with your actual GitHub username:
   ```
   https://raw.githubusercontent.com/YOUR_USERNAME/Swiftly/main/appcast.xml
   ```

2. **Code-sign for distribution** — Sparkle requires the app to be signed with a Developer ID certificate (not just a development cert). Archive the app with `Product → Archive` in Xcode and export with "Developer ID" signing.

3. **Generate an EdDSA keypair** — Sparkle uses EdDSA signatures to verify updates:
   ```bash
   ./bin/generate_keys  # from the Sparkle distribution
   ```
   This creates a keypair. The private key goes in your Keychain. The public key goes in `Info.plist` as `SUPublicEDKey`.

4. **Create the appcast** — After building a signed `.app` or `.dmg`:
   ```bash
   ./bin/generate_appcast /path/to/updates/
   ```
   This produces `appcast.xml`. Commit it to the repo root (or wherever `SUFeedURL` points).

5. **Publish a release** — Upload the signed `.app`/`.dmg` to GitHub Releases. Update the appcast to point to the download URL. Push `appcast.xml` to the repo.
