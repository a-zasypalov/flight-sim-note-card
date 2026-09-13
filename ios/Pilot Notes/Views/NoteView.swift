import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct NoteView: View {
    @Environment(NotesModel.self) private var notesModel
    @State private var isChoosingLogoSource = false
    @State private var isChoosingPhoto = false
    @State private var isChoosingFile = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var exportDocument: NotePDFDocument?
    @State private var isExporting = false
    @State private var errorMessage: String?

    let noteID: Note.ID

    private var note: Note? {
        notesModel.note(id: noteID)
    }

    private var layout: NoteLayout? {
        guard let note else { return nil }
        return NoteLayout.available.first {
            $0.id == note.layoutID && $0.revision == note.layoutRevision
        }
    }

    private var exportFilename: String {
        note?.name.replacingOccurrences(of: "/", with: "-") ?? "Pilot Note"
    }

    var body: some View {
        Group {
            if let note, let layout, let pdfURL = layout.pdfURL {
                NoteTemplateView(
                    layout: layout,
                    pdfURL: pdfURL,
                    fieldValues: note.content.fieldValues,
                    logoData: note.content.logoData,
                    onFieldChange: { fieldID, value in
                        notesModel.setField(fieldID, to: value, in: noteID)
                    },
                    onPickLogo: {
                        isChoosingLogoSource = true
                    },
                    onDropLogo: setLogo
                )
                .id(note.id)
            } else {
                ContentUnavailableView(
                    "Layout Unavailable",
                    systemImage: "doc.badge.ellipsis",
                    description: Text("This note's layout could not be loaded.")
                )
            }
        }
        .navigationTitle(note?.name ?? "Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {

            if(UIDevice.current.userInterfaceIdiom == .pad) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        print("Todo: implement annotations")
                    } label: {
                        Label("Annotate", systemImage: "pencil.tip.crop.circle")
                    }
                    .disabled(note == nil || layout == nil)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    print("Todo: implement renaming")
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .disabled(note == nil || layout == nil)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    prepareExport()
                } label: {
                    Label("Export PDF", systemImage: "square.and.arrow.up")
                }
                .disabled(note == nil || layout == nil)
            }
        }
        .confirmationDialog("Logo", isPresented: $isChoosingLogoSource) {
            Button("Photo Library") {
                isChoosingPhoto = true
            }
            Button("Files") {
                isChoosingFile = true
            }
            if note?.content.logoData != nil {
                Button("Remove Logo", role: .destructive) {
                    notesModel.setLogo(nil, in: noteID)
                }
            }
        }
        .photosPicker(isPresented: $isChoosingPhoto, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, item in
            loadPhoto(item)
        }
        .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [.image]) { result in
            loadFile(result)
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .pdf,
            defaultFilename: exportFilename
        ) { result in
            if case .failure(let error) = result {
                errorMessage = error.localizedDescription
            }
        }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            defer { selectedPhoto = nil }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    errorMessage = "The selected image could not be loaded."
                    return
                }
                setLogo(data: data)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            setLogo(data: try Data(contentsOf: url))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setLogo(data: Data) {
        guard let image = UIImage(data: data) else {
            errorMessage = "Choose an image that iPhone or iPad can read."
            return
        }
        setLogo(image)
    }

    private func setLogo(_ image: UIImage) {
        guard
            let logoFrame = layout?.logoFrame,
            image.size.width > 0,
            image.size.height > 0
        else {
            errorMessage = "The selected image could not be used as a logo."
            return
        }

        let size = CGSize(
            width: CGFloat((logoFrame.width / 25.4 * 300).rounded()),
            height: CGFloat((logoFrame.height / 25.4 * 300).rounded())
        )
        let scale = min(size.width / image.size.width, size.height / image.size.height)
        let imageSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let imageFrame = CGRect(
            x: (size.width - imageSize.width) / 2,
            y: (size.height - imageSize.height) / 2,
            width: imageSize.width,
            height: imageSize.height
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let data = UIGraphicsImageRenderer(size: size, format: format).pngData { _ in
            image.draw(in: imageFrame)
        }
        notesModel.setLogo(data, in: noteID)
    }

    private func prepareExport() {
        guard let note, let layout else { return }

        do {
            exportDocument = try NotePDFExporter.document(for: note, layout: layout)
            isExporting = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    let note = Note(name: "EDDF to EDDM", layout: .vatsimFlightCard)
    NavigationStack {
        NoteView(noteID: note.id)
            .environment(NotesModel(notes: [note]))
    }
}
