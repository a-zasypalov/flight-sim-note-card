import SwiftUI

struct NoteView: View {
    let note: Note

    private var layout: NoteLayout? {
        NoteLayout.available.first {
            $0.id == note.layoutID && $0.revision == note.layoutRevision
        }
    }

    var body: some View {
        Group {
            if let layout, let pdfURL = layout.pdfURL {
                NoteTemplateView(pdfURL: pdfURL)
            } else {
                ContentUnavailableView(
                    "Layout Unavailable",
                    systemImage: "doc.badge.ellipsis",
                    description: Text("This note's layout could not be loaded.")
                )
            }
        }
        .navigationTitle(note.name)
    }
}

#Preview {
    NavigationStack {
        NoteView(note: Note(name: "EDDF to EDDM", layout: .vatsimFlightCard))
    }
}
