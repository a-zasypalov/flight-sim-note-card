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

    func setField(_ fieldID: NoteLayoutField.ID, to value: String, in noteID: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }

        if value.isEmpty {
            notes[index].content.fieldValues.removeValue(forKey: fieldID)
        } else {
            notes[index].content.fieldValues[fieldID] = value
        }
    }

    func setLogo(_ data: Data?, in noteID: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[index].content.logoData = data
    }
}
