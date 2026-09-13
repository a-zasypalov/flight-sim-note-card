import Testing
@testable import Pilot_Notes

@Suite("Notes model")
@MainActor
struct NotesModelTests {
    @Test("Creates a named note with its layout identity")
    func createsNote() throws {
        let model = NotesModel()

        let id = try #require(model.createNote(named: "EDDF to EDDM", layout: .placeholder))
        let note = try #require(model.note(id: id))

        #expect(note.name == "EDDF to EDDM")
        #expect(note.layoutID == NoteLayout.placeholder.id)
        #expect(note.layoutRevision == NoteLayout.placeholder.revision)
    }

    @Test("Rejects a blank name")
    func rejectsBlankName() {
        let model = NotesModel()

        #expect(model.createNote(named: " \n ", layout: .placeholder) == nil)
        #expect(model.notes.isEmpty)
    }

    @Test("Trims names and keeps duplicate notes distinct")
    func trimsDuplicateNames() throws {
        let model = NotesModel()

        let firstID = try #require(model.createNote(named: "  Flight  ", layout: .placeholder))
        let secondID = try #require(model.createNote(named: "Flight", layout: .placeholder))

        #expect(firstID != secondID)
        #expect(model.notes.map(\.name) == ["Flight", "Flight"])
    }
}
