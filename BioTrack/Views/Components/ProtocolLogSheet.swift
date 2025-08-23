import SwiftUI

struct ProtocolLogSheet: View {
    let item: ProtocolItem
    let onDone: (Bool, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var completed: Bool = false
    @State private var time: Date = Date()
    @State private var notes: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Form {
                Section(header: Text("Objectif")) {
                    Text(item.goal ?? item.detail ?? "").foregroundColor(.primary)
                }
                Section(header: Text("Intervention")) {
                    Text(item.intervention ?? "").foregroundColor(.primary)
                }
                Section(header: Text("Heure de réalisation")) {
                    DatePicker("", selection: $time, displayedComponents: .hourAndMinute).labelsHidden()
                }
                Section(header: Text("Notes (optionnel)")) {
                    TextEditor(text: $notes).frame(minHeight: 100)
                }
                Section(header: Text("Marquer comme complété ?")) {
                    Toggle("", isOn: $completed).labelsHidden()
                }
                HStack {
                    Button("Annuler") { dismiss() }
                    Spacer()
                    Button("Sauvegarder") { onDone(completed, notes); Haptics.success(); dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("Primary"))
                }
            }
        }
    }

    private var header: some View {
        SheetHeader(
            title: "Journaliser: \(item.name)",
            leadingIcon: "xmark",
            onLeading: { dismiss() },
            trailingTitle: "Terminé",
            onTrailing: { onDone(completed, notes); dismiss() }
        )
    }
}


