import Foundation

final class CompletionProvider {
    private var entries: [(word: String, count: Int)] = []

    func rebuild(from notes: [Note]) {
        var freq: [String: Int] = [:]
        for note in notes {
            for word in words(in: note.content) {
                let lower = word.lowercased()
                if lower.count >= 3 {
                    freq[lower, default: 0] += 1
                }
            }
        }
        entries = freq.map { (word: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    func complete(prefix: String) -> String? {
        let lower = prefix.lowercased()
        guard lower.count >= 3 else { return nil }
        for entry in entries {
            if entry.word.hasPrefix(lower), entry.word.count > lower.count + 1 {
                return String(entry.word.dropFirst(lower.count))
            }
        }
        return nil
    }

    private func words(in text: String) -> [String] {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}
