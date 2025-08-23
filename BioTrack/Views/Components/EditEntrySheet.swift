import SwiftUI

struct EditEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let entry: MetricEntry
    let metric: Metric?
    let onSave: (MetricEntry, Bool) -> Void // updated, delete?

    @State private var date: Date
    @State private var value: Double
    @State private var notes: String

    init(entry: MetricEntry, metric: Metric?, onSave: @escaping (MetricEntry, Bool) -> Void) {
        self.entry = entry
        self.metric = metric
        self.onSave = onSave
        _date = State(initialValue: entry.date)
        _value = State(initialValue: entry.value)
        _notes = State(initialValue: entry.notes ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Date")) {
                    DatePicker("", selection: $date, in: Date.distantPast...Date(), displayedComponents: .date)
                        .labelsHidden()
                }
                Section(header: Text("Valeur")) {
                    if metric?.kind == .hoursMinutes || (metric?.name.lowercased().contains("sommeil") ?? false) {
                        Stepper(value: $value, in: 0...16*60, step: 5) {
                            Text(minutesToLabel(Int(value)))
                        }
                    } else if metric?.name.lowercased().contains("poids") ?? false {
                        Stepper(value: $value, in: 0...300, step: 0.1) {
                            Text(String(format: "%.1f kg", value))
                        }
                    } else {
                        Stepper(value: $value, in: 0...10, step: 1) {
                            Text(String(format: "%.0f", value))
                        }
                    }
                }
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes).frame(minHeight: 80)
                }
                Section {
                    Button(role: .destructive) { onSave(entry, true); dismiss() } label: { Text("Supprimer l’entrée") }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    SheetHeader(
                        title: "Modifier l’entrée",
                        leadingTitle: "Annuler",
                        onLeading: { dismiss() },
                        trailingTitle: "Enregistrer",
                        onTrailing: { var e = entry; e.date = date; e.value = value; e.notes = notes.isEmpty ? nil : notes; onSave(e, false); Haptics.success(); dismiss() }
                    )
                }
            }
        }
    }

    private func minutesToLabel(_ mins: Int) -> String { String(format: "%dh%02d", mins/60, mins%60) }
}


