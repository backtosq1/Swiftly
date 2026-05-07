import SwiftUI

struct NotesListView: View {
    var noteStore: NoteStore
    @State private var searchText = ""
    @State private var selectedNoteID: String?
    @State private var noteToDelete: Note?

    private var filteredNotes: [Note] {
        if searchText.isEmpty { return noteStore.notes }
        return noteStore.notes.filter {
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if filteredNotes.isEmpty {
                emptyState
            } else {
                notesList
            }
        }
        .frame(minWidth: 320, minHeight: 300)
        .background(.background)
        .alert("Delete Note?", isPresented: .init(
            get: { noteToDelete != nil },
            set: { if !$0 { noteToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { noteToDelete = nil }
            Button("Delete", role: .destructive) {
                if let note = noteToDelete {
                    noteStore.delete(note)
                    if selectedNoteID == note.id { selectedNoteID = nil }
                }
                noteToDelete = nil
            }
        } message: {
            Text("This note will be permanently deleted.")
        }
        .onAppear { noteStore.loadNotes() }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search \(noteStore.noteCount) notes...", text: $searchText)
                .textFieldStyle(.plain)
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
        .padding(12)
    }

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

    private var notesList: some View {
        List(selection: $selectedNoteID) {
            ForEach(filteredNotes) { note in
                noteRow(note)
                    .tag(note.id)
            }
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private func noteRow(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(note.date, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if selectedNoteID == note.id {
                    Button(role: .destructive) {
                        noteToDelete = note
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            if selectedNoteID == note.id {
                Text(note.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(note.preview)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(note.content, forType: .string)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive) {
                noteToDelete = note
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
