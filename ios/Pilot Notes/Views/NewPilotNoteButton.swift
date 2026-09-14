//
//  NewPilotNoteButton.swift
//  Pilot Notes
//
//  Created by Artem Zasypalov on 14.09.26.
//

import SwiftUI

struct NewPilotNoteButton: View {
    @State private var continuation: CheckedContinuation<PilotNoteDocument?, any Error>?
    @State private var isChoosingLayout = false

    var body: some View {
        NewDocumentButton("New Note", for: PilotNoteDocument.self) {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                isChoosingLayout = true
            }
        }
        .sheet(isPresented: $isChoosingLayout, onDismiss: cancel) {
            ChooseLayoutView { layout in
                let continuation = continuation
                self.continuation = nil
                continuation?.resume(returning: PilotNoteDocument(layout: layout))
                isChoosingLayout = false
            }
        }
    }

    private func cancel() {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(throwing: CancellationError())
    }
}
