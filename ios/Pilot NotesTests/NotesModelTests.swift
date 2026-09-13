import Testing
@testable import Pilot_Notes

@Suite("Notes model")
@MainActor
struct NotesModelTests {
    @Test("Creates a named note with its layout identity")
    func createsNote() throws {
        let model = NotesModel()

        let id = try #require(model.createNote(named: "EDDF to EDDM", layout: .vatsimFlightCard))
        let note = try #require(model.note(id: id))

        #expect(note.name == "EDDF to EDDM")
        #expect(note.layoutID == NoteLayout.vatsimFlightCard.id)
        #expect(note.layoutRevision == NoteLayout.vatsimFlightCard.revision)
    }

    @Test("Rejects a blank name")
    func rejectsBlankName() {
        let model = NotesModel()

        #expect(model.createNote(named: " \n ", layout: .vatsimFlightCard) == nil)
        #expect(model.notes.isEmpty)
    }

    @Test("Trims names and keeps duplicate notes distinct")
    func trimsDuplicateNames() throws {
        let model = NotesModel()

        let firstID = try #require(model.createNote(named: "  Flight  ", layout: .vatsimFlightCard))
        let secondID = try #require(model.createNote(named: "Flight", layout: .vatsimFlightCard))

        #expect(firstID != secondID)
        #expect(model.notes.map(\.name) == ["Flight", "Flight"])
    }

    @Test("Loads the complete flight card layout")
    func loadsFlightCardLayout() {
        let layout = NoteLayout.vatsimFlightCard

        #expect(layout.pageSize == LayoutSize(width: 148, height: 210))
        #expect(layout.cardFrame == LayoutRect(x: 5, y: 5, width: 138, height: 200))
        #expect(layout.fields.count == 30)
        #expect(layout.writingRegions.map(\.id) == ["pushbackTaxi", "inFlight", "arrivalTaxi"])
        #expect(layout.pdfURL != nil)
    }
}
