import Foundation
import Observation

@Observable
@MainActor
final class NotesModel {
    private(set) var notes: [Note]

    init(notes: [Note] = []) {
        self.notes = notes
    }

    @discardableResult
    func createNote(named name: String, layout: NoteLayout) -> Note.ID? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let note = Note(name: name, layout: layout)
        notes.insert(note, at: 0)
        return note.id
    }

    func note(id: Note.ID?) -> Note? {
        notes.first { $0.id == id }
    }
}
