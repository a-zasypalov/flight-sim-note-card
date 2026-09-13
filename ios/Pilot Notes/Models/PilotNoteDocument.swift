import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    nonisolated static let pilotNote = UTType(
        exportedAs: "com.gaoyun.pilot-notes.document",
        conformingTo: .package
    )
}

nonisolated struct PilotNoteDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.pilotNote]

    var note: Note

    init(layout: NoteLayout) {
        note = Note(layout: layout)
    }

    init(configuration: ReadConfiguration) throws {
        try self.init(fileWrapper: configuration.file)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try fileWrapper()
    }

    init(fileWrapper: FileWrapper) throws {
        guard
            fileWrapper.isDirectory,
            let children = fileWrapper.fileWrappers,
            let manifestData = children[File.manifest]?.regularFileContents
        else {
            throw PilotNoteDocumentError.invalidPackage
        }

        let manifest: Manifest
        do {
            manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
        } catch {
            throw PilotNoteDocumentError.invalidPackage
        }

        guard manifest.formatVersion == Manifest.currentFormatVersion else {
            throw PilotNoteDocumentError.unsupportedVersion(manifest.formatVersion)
        }

        note = Note(
            id: manifest.id,
            layoutID: manifest.layoutID,
            layoutRevision: manifest.layoutRevision,
            content: NoteContent(
                fieldValues: manifest.fieldValues,
                writingRegionValues: manifest.writingRegionValues,
                logoData: children[File.logo]?.regularFileContents
            )
        )
    }

    func fileWrapper() throws -> FileWrapper {
        let manifest = Manifest(note: note)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        var children = [
            File.manifest: FileWrapper(
                regularFileWithContents: try encoder.encode(manifest)
            )
        ]
        if let logoData = note.content.logoData {
            children[File.logo] = FileWrapper(regularFileWithContents: logoData)
        }
        return FileWrapper(directoryWithFileWrappers: children)
    }
}

private extension PilotNoteDocument {
    nonisolated enum File {
        static let manifest = "manifest.json"
        static let logo = "logo.png"
    }

    nonisolated struct Manifest: Codable {
        static let currentFormatVersion = 1

        let formatVersion: Int
        let id: UUID
        let layoutID: NoteLayout.ID
        let layoutRevision: Int
        let fieldValues: [NoteLayoutField.ID: String]
        let writingRegionValues: [NoteLayoutRegion.ID: String]

        init(note: Note) {
            formatVersion = Self.currentFormatVersion
            id = note.id
            layoutID = note.layoutID
            layoutRevision = note.layoutRevision
            fieldValues = note.content.fieldValues
            writingRegionValues = note.content.writingRegionValues
        }
    }
}

nonisolated enum PilotNoteDocumentError: LocalizedError {
    case invalidPackage
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .invalidPackage:
            "This Pilot Note file is damaged or incomplete."
        case .unsupportedVersion(let version):
            "This Pilot Note uses unsupported format version \(version)."
        }
    }
}
