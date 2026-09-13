import Foundation

struct Note: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    let layoutID: NoteLayout.ID
    let layoutRevision: Int
    var content: NoteContent

    init(
        id: UUID = UUID(),
        name: String,
        layout: NoteLayout,
        content: NoteContent = NoteContent()
    ) {
        self.id = id
        self.name = name
        layoutID = layout.id
        layoutRevision = layout.revision
        self.content = content
    }
}

struct NoteContent: Hashable, Sendable {
    var fieldValues: [NoteLayoutField.ID: String] = [:]
    var logoData: Data?
}
