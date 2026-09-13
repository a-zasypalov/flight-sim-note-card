//
//  Pilot_NotesApp.swift
//  Pilot Notes
//
//  Created by Artem Zasypalov on 13.09.26.
//

import SwiftUI

@main
struct PilotNotesApp: App {
    @State private var notesModel = NotesModel()

    var body: some Scene {
        WindowGroup {
            NotesListView()
                .environment(notesModel)
        }
    }
}
