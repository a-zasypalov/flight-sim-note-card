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

struct NoteContent: Hashable, Sendable {}

struct NoteLayout: Identifiable, Hashable, Sendable {
    let id: String
    let revision: Int
    let name: String

    static let placeholder = NoteLayout(
        id: "placeholder",
        revision: 1,
        name: "Placeholder layout"
    )

    static let available = [placeholder]
}
