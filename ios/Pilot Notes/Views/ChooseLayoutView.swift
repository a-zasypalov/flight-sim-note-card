import SwiftUI

struct ChooseLayoutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedLayoutID: NoteLayout.ID?

    let layouts: [NoteLayout]
    let onCreate: (String, NoteLayout) -> Void

    init(
        layouts: [NoteLayout] = NoteLayout.available,
        onCreate: @escaping (String, NoteLayout) -> Void
    ) {
        self.layouts = layouts
        self.onCreate = onCreate
    }

    private var selectedLayout: NoteLayout? {
        layouts.first { $0.id == selectedLayoutID }
    }

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedLayout != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextField("Name", text: $name)
                }

                Section("Layout") {
                    ForEach(layouts) { layout in
                        Button {
                            selectedLayoutID = layout.id
                        } label: {
                            HStack {
                                Text(layout.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedLayoutID == layout.id {
                                    Image(systemName: "checkmark")
                                        .accessibilityHidden(true)
                                }
                            }
                            .contentShape(.rect)
                        }
                        .accessibilityAddTraits(selectedLayoutID == layout.id ? .isSelected : [])
                    }
                }
            }
            .navigationTitle("New Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard let selectedLayout else { return }
                        onCreate(name, selectedLayout)
                        dismiss()
                    }
                    .disabled(!canCreate)
                }
            }
            .onAppear {
                if selectedLayoutID == nil {
                    selectedLayoutID = layouts.first?.id
                }
            }
        }
    }
}

#Preview {
    ChooseLayoutView { _, _ in }
}
