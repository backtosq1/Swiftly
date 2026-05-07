import Foundation

struct Note: Identifiable {
    let id: String
    let date: Date
    let content: String

    var preview: String {
        let firstLine = content.prefix(while: { $0 != "\n" })
        return String(firstLine.prefix(80))
    }
}

@Observable
final class NoteStore {
    private(set) var notes: [Note] = []

    private let fileManager = FileManager.default
    let completionProvider = CompletionProvider()

    var storageDirectory: URL {
        Settings.shared.storageDirectory
    }

    var noteCount: Int { notes.count }

    init() {
        ensureDirectoryExists()
        loadNotes()
    }

    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
    }

    func updateStorageDirectory(_ url: URL) {
        Settings.shared.storageDirectory = url
        ensureDirectoryExists()
        loadNotes()
    }

    func save(_ content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        ensureDirectoryExists()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        var filename = formatter.string(from: Date()) + ".md"
        var fileURL = storageDirectory.appendingPathComponent(filename)

        var counter = 1
        while fileManager.fileExists(atPath: fileURL.path) {
            filename = formatter.string(from: Date()) + "-\(counter).md"
            fileURL = storageDirectory.appendingPathComponent(filename)
            counter += 1
        }

        try? trimmed.write(to: fileURL, atomically: true, encoding: .utf8)
        loadNotes()
    }

    func delete(_ note: Note) {
        let fileURL = storageDirectory.appendingPathComponent(note.id)
        try? fileManager.removeItem(at: fileURL)
        loadNotes()
    }

    func loadNotes() {
        guard let files = try? fileManager.contentsOfDirectory(atPath: storageDirectory.path) else {
            notes = []
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        notes = files
            .filter { $0.hasSuffix(".txt") || $0.hasSuffix(".md") }
            .compactMap { filename -> Note? in
                let fileURL = storageDirectory.appendingPathComponent(filename)
                guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }

                let datePart = (filename as NSString).deletingPathExtension
                    .replacingOccurrences(of: #"-\d+$"#, with: "", options: .regularExpression)
                let date = formatter.date(from: datePart) ?? Date.distantPast

                return Note(id: filename, date: date, content: content)
            }
            .sorted { $0.date > $1.date }
        completionProvider.rebuild(from: notes)
    }
}
