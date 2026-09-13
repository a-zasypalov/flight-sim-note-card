import PDFKit
import Testing
@testable import Pilot_Notes

@Suite("Pilot Note documents")
@MainActor
struct PilotNoteDocumentTests {
    @Test("Round-trips empty content and layout identity")
    func roundTripsEmptyDocument() throws {
        let original = PilotNoteDocument(layout: .vatsimFlightCard)
        let restored = try roundTrip(original)

        #expect(restored.note.id == original.note.id)
        #expect(restored.note.layoutID == NoteLayout.vatsimFlightCard.id)
        #expect(restored.note.layoutRevision == NoteLayout.vatsimFlightCard.revision)
        #expect(restored.note.content == NoteContent())
    }

    @Test("Round-trips fields, multiline writing, and logo data")
    func roundTripsPopulatedDocument() throws {
        var original = PilotNoteDocument(layout: .vatsimFlightCard)
        original.note.content.fieldValues["callsign"] = "DLH123"
        original.note.content.writingRegionValues["inFlight"] = "Direct KERAX\nClimb FL350"
        original.note.content.logoData = Data([0x89, 0x50, 0x4E, 0x47])

        let restored = try roundTrip(original)

        #expect(restored.note.content == original.note.content)
    }

    @Test("Stores content in a package without a filename")
    func packageContents() throws {
        var document = PilotNoteDocument(layout: .vatsimFlightCard)
        document.note.content.logoData = Data([1, 2, 3])

        let wrapper = try document.fileWrapper()
        let children = try #require(wrapper.fileWrappers)
        let manifestData = try #require(children["manifest.json"]?.regularFileContents)
        let manifest = try #require(
            JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
        )

        #expect(Set(children.keys) == ["manifest.json", "logo.png"])
        #expect(manifest["name"] == nil)
        #expect(manifest["formatVersion"] as? Int == 1)
    }

    @Test("Rejects a package without a manifest")
    func rejectsMissingManifest() {
        do {
            _ = try PilotNoteDocument(fileWrapper: FileWrapper(directoryWithFileWrappers: [:]))
            Issue.record("Expected the package to be rejected")
        } catch PilotNoteDocumentError.invalidPackage {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Rejects corrupt JSON")
    func rejectsCorruptManifest() {
        let wrapper = package(manifest: Data("not json".utf8))

        do {
            _ = try PilotNoteDocument(fileWrapper: wrapper)
            Issue.record("Expected the manifest to be rejected")
        } catch PilotNoteDocumentError.invalidPackage {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Rejects newer format versions")
    func rejectsUnsupportedVersion() throws {
        let manifest: [String: Any] = [
            "formatVersion": 2,
            "id": UUID().uuidString,
            "layoutID": NoteLayout.vatsimFlightCard.id,
            "layoutRevision": NoteLayout.vatsimFlightCard.revision,
            "fieldValues": [:],
            "writingRegionValues": [:]
        ]

        do {
            _ = try PilotNoteDocument(
                fileWrapper: package(manifest: JSONSerialization.data(withJSONObject: manifest))
            )
            Issue.record("Expected the format version to be rejected")
        } catch PilotNoteDocumentError.unsupportedVersion(let version) {
            #expect(version == 2)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Loads the complete flight card layout")
    func loadsFlightCardLayout() {
        let layout = NoteLayout.vatsimFlightCard

        #expect(layout.pageSize == LayoutSize(width: 148, height: 210))
        #expect(layout.cardFrame == LayoutRect(x: 5, y: 5, width: 138, height: 200))
        #expect(layout.logoFrame == LayoutRect(x: 5.5, y: 188.5, width: 38, height: 9))
        #expect(layout.fields.count == 30)
        #expect(layout.writingRegions.map(\.id) == ["pushbackTaxi", "inFlight", "arrivalTaxi"])
        #expect(layout.writingRegions.map(\.baselineSpacing) == [6, 6, 6])
        #expect(layout.pdfURL != nil)
    }

    @Test("Exports note values to one PDF page")
    func exportsPDF() throws {
        var note = Note(layout: .vatsimFlightCard)
        note.content.fieldValues["callsign"] = "DLH123"
        note.content.writingRegionValues["inFlight"] = "Direct KERAX"

        let document = try NotePDFExporter.document(for: note, layout: .vatsimFlightCard)
        let pdf = try #require(PDFDocument(data: document.data))

        #expect(pdf.pageCount == 1)
        #expect(pdf.page(at: 0)?.string?.contains("DLH123") == true)
        #expect(pdf.page(at: 0)?.string?.contains("Direct KERAX") == true)
    }

    private func roundTrip(_ document: PilotNoteDocument) throws -> PilotNoteDocument {
        try PilotNoteDocument(fileWrapper: document.fileWrapper())
    }

    private func package(manifest: Data) -> FileWrapper {
        FileWrapper(directoryWithFileWrappers: [
            "manifest.json": FileWrapper(regularFileWithContents: manifest)
        ])
    }
}
