import SwiftUI

struct ProtocolTemplate: Identifiable {
    let id: String
    let name: String
    let goal: String
    let intervention: String
    let category: String
    let minutes: Int
    let frequency: Frequency
    let hour: Int
    let minute: Int
    let isUserDefined: Bool

    init(id: String = UUID().uuidString,
         name: String,
         goal: String,
         intervention: String,
         category: String,
         minutes: Int,
         frequency: Frequency,
         hour: Int,
         minute: Int,
         isUserDefined: Bool = false) {
        self.id = id
        self.name = name
        self.goal = goal
        self.intervention = intervention
        self.category = category
        self.minutes = minutes
        self.frequency = frequency
        self.hour = hour
        self.minute = minute
        self.isUserDefined = isUserDefined
    }
}

let protocolTemplateLibrary: [ProtocolTemplate] = [
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

struct TemplatesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: AppState
    let onSelect: (ProtocolTemplate) -> Void
    @State private var selectedCategory: String? = nil
    @State private var searchText: String = ""

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
                    ForEach(filteredTemplates) { t in
                        Button(action: { onSelect(t); dismiss() }) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Text(t.name).font(.headline)
                                    if t.isUserDefined {
                                        Text("Perso")
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color("Primary").opacity(0.12))
                                            .foregroundColor(Color("Primary"))
                                            .clipShape(Capsule())
                                    }
                                }
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
                Section(footer: Text("Ces modèles incluent la bibliothèque BioTrack et vos modèles personnalisés.")) { EmptyView() }
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
        Array(Set(allTemplates.map { $0.category })).sorted()
    }

    private var filteredTemplates: [ProtocolTemplate] {
        let base: [ProtocolTemplate]
        if let c = selectedCategory { base = allTemplates.filter { $0.category == c } } else { base = allTemplates }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.goal.localizedCaseInsensitiveContains(q) }
    }

    private var allTemplates: [ProtocolTemplate] {
        var merged: [ProtocolTemplate] = []
        var seen: Set<String> = []

        for template in protocolTemplateLibrary {
            let key = normalizedTemplateKey(template.name)
            if seen.insert(key).inserted {
                merged.append(template)
            }
        }
        for template in customTemplates {
            let key = normalizedTemplateKey(template.name)
            if seen.insert(key).inserted {
                merged.append(template)
            }
        }
        return merged
    }

    private var customTemplates: [ProtocolTemplate] {
        state.customProtocolTemplates.map { template in
            let detail = template.detail?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackDetail = "Modèle personnalisé"
            return ProtocolTemplate(
                id: "custom-\(template.id.uuidString)",
                name: template.name,
                goal: (detail?.isEmpty == false ? detail! : fallbackDetail),
                intervention: (detail?.isEmpty == false ? detail! : fallbackDetail),
                category: template.category,
                minutes: max(1, template.minutes),
                frequency: template.frequency,
                hour: max(0, min(template.hour, 23)),
                minute: max(0, min(template.minute, 59)),
                isUserDefined: true
            )
        }
    }

    private func normalizedTemplateKey(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
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
