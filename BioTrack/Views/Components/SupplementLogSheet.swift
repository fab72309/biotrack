import SwiftUI

struct SupplementLogSheet: View {
    let supplement: Supplement
    let onDone: (Bool, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var taken: Bool = false
    @State private var notes: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Form {
                Section {
                    HStack {
                        Text(supplement.name).font(.headline)
                        Spacer()
                        if let dose = supplement.dose { Text(dose).foregroundColor(.blue) }
                    }
                    Text(supplement.brand ?? "non spécifié").foregroundColor(.secondary)
                }
                Section(header: Text("Dose quotidienne")) {
                    Toggle("Pris", isOn: $taken)
                }
                Section(header: Text("Notes (optionnel)")) {
                    TextEditor(text: $notes).frame(minHeight: 100)
                }
                HStack {
                    Button("Annuler") { dismiss() }
                    Spacer()
                    Button("Sauvegarder") { onDone(taken, notes); Haptics.success(); dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("Primary"))
                }
            }
        }
    }

    private var header: some View {
        SheetHeader(
            title: "Journaliser la prise",
            leadingIcon: "xmark",
            onLeading: { dismiss() },
            trailingTitle: "Terminé",
            onTrailing: { onDone(taken, notes); dismiss() }
        )
    }
}


