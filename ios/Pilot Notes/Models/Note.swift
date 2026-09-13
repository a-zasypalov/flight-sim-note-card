import Foundation

nonisolated struct Note: Identifiable, Hashable, Sendable {
    let id: UUID
    let layoutID: NoteLayout.ID
    let layoutRevision: Int
    var content: NoteContent

    init(
        id: UUID = UUID(),
        layout: NoteLayout,
        content: NoteContent = NoteContent()
    ) {
        self.id = id
        layoutID = layout.id
        layoutRevision = layout.revision
        self.content = content
    }

    init(
        id: UUID,
        layoutID: NoteLayout.ID,
        layoutRevision: Int,
        content: NoteContent
    ) {
        self.id = id
        self.layoutID = layoutID
        self.layoutRevision = layoutRevision
        self.content = content
    }
}

nonisolated struct NoteContent: Hashable, Sendable {
    var fieldValues: [NoteLayoutField.ID: String] = [:]
    var writingRegionValues: [NoteLayoutRegion.ID: String] = [:]
    var logoData: Data?

    mutating func setField(_ id: NoteLayoutField.ID, to value: String) {
        fieldValues[id] = value.isEmpty ? nil : value
    }

    mutating func setWritingRegion(_ id: NoteLayoutRegion.ID, to value: String) {
        writingRegionValues[id] = value.isEmpty ? nil : value
    }
}
