import SwiftUI

struct TrackView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedMetric: Metric?
    @State private var numberValue: Double = 0
    @State private var durationMinutes: Double = 0
    @State private var notes: String = ""
    @State private var showingCreate = false
    @State private var date: Date = Date()
    @State private var sleepHours: Int = 0
    @State private var sleepMinutes: Int = 0
    @State private var weightUnit: String = "kg"
    @State private var weightValue: Double = 70
    @State private var entriesToShow: Int = 5
    @State private var showingFilter = false
    @State private var filterMetricId: UUID? = nil
    @State private var editingEntry: MetricEntry? = nil
    enum DateFilter { case all, today, last7, last30 }
    @State private var dateFilter: DateFilter = .all
    @State private var dateLocked: Bool = true
    @State private var toDeleteEntry: MetricEntry? = nil
    @State private var showDeleteAlert: Bool = false
    @State private var categoryFilters: Set<String> = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    metricChips
                    if selectedMetric != nil { entryCard }
                    recentEntries
                }
                .padding()
            }
            .navigationTitle("Suivi")
        }
        .sheet(isPresented: $showingCreate) { CreateMetricSheet { metric in state.metrics.append(metric); state.save() } .withSheetDetentsIfAvailable() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Saisie des mesures")
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            Spacer()
            Button(action: { dateLocked.toggle() }) {
                Image(systemName: dateLocked ? "lock.fill" : "lock.open.fill")
                    .foregroundColor(Color("Primary"))
            }
            .buttonStyle(.plain)
            DatePicker("", selection: $date, in: Date.distantPast...Date(), displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .disabled(dateLocked)
        }
    }

    private var metricChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sélectionner une métrique").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    let presets = defaultMetrics()
                    let selectedPresetId = equivalentPresetId(for: selectedMetric, within: presets)
                    ForEach(presets, id: \.id) { metric in
                        SelectableChip(title: metric.name, selected: selectedPresetId == metric.id) {
                            selectedMetric = ensureMetricExists(metric)
                        }
                    }
                    Button(action: { showingCreate = true }) {
                        HStack(spacing: 6) { Image(systemName: "plus"); Text("Créer") }
                            .padding(.vertical, 10).padding(.horizontal, 14)
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))).foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    

    private var entryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedMetric?.name ?? "Sélectionner une métrique")
                .font(.title3.weight(.semibold))
            Text(descriptionForSelected()).foregroundColor(.secondary)
            if let metric = selectedMetric {
                inputForMetric(metric)
                VStack(alignment: .leading) {
                    Text("Notes (optionnel)").font(.subheadline.weight(.semibold))
                    TextEditor(text: $notes).frame(minHeight: 90)
                }
                Button(action: { saveEntry(); Haptics.success() }) { Label("Sauvegarder", systemImage: "externaldrive.badge.checkmark") }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("Primary"))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(UIColor.secondarySystemBackground)))
    }

    private var recentEntries: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Entrées récentes").font(.headline)
                Spacer()
                Button(action: { showingFilter = true }) { Image(systemName: "line.3.horizontal.decrease.circle") }
            }
            if filteredAllEntries().isEmpty {
                SurfaceCard {
                    EmptyStateView(text: "Aucune donnée enregistrée", systemImageName: "chart.bar")
                        .frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredAllEntries().prefix(entriesToShow)) { entry in
                        let metric = metricById(entry.metricId)
                        SwipeableRow(onEdit: { editingEntry = entry }, onDelete: { toDeleteEntry = entry; showDeleteAlert = true }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(metric?.name ?? "—").font(.subheadline.weight(.semibold))
                                    Text(entry.date, style: .date).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(formattedValue(entry, metric: metric))
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.vertical, 4)
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        Divider()
                    }
                    if entriesToShow < filteredAllEntries().count {
                        Button("Afficher 10 de plus") { entriesToShow += 10 }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
            }
        }
        .sheet(isPresented: $showingFilter) { filterSheet }
        .alert("Supprimer l’entrée ?", isPresented: $showDeleteAlert, presenting: toDeleteEntry) { entry in
            Button("Supprimer", role: .destructive) {
                if let idx = state.metricEntries.firstIndex(where: { $0.id == entry.id }) {
                    state.metricEntries.remove(at: idx)
                    state.save()
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: { entry in
            let mName = metricById(entry.metricId)?.name ?? "Métrique"
            let df = DateFormatter(); df.dateStyle = .medium
            let valueText = formattedValue(entry, metric: metricById(entry.metricId))
            return Text("Supprimer l’entrée ‘\(mName)’ (\(valueText)) du \(df.string(from: entry.date)) ? Cette action est irréversible.")
        }
        .sheet(item: $editingEntry) { entry in
            EditEntrySheet(entry: entry, metric: metricById(entry.metricId)) { updated, delete in
                if delete {
                    state.metricEntries.removeAll { $0.id == entry.id }
                } else if let idx = state.metricEntries.firstIndex(where: { $0.id == entry.id }) {
                    state.metricEntries[idx] = updated
                }
                state.save()
            }
        }
    }

    private func saveEntry() {
        guard let metric = selectedMetric else { return }
        var v: Double
        if metric.kind == .hoursMinutes {
            v = Double(sleepHours * 60 + sleepMinutes)
        } else if metric.name.lowercased().contains("poids") {
            // Convert to kg if nécessaire
            let kg = weightUnit == "lb" ? weightValue * 0.45359237 : weightValue
            v = kg
        } else {
            v = numberValue
        }
        let entry = MetricEntry(metricId: metric.id, date: date, value: v, notes: notes.isEmpty ? nil : notes)
        state.metricEntries.append(entry)
        state.save()
        numberValue = 0; durationMinutes = 0; sleepHours = 0; sleepMinutes = 0; weightValue = 70; notes = ""
        entriesToShow = 5
    }

    private func descriptionForSelected() -> String {
        guard let m = selectedMetric else { return "" }
        if let d = m.description { return d }
        switch m.kind {
        case .hoursMinutes: return "Heures de sommeil par nuit"
        case .number: return m.unit ?? ""
        }
    }

    private func defaultMetrics() -> [Metric] {
        let presets: [Metric] = [
            Metric(name: "Durée du sommeil", kind: .hoursMinutes, unit: "h", description: "Heures de sommeil par nuit"),
            Metric(name: "Qualité du sommeil", kind: .number, unit: "1-10"),
            Metric(name: "Humeur", kind: .number, unit: "1-10"),
            Metric(name: "Énergie", kind: .number, unit: "1-10"),
            Metric(name: "Concentration", kind: .number, unit: "1-10"),
            Metric(name: "Poids", kind: .number, unit: "kg"),
            Metric(name: "Stress", kind: .number, unit: "1-10"),
        ]
        return presets
    }

    private func ensureMetricExists(_ m: Metric) -> Metric {
        // Si une métrique équivalente existe (par nom ou par type clé), la réutiliser
        if let existingByName = state.metrics.first(where: { $0.name == m.name }) { return existingByName }
        if m.kind == .hoursMinutes {
            if let existingByKind = state.metrics.first(where: { $0.kind == .hoursMinutes }) { return existingByKind }
        }
        state.metrics.append(m); state.save(); return m
    }

    private func isSelectedChip(_ preset: Metric) -> Bool {
        guard let current = selectedMetric else { return false }
        // Match exact id if preset is already persisted
        if current.id == preset.id { return true }
        // Match by name
        if current.name == preset.name { return true }
        // Special case: sommeil (durée) -> match by kind hoursMinutes
        if preset.kind == .hoursMinutes && current.kind == .hoursMinutes { return true }
        return false
    }

    private func equivalentPresetId(for current: Metric?, within presets: [Metric]) -> UUID? {
        guard let current = current else { return nil }
        if let exact = presets.first(where: { $0.id == current.id }) { return exact.id }
        if let byName = presets.first(where: { $0.name == current.name }) { return byName.id }
        if current.kind == .hoursMinutes, let byKind = presets.first(where: { $0.kind == .hoursMinutes }) { return byKind.id }
        return nil
    }
}

// MARK: - Inputs
private extension TrackView {
    @ViewBuilder
    func inputForMetric(_ metric: Metric) -> some View {
        if metric.kind == .hoursMinutes {
            // Durée de sommeil: heures et minutes
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Heures").font(.subheadline)
                    Picker("Heures", selection: $sleepHours) {
                        ForEach(0...16, id: \.self) { Text("\($0) h") }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 120)
                }
                VStack(alignment: .leading) {
                    Text("Minutes").font(.subheadline)
                    Picker("Minutes", selection: $sleepMinutes) {
                        ForEach([0,5,10,15,20,25,30,35,40,45,50,55], id: \.self) { Text("\($0) min") }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 120)
                }
                Spacer()
            }
        } else if metric.name.lowercased().contains("poids") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Valeur")
                    Spacer()
                    Stepper("\(weightValue, specifier: "%.1f")", value: $weightValue, in: 0...300, step: 0.1)
                }
                Picker("Unité", selection: $weightUnit) {
                    Text("kg").tag("kg")
                    Text("lb").tag("lb")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Échelle")
                    Spacer()
                    Text("\(Int(numberValue))")
                        .font(.subheadline.weight(.semibold))
                }
                Slider(value: $numberValue, in: 0...10, step: 1)
            }
        }
    }

    func filteredAllEntries() -> [MetricEntry] {
        var items = state.metricEntries
        if let id = filterMetricId { items = items.filter { $0.metricId == id } }
        if !categoryFilters.isEmpty {
            items = items.filter { entry in
                guard let m = metricById(entry.metricId) else { return false }
                return categoryFilters.contains(metricCategory(for: m))
            }
        }
        let cal = Calendar.current
        switch dateFilter {
        case .all: break
        case .today: items = items.filter { cal.isDateInToday($0.date) }
        case .last7: items = items.filter { ($0.date >= cal.date(byAdding: .day, value: -7, to: Date())!) }
        case .last30: items = items.filter { ($0.date >= cal.date(byAdding: .day, value: -30, to: Date())!) }
        }
        return items.sorted(by: { $0.date > $1.date })
    }

    func formattedValue(_ entry: MetricEntry, metric: Metric?) -> String {
        guard let metric = metric ?? metricById(entry.metricId) else { return "" }
        if metric.kind == .hoursMinutes {
            let mins = Int(entry.value)
            let h = mins / 60
            let m = mins % 60
            return String(format: "%dh %02d", h, m)
        } else if metric.name.lowercased().contains("poids") {
            let val = entry.value // stored in kg
            return String(format: "%.1f kg", val)
        } else {
            return String(Int(entry.value))
        }
    }
    func metricById(_ id: UUID) -> Metric? { state.metrics.first(where: { $0.id == id }) }

    func metricCategory(for metric: Metric) -> String {
        let lower = metric.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
        if lower.contains("sommeil") { return "Sommeil" }
        if lower.contains("poids") { return "Corps" }
        if ["humeur", "energie", "énergie", "concentration", "stress"].contains(where: { lower.contains($0) }) { return "Bien-être" }
        return "Autre"
    }

    func allMetricCategories() -> [String] {
        let cats = Set(state.metrics.map { metricCategory(for: $0) })
        let order = ["Sommeil", "Bien-être", "Corps", "Autre"]
        let sortedKnown = order.filter { cats.contains($0) }
        let others = cats.subtracting(sortedKnown)
        return sortedKnown + others.sorted()
    }

    /// Liste des métriques proposées dans le filtre: union des presets visibles et des métriques créées par l'utilisateur (sans doublons sur le nom)
    func metricsForFilter() -> [Metric] {
        let presets = defaultMetrics()
        var byName: [String: Metric] = [:]
        for m in presets { byName[m.name] = m }
        for m in state.metrics { byName[m.name] = m }
        // Retourner trié alpha pour une navigation plus simple
        return Array(byName.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var filterSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Métrique")) {
                    Picker("", selection: Binding(get: { filterMetricId ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID() }, set: { newVal in
                        // Using nil sentinel: all zeros UUID
                        let zero = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
                        filterMetricId = (newVal == zero) ? nil : newVal
                    })) {
                        Text("Toutes").tag(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
                        ForEach(metricsForFilter()) { m in Text(m.name).tag(m.id) }
                    }
                }
                Section(header: Text("Date")) {
                    Picker("", selection: $dateFilter) {
                        Text("Toutes").tag(DateFilter.all)
                        Text("Aujourd'hui").tag(DateFilter.today)
                        Text("7 derniers jours").tag(DateFilter.last7)
                        Text("30 derniers jours").tag(DateFilter.last30)
                    }
                    .pickerStyle(.segmented)
                }
                Section { Button("Réinitialiser", role: .destructive) { filterMetricId = nil; dateFilter = .all } }
            }
            .navigationTitle("Filtres")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Terminé") { showingFilter = false } } }
        }
    }
}

#Preview { TrackView().environmentObject(AppState()) }
