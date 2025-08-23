import SwiftUI

struct CreateMetricSheet: View {
    var onCreate: (Metric) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var descriptionText: String = ""
    enum Kind { case number, scale, yesno, duration }
    @State private var kind: Kind = .number
    @State private var unit: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Annuler") { dismiss() }
                Spacer()
                Text("Créer une métrique").font(.headline)
                Spacer()
                Button("Enregistrer") { onCreate(buildMetric()); dismiss() }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)

            Form {
                Section(header: RequiredHeader("Nom")) {
                    TextField("ex.: Temps de méditation", text: $name)
                }
                Section(header: Text("Description")) {
                    TextField("ex.: Durée quotidienne de méditation", text: $descriptionText)
                }
                Section(header: Text("Type")) {
                    HStack(spacing: 8) {
                        typeChip("Nombre", selected: kind == .number) { kind = .number }
                        typeChip("Échelle", selected: kind == .scale) { kind = .scale }
                        typeChip("Oui/Non", selected: kind == .yesno) { kind = .yesno }
                        typeChip("Durée", selected: kind == .duration) { kind = .duration }
                    }
                }
                Section(header: Text("Unité (optionnel)")) {
                    TextField("ex.: kg, h, etc.", text: $unit)
                }
            }
        }
    }

    private func typeChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .frame(height: 34)
                .padding(.horizontal, 12)
                .background(selected ? Color("Primary") : Color(UIColor.secondarySystemBackground))
                .foregroundColor(selected ? Color("OnPrimary") : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func buildMetric() -> Metric {
        let kindVal: MetricKind = (kind == .duration) ? .hoursMinutes : .number
        let unitVal: String? = unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : unit
        return Metric(name: name, kind: kindVal, unit: unitVal, description: descriptionText.isEmpty ? nil : descriptionText)
    }
}


