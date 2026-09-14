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
        note.content.writingRegionValues["inFlight"] = "KERAX\n\nNORKU"

        let document = try NotePDFExporter.document(for: note, layout: .vatsimFlightCard)
        let pdf = try #require(PDFDocument(data: document.data))
        let page = try #require(pdf.page(at: 0))
        let pageText = try #require(page.string) as NSString
        let firstLine = try #require(page.selection(for: pageText.range(of: "KERAX")))
        let thirdLine = try #require(page.selection(for: pageText.range(of: "NORKU")))
        let expectedSpacing = 2 * 6 * page.bounds(for: .mediaBox).height
            / CGFloat(NoteLayout.vatsimFlightCard.pageSize.height)

        #expect(pdf.pageCount == 1)
        #expect(pageText.contains("DLH123"))
        #expect(abs(abs(firstLine.bounds(for: page).midY - thirdLine.bounds(for: page).midY) - expectedSpacing) < 0.5)
    }

    @Test("Writing regions enforce their ruled row capacity")
    func writingRegionCapacity() throws {
        let capacities = ["pushbackTaxi": 2, "inFlight": 10, "arrivalTaxi": 2]

        for region in NoteLayout.vatsimFlightCard.writingRegions {
            let textView = try writingTextView(for: region)
            let allowed = Array(repeating: "A", count: try #require(capacities[region.id]))
                .joined(separator: "\n")

            #expect(fitting(allowed, in: textView) == allowed)
            #expect(fitting(allowed + "\n", in: textView) == allowed)
            #expect(fitting(allowed + "\nB", in: textView) == allowed)
        }
    }

    @Test("Writing regions truncate wrapped paste at character boundaries")
    func writingRegionPasteLimit() throws {
        let textView = try writingTextView(for: try region("pushbackTaxi"))
        let pasted = String(repeating: "🙂", count: 1_000)
        let accepted = try #require(fitting(pasted, in: textView))

        #expect(!accepted.isEmpty)
        #expect(accepted.count < pasted.count)
        #expect(accepted.allSatisfy { $0 == "🙂" })

        setText(accepted, in: textView)
        #expect(fitting("🙂", in: textView, at: (accepted as NSString).length) == "")
    }

    @Test("Writing region replacement preserves existing suffix text")
    func writingRegionReplacement() throws {
        let textView = try writingTextView(for: try region("pushbackTaxi"), text: "HEAD\nTAIL")
        let range = (textView.text as NSString).range(of: "HEAD")
        let pasted = String(repeating: "X", count: 1_000)
        let accepted = try #require(fitting(pasted, in: textView, replacing: range))
        let result = (textView.text as NSString).replacingCharacters(in: range, with: accepted)

        #expect(accepted.count < pasted.count)
        #expect(result.hasSuffix("TAIL"))
        #expect(fitting("", in: textView, replacing: range) == "")
    }

    private func roundTrip(_ document: PilotNoteDocument) throws -> PilotNoteDocument {
        try PilotNoteDocument(fileWrapper: document.fileWrapper())
    }

    private func package(manifest: Data) -> FileWrapper {
        FileWrapper(directoryWithFileWrappers: [
            "manifest.json": FileWrapper(regularFileWithContents: manifest)
        ])
    }

    private func region(_ id: String) throws -> NoteLayoutRegion {
        try #require(NoteLayout.vatsimFlightCard.writingRegions.first { $0.id == id })
    }

    private func writingTextView(
        for region: NoteLayoutRegion,
        text: String = ""
    ) throws -> UITextView {
        let layout = NoteLayout.vatsimFlightCard
        let pdf = try #require(layout.pdfURL.flatMap(PDFDocument.init(url:)))
        let page = try #require(pdf.page(at: 0))
        let pageBounds = page.bounds(for: .mediaBox)
        let scale = pageBounds.height / CGFloat(layout.pageSize.height)
        let font = UIFont(name: "Courier", size: CGFloat(region.fontSize ?? 8.5))
            ?? UIFont.monospacedSystemFont(ofSize: 8.5, weight: .regular)
        let lineHeight = CGFloat(region.baselineSpacing) * scale
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph
        ]
        let textView = UITextView(frame: layout.pageRect(for: region.frame, in: pageBounds))
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(
            top: max(0, CGFloat(region.firstBaselineOffset) * scale - lineHeight - font.descender),
            left: scale,
            bottom: 0,
            right: scale
        )
        textView.textContainer.lineFragmentPadding = 0
        textView.attributedText = NSAttributedString(string: text, attributes: attributes)
        textView.typingAttributes = attributes
        return textView
    }

    private func fitting(
        _ replacement: String,
        in textView: UITextView,
        at location: Int = 0,
        replacing range: NSRange? = nil
    ) -> String? {
        WritingRegionTextLimiter.fittingReplacement(
            replacement,
            in: textView,
            replacing: range ?? NSRange(location: location, length: 0)
        )
    }

    private func setText(_ text: String, in textView: UITextView) {
        textView.attributedText = NSAttributedString(
            string: text,
            attributes: textView.typingAttributes
        )
    }
}
