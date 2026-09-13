import SwiftUI

struct NoteView: View {
    let note: Note

    var body: some View {
        ContentUnavailableView(
            "Note Editor",
            systemImage: "pencil.and.scribble",
            description: Text("The layout editor will appear here.")
        )
        .navigationTitle(note.name)
    }
}

#Preview {
    NavigationStack {
        NoteView(note: Note(name: "EDDF to EDDM", layout: .placeholder))
    }
}
