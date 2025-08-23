import SwiftUI

struct ProtocolTemplate: Identifiable {
    let id = UUID()
    let name: String
    let goal: String
    let intervention: String
    let category: String
    let minutes: Int
    let frequency: Frequency
    let hour: Int
    let minute: Int
}

struct TemplatesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (ProtocolTemplate) -> Void
    @State private var selectedCategory: String? = nil
    @State private var searchText: String = ""

    private let samples: [ProtocolTemplate] = [
        ProtocolTemplate(name: "Jeûne 16/8",
                          goal: "Améliorer la sensibilité à l'insuline et la clarté mentale",
                          intervention: "Jeûner 16 h/jour (20h→12h). Hydratation, café/thé non sucré autorisés.",
                          category: "Métabolisme",
                          minutes: 10,
                          frequency: .daily,
                          hour: 8,
                          minute: 0),
        ProtocolTemplate(name: "Respiration Wim Hof",
                          goal: "Réduire le stress et augmenter l'énergie",
                          intervention: "3 à 4 cycles de 30-40 respirations profondes + rétention, chaque matin.",
                          category: "Énergie",
                          minutes: 15,
                          frequency: .daily,
                          hour: 7,
                          minute: 0),
        ProtocolTemplate(name: "Exposition au froid",
                          goal: "Stimuler la noradrénaline et améliorer la récupération",
                          intervention: "Douche froide 2-3 min à la fin de la douche quotidienne, 4-5x/semaine.",
                          category: "Récupération",
                          minutes: 3,
                          frequency: .weekly(days: [2,4,6]),
                          hour: 8,
                          minute: 30),
        ProtocolTemplate(name: "Pomodoro profond",
                          goal: "Améliorer la concentration soutenue",
                          intervention: "4 cycles de 25 min focus + 5 min pause, 1 à 2 fois/jour.",
                          category: "Cognition",
                          minutes: 25,
                          frequency: .timesPerDay(2),
                          hour: 10,
                          minute: 0),
        ProtocolTemplate(name: "Journal de gratitude",
                          goal: "Clarté mentale et humeur",
                          intervention: "Écrire 3 choses positives chaque soir (2 min)",
                          category: "Cognition",
                          minutes: 2,
                          frequency: .daily,
                          hour: 21,
                          minute: 30)
    ]

    var body: some View {
        NavigationView {
            List {
                Section { SearchField(placeholder: "Rechercher un modèle...", text: $searchText) }
                if !categories.isEmpty {
                    Section(header: Text("Catégories")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                SelectableChip(title: "Toutes", selected: selectedCategory == nil) { selectedCategory = nil }
                                ForEach(categories, id: \.self) { c in
                                    SelectableChip(title: c,
                                                   selected: selectedCategory == c,
                                                   iconSystemName: CategoryAppearance.iconName(for: c),
                                                   tintColor: CategoryAppearance.color(for: c),
                                                   action: { selectedCategory = c })
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                Section(header: Text("Modèles recommandés")) {
                    ForEach(filteredSamples) { t in
                        Button(action: { onSelect(t); dismiss() }) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(t.name).font(.headline)
                                Text(t.goal).font(.subheadline).foregroundStyle(.secondary)
                                HStack(spacing: 6) {
                                    Image(systemName: iconForCategory(t.category))
                                        .foregroundColor(colorForCategory(t.category))
                                    Text(t.category)
                                }
                                .font(.caption.weight(.semibold))
                                HStack(spacing: 8) {
                                    Image(systemName: "clock")
                                    Text(labelForFrequency(t.frequency))
                                    Text("· \(t.minutes) min")
                                    Text(String(format: "· %02d:%02d", t.hour, t.minute))
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                Section(footer: Text("Ces modèles sont fournis à titre d'exemple et peuvent être adaptés.")) { EmptyView() }
            }
            .navigationTitle("Modèles")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } } }
        }
        .withSheetDetentsIfAvailable()
    }

    private func labelForFrequency(_ f: Frequency) -> String {
        switch f {
        case .daily: return "Quotidienne"
        case .timesPerDay(let n): return n <= 1 ? "1 fois/jour" : "\(n) fois/jour"
        case .weekly(let days): return days.isEmpty ? "Si besoin" : "Jours spécifiques"
        }
    }

    private var categories: [String] {
        Array(Set(samples.map { $0.category })).sorted()
    }

    private var filteredSamples: [ProtocolTemplate] {
        let base: [ProtocolTemplate]
        if let c = selectedCategory { base = samples.filter { $0.category == c } } else { base = samples }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.goal.localizedCaseInsensitiveContains(q) }
    }

    
}

private func iconForCategory(_ category: String) -> String {
    let key = category.lowercased()
    switch key {
    case "cognition", "nootropiques": return "brain.head.profile"
    case "énergie", "performance": return "bolt"
    case "récupération": return "heart"
    case "sommeil": return "moon"
    case "métabolisme": return "chart.line.uptrend.xyaxis"
    default: return "circle.grid.3x3"
    }
}

private func colorForCategory(_ category: String) -> Color {
    let key = category.lowercased()
    switch key {
    case "cognition", "nootropiques": return .purple
    case "énergie", "performance": return .pink
    case "récupération": return .green
    case "sommeil": return .indigo
    case "métabolisme": return .blue
    default: return .secondary
    }
}


