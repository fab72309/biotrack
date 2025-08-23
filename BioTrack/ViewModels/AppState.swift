import Foundation

final class AppState: ObservableObject {
    @Published var protocols: [ProtocolItem] = []
    @Published var protocolCompletions: [ProtocolCompletion] = []
    @Published var supplements: [Supplement] = []
    @Published var supplementIntakes: [SupplementIntake] = []
    @Published var metrics: [Metric] = []
    @Published var metricEntries: [MetricEntry] = []
    @Published var reminders: [Reminder] = []
    
    private let store = LocalStore.shared
    
    init() {
        load()
        if protocols.isEmpty && supplements.isEmpty && metrics.isEmpty {
            seed()
            save()
        }
        migrateMetricsIfNeeded()
        migrateSupplementCategoriesIfNeeded()
    }
    
    func load() {
        let s = store.load()
        self.protocols = s.protocols
        self.protocolCompletions = s.protocolCompletions
        self.supplements = s.supplements
        self.supplementIntakes = s.supplementIntakes
        self.metrics = s.metrics
        self.metricEntries = s.metricEntries
        self.reminders = s.reminders
    }
    
    func save() {
        let snap = LocalStore.Snapshot(protocols: protocols,
                                       protocolCompletions: protocolCompletions,
                                       supplements: supplements,
                                       supplementIntakes: supplementIntakes,
                                       metrics: metrics,
                                       metricEntries: metricEntries,
                                       reminders: reminders)
        store.save(snap)
    }

    // MARK: - Activation toggles
    func toggleSupplementActivation(_ id: UUID, at date: Date = Date()) {
        guard let idx = supplements.firstIndex(where: { $0.id == id }) else { return }
        var item = supplements[idx]
        let now = date
        if item.active {
            if item.activationSpans.isEmpty {
                item.activationSpans = [ActivationSpan(start: Date.distantPast, end: now)]
            } else if let last = item.activationSpans.last, last.end == nil {
                item.activationSpans[item.activationSpans.count - 1].end = now
            }
            item.active = false
        } else {
            item.activationSpans.append(ActivationSpan(start: now, end: nil))
            item.active = true
        }
        var arr = supplements
        arr[idx] = item
        supplements = arr
        save()
    }

    func toggleProtocolActivation(_ id: UUID, at date: Date = Date()) {
        guard let idx = protocols.firstIndex(where: { $0.id == id }) else { return }
        var item = protocols[idx]
        let now = date
        if item.active {
            if item.activationSpans.isEmpty {
                item.activationSpans = [ActivationSpan(start: Date.distantPast, end: now)]
            } else if let last = item.activationSpans.last, last.end == nil {
                item.activationSpans[item.activationSpans.count - 1].end = now
            }
            item.active = false
        } else {
            item.activationSpans.append(ActivationSpan(start: now, end: nil))
            item.active = true
        }
        var arr = protocols
        arr[idx] = item
        protocols = arr
        save()
    }
    
    func seed() {
        let meditation = ProtocolItem(name: "Méditation matinale",
                                      detail: "10 minutes",
                                      frequency: .daily,
                                      preferredHour: DateComponents(hour: 7, minute: 0),
                                      targetMinutes: 10,
                                      notes: "Respiration calme",
                                      remindersEnabled: true)
        protocols.append(meditation)
        
        let vitD = Supplement(name: "Vitamine D3",
                              brand: "Nutripure",
                              dose: "5000 UI",
                              category: "Vitamines",
                              timeOfDay: DateComponents(hour: 8, minute: 0),
                              frequency: .daily,
                              durationNote: "3 mois",
                              notes: "Avec repas",
                              active: true)
        supplements.append(vitD)
        
        let sleep = Metric(name: "Sommeil", kind: .hoursMinutes, unit: "h")
        let mood = Metric(name: "Humeur", kind: .number, unit: "1-10")
        metrics.append(contentsOf: [sleep, mood])
    }
}

// MARK: - Migrations
extension AppState {
    private func migrateMetricsIfNeeded() {
        // Objectif: unifier la métrique de sommeil (durée) sous le nom "Sommeil"
        // et fusionner d'éventuels doublons (ex.: "Durée du sommeil").
        let sleepMetrics = metrics.enumerated().filter { $0.element.kind == .hoursMinutes }
        guard !sleepMetrics.isEmpty else { return }

        // Choisir un ID canonique
        let canonicalIndex: Int
        if let idx = sleepMetrics.first(where: { $0.element.name.lowercased().contains("sommeil") })?.offset {
            canonicalIndex = idx
        } else {
            canonicalIndex = sleepMetrics.first!.offset
        }
        let canonicalId = metrics[canonicalIndex].id

        // Renommer la métrique canonique en "Sommeil"
        metrics[canonicalIndex].name = "Sommeil"
        if metrics[canonicalIndex].unit == nil { metrics[canonicalIndex].unit = "h" }

        // Rediriger les entrées vers l'ID canonique et supprimer doublons
        let duplicateIndices = sleepMetrics.map { $0.offset }.filter { $0 != canonicalIndex }.sorted(by: >)
        if !duplicateIndices.isEmpty {
            for dupIdx in duplicateIndices {
                let dupId = metrics[dupIdx].id
                for i in 0..<metricEntries.count {
                    if metricEntries[i].metricId == dupId { metricEntries[i].metricId = canonicalId }
                }
                metrics.remove(at: dupIdx)
            }
            save()
        }
    }

    // Normalise les catégories de suppléments (fusion EN -> FR, casse, accents)
    private func migrateSupplementCategoriesIfNeeded() {
        guard !supplements.isEmpty else { return }
        var changed = false
        for idx in supplements.indices {
            if let cat = supplements[idx].category {
                let canonical = canonicalCategory(from: cat)
                if canonical != cat {
                    supplements[idx].category = canonical
                    changed = true
                }
            }
        }
        if changed { save() }
    }

    private func canonicalCategory(from raw: String) -> String {
        let key = normalize(raw)
        switch key {
        case "nootropiques", "nootropics": return "Nootropiques"
        case "vitamines", "vitamins": return "Vitamines"
        case "mineraux", "minéraux", "minerals": return "Minéraux"
        case "proteines", "protéines", "protein", "proteins": return "Protéines"
        case "energie", "énergie", "performance", "energy": return "Énergie"
        case "recuperation", "récupération", "recovery": return "Récupération"
        case "sommeil", "sleep": return "Sommeil"
        case "digestif", "digestive": return "Digestif"
        case "immunite", "immunité", "immune": return "Immunité"
        case "traitement medical", "traitement", "medical": return "Traitement médical"
        default: return raw
        }
    }

    private func normalize(_ s: String) -> String {
        let lower = s.lowercased()
        let folded = lower.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return folded.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
