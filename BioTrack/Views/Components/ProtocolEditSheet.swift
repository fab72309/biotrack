import SwiftUI

struct ProtocolEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    var existing: ProtocolItem
    var onSave: (ProtocolItem) -> Void

    @State private var name: String = ""
    @State private var detail: String = ""
    @State private var notes: String = ""
    @State private var active: Bool = true

    init(existing: ProtocolItem, onSave: @escaping (ProtocolItem) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _name = State(initialValue: existing.name)
        _detail = State(initialValue: existing.detail ?? "")
        _notes = State(initialValue: existing.notes ?? "")
        _active = State(initialValue: existing.active)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Nom")) { TextField("Nom", text: $name) }
                Section(header: Text("Détail")) { TextField("Détail", text: $detail) }
                Section(header: Text("Actif")) { Toggle("Activer le protocole", isOn: $active) }
                Section(header: Text("Notes")) { TextEditor(text: $notes).frame(minHeight: 120) }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    SheetHeader(
                        title: "Modifier le protocole",
                        leadingTitle: "Fermer",
                        onLeading: { dismiss() },
                        trailingTitle: "Enregistrer",
                        onTrailing: { save() }
                    )
                }
            }
        }
    }

    private func save() {
        var updated = existing
        updated.name = name
        updated.detail = detail.isEmpty ? nil : detail
        updated.notes = notes.isEmpty ? nil : notes
        if updated.active != active {
            // mettre à jour via AppState depuis l'appelant si besoin
            updated.active = active
        }
        onSave(updated)
        dismiss()
    }
}

#Preview { ProtocolEditSheet(existing: ProtocolItem(name: "Test", detail: nil, frequency: .daily), onSave: { _ in }) }


