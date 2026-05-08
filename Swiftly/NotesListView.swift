import SwiftUI
import AppKit

// MARK: - Notes List View (SwiftUI container)

/// Top-level view for the notes browser window.
/// Combines a SwiftUI search bar with a native NSTableView for reliable keyboard focus.
struct NotesListView: View {
    var noteStore: NoteStore
    @State private var searchText = ""
    @State private var selectedNoteID: String?
    @State private var expandedNoteID: String?
    @State private var noteToDelete: Note?
    @FocusState private var searchFocused: Bool

    /// Filter notes by search text using case-insensitive substring match.
    private var filteredNotes: [Note] {
        if searchText.isEmpty { return noteStore.notes }
        return noteStore.notes.filter {
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            hintsBar

            if filteredNotes.isEmpty {
                emptyState
            } else {
                NotesTableView(
                    notes: filteredNotes,
                    selectedNoteID: $selectedNoteID,
                    expandedNoteID: $expandedNoteID,
                    onDelete: { note in noteToDelete = note },
                    onCopy: { note in
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(note.content, forType: .string)
                    }
                )
            }
        }
        .frame(minWidth: 450, minHeight: 300)
        .background(.background)
        .alert("Delete Note?", isPresented: .init(
            get: { noteToDelete != nil },
            set: { if !$0 { noteToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let note = noteToDelete {
                    let idx = filteredNotes.firstIndex(where: { $0.id == note.id })
                    noteStore.delete(note)
                    if expandedNoteID == note.id { expandedNoteID = nil }
                    // Auto-select the next note after deletion
                    if let idx {
                        let remaining = filteredNotes.filter { $0.id != note.id }
                        if !remaining.isEmpty {
                            let newIdx = min(idx, remaining.count - 1)
                            selectedNoteID = remaining[newIdx].id
                        } else {
                            selectedNoteID = nil
                        }
                    }
                }
                noteToDelete = nil
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) { noteToDelete = nil }
        } message: {
            Text("This note will be permanently deleted.")
        }
        .onAppear {
            noteStore.loadNotes()
            if selectedNoteID == nil, let first = filteredNotes.first {
                selectedNoteID = first.id
            }
            searchFocused = true
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search \(noteStore.noteCount) notes...", text: $searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Keyboard hints bar

    private var hintsBar: some View {
        HStack(spacing: 16) {
            hintLabel("Tab", "navigate")
            hintLabel("↑↓", "select")
            hintLabel("Enter", "expand")
            hintLabel("Delete", "remove")
            hintLabel("Esc", "collapse")
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    /// Renders a single keyboard hint: key badge + action label.
    private func hintLabel(_ key: String, _ action: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(action)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "note.text" : "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty ? "No notes yet" : "No matching notes")
                .font(.headline)
                .foregroundStyle(.secondary)
            if searchText.isEmpty {
                Text("Press \(Settings.shared.hotkey.displayString) to capture a note")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Native NSTableView wrapper

/// Wraps an AppKit NSTableView in SwiftUI via NSViewRepresentable.
/// Using a native table view gives us reliable first-responder control
/// and smooth row-height animations that SwiftUI's List doesn't support well.
struct NotesTableView: NSViewRepresentable {
    let notes: [Note]
    @Binding var selectedNoteID: String?
    @Binding var expandedNoteID: String?
    var onDelete: (Note) -> Void
    var onCopy: (Note) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        let tableView = NotesNSTableView()
        tableView.style = .inset
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.rowSizeStyle = .custom
        tableView.selectionHighlightStyle = .regular
        tableView.allowsMultipleSelection = false
        tableView.headerView = nil
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.gridStyleMask = []

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("note"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        context.coordinator.tableView = tableView

        tableView.menu = context.coordinator.makeContextMenu()

        scrollView.documentView = tableView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        guard let tableView = coordinator.tableView else { return }

        tableView.reloadData()

        // Sync SwiftUI selection state → NSTableView selection
        if let id = selectedNoteID, let idx = notes.firstIndex(where: { $0.id == id }) {
            let indexSet = IndexSet(integer: idx)
            if tableView.selectedRowIndexes != indexSet {
                tableView.selectRowIndexes(indexSet, byExtendingSelection: false)
                tableView.scrollRowToVisible(idx)
            }
        }
    }

    // MARK: - Coordinator (NSTableView delegate + data source)

    final class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var parent: NotesTableView
        weak var tableView: NSTableView?

        private let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            return f
        }()

        init(parent: NotesTableView) {
            self.parent = parent
        }

        // MARK: Data source

        func numberOfRows(in tableView: NSTableView) -> Int {
            parent.notes.count
        }

        // MARK: Cell rendering

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let note = parent.notes[row]
            let isExpanded = parent.expandedNoteID == note.id

            let cellID = NSUserInterfaceItemIdentifier("NoteCell")
            let cell: NSTableCellView
            if let reused = tableView.makeView(withIdentifier: cellID, owner: nil) as? NSTableCellView {
                cell = reused
                cell.subviews.forEach { $0.removeFromSuperview() }
            } else {
                cell = NSTableCellView()
                cell.identifier = cellID
            }

            let stack = NSStackView()
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 4
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.edgeInsets = NSEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)

            // Date row
            let dateLabel = NSTextField(labelWithString: dateFormatter.string(from: note.date))
            dateLabel.font = .systemFont(ofSize: 11)
            dateLabel.textColor = .secondaryLabelColor

            // Content: full text when expanded, single-line preview otherwise
            let contentLabel = NSTextField(wrappingLabelWithString: note.preview)
            contentLabel.maximumNumberOfLines = isExpanded ? 0 : 1
            contentLabel.lineBreakMode = isExpanded ? .byWordWrapping : .byTruncatingTail
            if isExpanded {
                contentLabel.attributedStringValue = MarkdownHighlighter.attributedString(from: note.content)
                contentLabel.isSelectable = true
            } else {
                contentLabel.font = MarkdownHighlighter.baseFont
                contentLabel.textColor = .labelColor
            }

            stack.addArrangedSubview(dateLabel)
            stack.addArrangedSubview(contentLabel)

            cell.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: cell.topAnchor),
                stack.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
                stack.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            ])

            return cell
        }

        // MARK: Row height (animated via NSTableView.noteHeightOfRows)

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            let note = parent.notes[row]
            if parent.expandedNoteID == note.id {
                let lineCount = max(note.content.components(separatedBy: .newlines).count, 2)
                return CGFloat(36 + min(lineCount, 20) * 17)
            }
            return 52
        }

        // MARK: Selection sync → SwiftUI

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView = notification.object as? NSTableView else { return }
            let row = tableView.selectedRow
            if row >= 0 && row < parent.notes.count {
                let note = parent.notes[row]
                if parent.selectedNoteID != note.id {
                    parent.selectedNoteID = note.id
                    // Collapse any expanded note when selection changes
                    if parent.expandedNoteID != nil {
                        parent.expandedNoteID = nil
                        animateRowHeights(tableView)
                    }
                }
            } else {
                parent.selectedNoteID = nil
            }
        }

        // MARK: Keyboard handling

        /// Called by NotesNSTableView.keyDown — returns true if the event was handled.
        func tableView(_ tableView: NSTableView, keyDown event: NSEvent) -> Bool {
            let row = tableView.selectedRow
            guard row >= 0 && row < parent.notes.count else { return false }
            let note = parent.notes[row]

            switch Int(event.keyCode) {
            case 0x24: // Return — toggle expand/collapse with animation
                if parent.expandedNoteID == note.id {
                    parent.expandedNoteID = nil
                } else {
                    parent.expandedNoteID = note.id
                }
                animateRowHeights(tableView)
                tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0))
                return true

            case 0x33, 0x75: // Backspace / Forward Delete — trigger delete confirmation
                parent.onDelete(note)
                return true

            case 0x35: // Escape — collapse expanded note, or deselect
                if parent.expandedNoteID != nil {
                    parent.expandedNoteID = nil
                    animateRowHeights(tableView)
                    tableView.reloadData()
                } else {
                    parent.selectedNoteID = nil
                    tableView.deselectAll(nil)
                }
                return true

            default:
                return false
            }
        }

        // MARK: Animated row height change

        /// Wraps noteHeightOfRows in an NSAnimationContext for a smooth expand/collapse transition.
        private func animateRowHeights(_ tableView: NSTableView) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.allowsImplicitAnimation = true
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                tableView.noteHeightOfRows(withIndexesChanged: IndexSet(0..<parent.notes.count))
            }
        }

        // MARK: Context menu

        func makeContextMenu() -> NSMenu {
            let menu = NSMenu()

            let copyItem = NSMenuItem(title: "Copy", action: #selector(copyNote(_:)), keyEquivalent: "c")
            copyItem.target = self
            menu.addItem(copyItem)

            menu.addItem(.separator())

            let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteNote(_:)), keyEquivalent: "")
            deleteItem.target = self
            menu.addItem(deleteItem)

            return menu
        }

        @objc func copyNote(_ sender: Any?) {
            guard let tableView, tableView.clickedRow >= 0 else { return }
            parent.onCopy(parent.notes[tableView.clickedRow])
        }

        @objc func deleteNote(_ sender: Any?) {
            guard let tableView, tableView.clickedRow >= 0 else { return }
            parent.onDelete(parent.notes[tableView.clickedRow])
        }
    }
}

// MARK: - NSTableView subclass for key event forwarding

/// Overrides keyDown to route keyboard events through the Coordinator
/// before falling back to default NSTableView behavior (arrow key navigation).
final class NotesNSTableView: NSTableView {
    override func keyDown(with event: NSEvent) {
        if let coordinator = delegate as? NotesTableView.Coordinator,
           coordinator.tableView(self, keyDown: event) {
            return
        }
        super.keyDown(with: event)
    }
}
