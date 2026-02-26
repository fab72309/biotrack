import SwiftUI

struct CheckInMetricSelectionView: View {
    @EnvironmentObject var state: AppState
    @Binding var selectionRaw: String
    @State private var selectedMetricIds: [UUID] = []

    var body: some View {
        List {
            Section(header: Text("Métriques sélectionnées (ordre check-in)")) {
                if selectedMetrics.isEmpty {
                    Text("Aucune métrique sélectionnée. Ajoutez des éléments depuis la section ci-dessous.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(selectedMetrics) { metric in
                        HStack(spacing: 12) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(metricDisplayName(metric))
                                Text(metricSubtitle(metric))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: { remove(metric.id) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Retirer \(metric.name)")
                        }
                    }
                    .onMove(perform: moveSelection)

                    Text("Maintenez puis glissez pour réordonner (de haut en bas).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Ajouter depuis Suivi")) {
                if sortedMetrics.isEmpty {
                    Text("Ajoutez d'abord des métriques dans l'onglet Suivi.")
                        .foregroundColor(.secondary)
                } else if availableMetrics.isEmpty {
                    Text("Toutes les métriques de Suivi sont déjà sélectionnées.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(availableMetrics) { metric in
                        Button(action: { add(metric.id) }) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(metricDisplayName(metric))
                                    Text(metricSubtitle(metric))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(Color("Primary"))
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }

            Section(header: Text("Actions")) {
                Button("Tout sélectionner") {
                    selectedMetricIds = sortedMetrics.map(\.id)
                    persistSelection()
                }
                .disabled(sortedMetrics.isEmpty)

                Button("Réinitialiser", role: .destructive) {
                    selectedMetricIds.removeAll()
                    persistSelection()
                }
                .disabled(selectedMetricIds.isEmpty)
            }
        }
        .navigationTitle("Champs check-ins")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .onAppear {
            selectedMetricIds = CheckInMetricSelection.parseOrdered(selectionRaw)
            sanitizeSelection()
            persistSelection()
        }
        .onChange(of: state.metrics) { _ in
            sanitizeSelection()
            persistSelection()
        }
        .onChange(of: selectedMetricIds) { _ in
            persistSelection()
        }
    }

    private var sortedMetrics: [Metric] {
        state.metrics.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var metricsById: [UUID: Metric] {
        Dictionary(uniqueKeysWithValues: state.metrics.map { ($0.id, $0) })
    }

    private var selectedMetrics: [Metric] {
        selectedMetricIds.compactMap { metricsById[$0] }
    }

    private var availableMetrics: [Metric] {
        let selected = Set(selectedMetricIds)
        return sortedMetrics.filter { !selected.contains($0.id) }
    }

    private func sanitizeSelection() {
        selectedMetricIds = CheckInMetricSelection.sanitizeOrdered(
            selectedMetricIds,
            availableIds: sortedMetrics.map(\.id)
        )
    }

    private func persistSelection() {
        selectionRaw = CheckInMetricSelection.encode(selectedMetricIds)
    }

    private func add(_ id: UUID) {
        guard !selectedMetricIds.contains(id) else { return }
        selectedMetricIds.append(id)
    }

    private func remove(_ id: UUID) {
        selectedMetricIds.removeAll { $0 == id }
    }

    private func moveSelection(from source: IndexSet, to destination: Int) {
        selectedMetricIds.move(fromOffsets: source, toOffset: destination)
    }

    private func metricSubtitle(_ metric: Metric) -> String {
        switch metric.kind {
        case .hoursMinutes:
            return "Durée (heures/minutes)"
        case .number:
            if let unit = metric.unit, !unit.isEmpty {
                return unit
            }
            return "Valeur numérique"
        }
    }

    private func metricDisplayName(_ metric: Metric) -> String {
        if metric.kind == .hoursMinutes,
           metric.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased().contains("sommeil") {
            return "Durée du sommeil"
        }
        return metric.name
    }
}
