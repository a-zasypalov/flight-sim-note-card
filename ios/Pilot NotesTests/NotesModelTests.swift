import PDFKit
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
        #expect(layout.logoFrame == LayoutRect(x: 5.5, y: 188.5, width: 38, height: 9))
        #expect(layout.fields.count == 30)
        #expect(layout.writingRegions.map(\.id) == ["pushbackTaxi", "inFlight", "arrivalTaxi"])
        #expect(layout.pdfURL != nil)
    }

    @Test("Updates editable note content")
    func updatesContent() throws {
        let model = NotesModel()
        let id = try #require(model.createNote(named: "Flight", layout: .vatsimFlightCard))

        model.setField("callsign", to: "DLH123", in: id)
        model.setLogo(Data([1, 2, 3]), in: id)

        let note = try #require(model.note(id: id))
        #expect(note.content.fieldValues["callsign"] == "DLH123")
        #expect(note.content.logoData == Data([1, 2, 3]))
    }

    @Test("Exports note values to one PDF page")
    func exportsPDF() throws {
        var note = Note(name: "Flight", layout: .vatsimFlightCard)
        note.content.fieldValues["callsign"] = "DLH123"

        let document = try NotePDFExporter.document(for: note, layout: .vatsimFlightCard)
        let pdf = try #require(PDFDocument(data: document.data))

        #expect(pdf.pageCount == 1)
        #expect(pdf.page(at: 0)?.string?.contains("DLH123") == true)
    }
}
