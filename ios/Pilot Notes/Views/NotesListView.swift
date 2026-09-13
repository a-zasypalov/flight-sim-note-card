import SwiftUI

struct NotesListView: View {
    @Environment(NotesModel.self) private var notesModel
    @State private var selectedNoteID: Note.ID?
    @State private var isChoosingLayout = false
    @State private var preferredCompactColumn = NavigationSplitViewColumn.sidebar

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $preferredCompactColumn) {
            List(notesModel.notes, selection: $selectedNoteID) { note in
                NavigationLink(value: note.id) {
                    Text(note.name)
                }
            }
            .overlay {
                if notesModel.notes.isEmpty {
                    ContentUnavailableView(
                        "No Notes",
                        systemImage: "note.text",
                        description: Text("Create a note to get started.")
                    )
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    isChoosingLayout = true
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "document.badge.plus")
                            .font(.title2)
                            .padding(6)

                        Text("New Note")
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                }
                .buttonStyle(.glass(.clear.tint(Color(red: 53.0 / 255, green: 122.0 / 255, blue: 205.0 / 255))))
                .buttonBorderShape(.capsule)
                .accessibilityLabel("Add note")
                .padding()
            }
            .navigationTitle("Pilot Notes")
        } detail: {
            if let note = notesModel.note(id: selectedNoteID) {
                NoteView(note: note)
            } else {
                ContentUnavailableView(
                    "No Note Selected",
                    systemImage: "note.text",
                    description: Text("Select a note from the list.")
                )
            }
        }
        .sheet(isPresented: $isChoosingLayout) {
            ChooseLayoutView { name, layout in
                selectedNoteID = notesModel.createNote(named: name, layout: layout)
                preferredCompactColumn = .detail
            }
        }
    }
}

#Preview("Empty") {
    NotesListView()
        .environment(NotesModel())
}

#Preview("Notes") {
    NotesListView()
        .environment(NotesModel(notes: [
            Note(name: "EDDL to EDDM", layout: .placeholder),
            Note(name: "Evening flight", layout: .placeholder)
        ]))
}
