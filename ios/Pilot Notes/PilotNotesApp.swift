//
//  Pilot_NotesApp.swift
//  Pilot Notes
//
//  Created by Artem Zasypalov on 13.09.26.
//

import SwiftUI

@main
struct PilotNotesApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: PilotNoteDocument(layout: .vatsimFlightCard)) { configuration in
            NoteView(document: configuration.$document)
        }

        DocumentGroupLaunchScene("Pilot Notes", backgroundStyle: PNColors.launchBackground) {
            NewPilotNoteButton()
        }
    }
}
