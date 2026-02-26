import SwiftUI

struct NOf1WizardSheet: View {
    let metrics: [Metric]
    let onCreate: (ExperimentWizardInput) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var hypothesis: String = ""
    @State private var selectedMetricId: UUID?
    @State private var startDate: Date = Date()
    @State private var durationDays: Int = 21
    @State private var phaseDurationDays: Int = 7
    @State private var controlLabel: String = "Contrôle"
    @State private var interventionLabel: String = "Intervention"

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Hypothèse")) {
                    TextField("Titre de l'expérience", text: $title)
                    TextField("Hypothèse (ex: le protocole améliore mon humeur)", text: $hypothesis)
                }
                Section(header: Text("Mesure cible")) {
                    Picker("Métrique", selection: $selectedMetricId) {
                        Text("Sélectionner").tag(UUID?.none)
                        ForEach(metrics) { metric in
                            Text(metric.name).tag(UUID?.some(metric.id))
                        }
                    }
                    DatePicker("Date de départ", selection: $startDate, displayedComponents: .date)
                }
                Section(header: Text("Cadence")) {
                    Stepper("Durée totale: \(durationDays) jours", value: $durationDays, in: 7...90)
                    Stepper("Durée phase A/B: \(phaseDurationDays) jours", value: $phaseDurationDays, in: 3...30)
                }
                Section(header: Text("Libellés")) {
                    TextField("Phase A", text: $controlLabel)
                    TextField("Phase B", text: $interventionLabel)
                }
            }
            .navigationTitle("N-of-1")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        guard let metricId = selectedMetricId else { return }
                        onCreate(
                            ExperimentWizardInput(
                                title: title,
                                hypothesis: hypothesis,
                                targetMetricId: metricId,
                                startDate: startDate,
                                durationDays: durationDays,
                                phaseDurationDays: phaseDurationDays,
                                controlLabel: controlLabel,
                                interventionLabel: interventionLabel
                            )
                        )
                        dismiss()
                    }
                    .disabled(selectedMetricId == nil)
                }
            }
        }
        .onAppear {
            if selectedMetricId == nil {
                selectedMetricId = metrics.first?.id
            }
        }
    }
}

