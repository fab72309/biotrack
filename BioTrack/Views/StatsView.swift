import SwiftUI
// Access ChartSeries/MultiSeriesChart

// Forward declaration removed; using the implementation in Components/MultiSeriesChart.swift

struct StatsView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedMetric: Metric?
    @State private var selectedMetricIds: Set<UUID> = []
    @State private var showTrackSheet = false
    enum Mode { case chart, calendar }
    @State private var mode: Mode = .chart
    enum Range { case d7, d30, d90, all }
    @State private var range: Range = .d30
    @State private var selectedProtocolId: UUID? = nil
    @State private var selectedSupplementId: UUID? = nil
    enum Grouping { case metrics, protocols, supplements }
    @State private var grouping: Grouping = .metrics
    enum ChartStyle { case line, bar }
    @State private var chartStyle: ChartStyle = .line
    @State private var showingExperimentWizard = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    selectMetricCard
                    timeAndFilters
                    mainPanel
                    correlationsPanel
                    experimentsPanel
                }
                .padding()
            }
            .navigationTitle("Statistiques")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingExperimentWizard = true }) {
                        Label("N-of-1", systemImage: "flask")
                    }
                }
            }
        }
        .sheet(isPresented: $showTrackSheet) { TrackView().environmentObject(state).withSheetDetentsIfAvailable() }
        .sheet(isPresented: $showingExperimentWizard) {
            NOf1WizardSheet(metrics: state.metrics) { input in
                state.createExperiment(input: input)
            }
            .withSheetDetentsIfAvailable()
        }
        .onAppear {
            if selectedMetric == nil {
                selectedMetric = metricsForSelection().first(where: { hasData(for: $0) }) ?? metricsForSelection().first
            }
            if selectedMetricIds.isEmpty, let first = selectedMetric { selectedMetricIds = [first.id] }
            state.refreshInsightsAndRecommendations()
        }
    }

    private var header: some View {
        HStack {
            Text("Visualisez l'évolution de vos données")
                .foregroundColor(.secondary)
            Spacer()
            Picker("", selection: $mode) {
                Label("Graphique", systemImage: "chart.bar").tag(Mode.chart)
                Label("Calendrier", systemImage: "calendar").tag(Mode.calendar)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
        }
    }

    private var selectMetricCard: some View {
        SurfaceCard {
            Text("Sélectionner une métrique").font(.headline)
            if metricsForSelection().isEmpty {
                VStack(spacing: 12) {
                    Text("Aucune métrique disponible").foregroundColor(.secondary)
                    Button(action: { showTrackSheet = true }) { Label("Ajouter des données", systemImage: "plus") }
                        .buttonStyle(.borderedProminent).tint(Color("Primary"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(metricsForSelection()) { m in
                            let isSelected = selectedMetricIds.contains(m.id)
                            let label = hasData(for: m) ? m.name : "\(m.name) · vide"
                            SelectableChip(
                                title: label,
                                selected: isSelected,
                                iconSystemName: nil,
                                tintColor: nil,
                                selectedBackgroundColor: Color(UIColor.secondarySystemBackground),
                                selectedForegroundColor: Color("Primary")
                            ) {
                                if isSelected { selectedMetricIds.remove(m.id) }
                                else if selectedMetricIds.count < 3 { selectedMetricIds.insert(m.id) }
                                if selectedMetric == nil { selectedMetric = m }
                            }
                            .opacity(isSelected || selectedMetricIds.count < 3 ? 1.0 : 0.5)
                            .disabled(!isSelected && selectedMetricIds.count >= 3)
                        }
                    }
                }
                Text("Les métriques marquées “vide” n'ont pas encore de donnée enregistrée.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var timeAndFilters: some View {
        SurfaceCard {
            Text("Période").font(.headline)
            HStack(spacing: 8) {
                SelectableChip(title: "7j", selected: range == .d7) { range = .d7 }
                SelectableChip(title: "30j", selected: range == .d30) { range = .d30 }
                SelectableChip(title: "90j", selected: range == .d90) { range = .d90 }
                SelectableChip(title: "Tout", selected: range == .all) { range = .all }
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Protocole").font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            SelectableChip(title: "Aucun", selected: selectedProtocolId == nil) { selectedProtocolId = nil }
                            ForEach(state.protocols) { p in
                                SelectableChip(title: p.name, selected: selectedProtocolId == p.id) { selectedProtocolId = p.id }
                            }
                        }
                    }
                }
                VStack(alignment: .leading) {
                    Text("Supplément").font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            SelectableChip(title: "Aucun", selected: selectedSupplementId == nil) { selectedSupplementId = nil }
                            ForEach(state.supplements) { s in
                                SelectableChip(title: s.name, selected: selectedSupplementId == s.id) { selectedSupplementId = s.id }
                            }
                        }
                    }
                }
            }
        }
    }

    private var mainPanel: some View {
        Group {
            if let m = selectedMetric {
                if mode == .chart {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Picker("", selection: $grouping) {
                                Text("Métriques").tag(Grouping.metrics)
                                Text("Protocoles").tag(Grouping.protocols)
                                Text("Suppléments").tag(Grouping.supplements)
                            }.pickerStyle(.segmented)
                            Spacer()
                            Picker("", selection: $chartStyle) {
                                Image(systemName: "waveform.path.ecg").tag(ChartStyle.line)
                                Image(systemName: "chart.bar").tag(ChartStyle.bar)
                            }.pickerStyle(.segmented).frame(maxWidth: 120)
                        }
                        // Use type defined in separate file; ensure symbol is visible by having same module
                        let metricsList = metricsListForDisplay(baseMetric: m)
                        let primaryMetric = metricsList.first ?? m
                        let isNormalizedComparison = shouldNormalizeMetricsComparison(metricsList: metricsList)
                        let series = buildSeries(from: metricsList, normalizeMetrics: isNormalizedComparison)
                        let forcedRange = isNormalizedComparison
                        ? (0.0 as Double?, 100.0 as Double?)
                        : forcedYRange(for: primaryMetric, series: series)
                        VStack(spacing: 8) {
                            // Légende au-dessus du graphique
                            legendRow(series: series)
                            MultiSeriesChart(series: series,
                                         style: chartStyle,
                                         unit: isNormalizedComparison ? "Indice (0-100)" : unitLabel(baseMetric: primaryMetric),
                                         yAxisMode: yAxisMode(for: primaryMetric, isNormalizedComparison: isNormalizedComparison),
                                         ticks: customTicks(),
                                         yMinForced: forcedRange.0,
                                         yMaxForced: forcedRange.1,
                                         valueFormatter: isNormalizedComparison ? nil : valueFormatterForMetric(primaryMetric),
                                         avgLineValue: isNormalizedComparison ? nil : averageValue(for: primaryMetric, series: series),
                                         showLegend: false)
                            .frame(height: 300)
                            .padding(.vertical, 6)
                            .padding(.bottom, 16) // éviter chevauchement avec "Moyenne sur la période"
                            averageRow(for: primaryMetric, series: series)
                        }
                        HStack {
                            Spacer()
                            Button("Exporter CSV") {
                            let csv = ExportService.csvMetrics(metrics: state.metrics, entries: filteredEntries(for: m))
                            share(text: csv)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    let (start, end) = dateBounds()
                    VStack(alignment: .leading, spacing: 12) {
                        SurfaceCard {
                            UnifiedCalendarView(days: rangeDays)
                                .environmentObject(state)
                        }
                        SurfaceCard {
                            Text("Heatmap métrique").font(.headline)
                            CalendarHeatmap(entries: filteredEntries(for: m), startDate: start, endDate: end)
                                .frame(height: 300)
                        }
                    }
                }
            } else {
                SurfaceCard {
                    EmptyStateView(text: "Choisissez une métrique pour afficher les données", systemImageName: "chart.bar")
                        .frame(maxWidth: .infinity, minHeight: 180)
                }
            }
        }
    }

    private var correlationsPanel: some View {
        SurfaceCard {
            HStack {
                Text("Corrélations locales").font(.headline)
                Spacer()
                Button("Rafraîchir") { state.refreshInsightsAndRecommendations() }
                    .buttonStyle(.bordered)
            }
            if state.correlationInsights.isEmpty {
                Text("Pas assez de données pour calculer des corrélations fiables.")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                ForEach(Array(state.correlationInsights.prefix(4))) { insight in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(metricName(for: insight.metricAId) + " ↔ " + metricName(for: insight.metricBId))
                            .font(.subheadline.weight(.semibold))
                        Text(insight.summary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "r=%.2f • n=%d • lag=%dj", insight.pearson, insight.sampleSize, insight.lagDays))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var experimentsPanel: some View {
        SurfaceCard {
            HStack {
                Text("Expériences N-of-1").font(.headline)
                Spacer()
                Button("Nouveau") { showingExperimentWizard = true }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("Primary"))
            }
            if state.experiments.isEmpty {
                Text("Aucune expérience en cours.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(state.experiments) { experiment in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(experiment.title).font(.subheadline.weight(.semibold))
                        Text(experiment.hypothesis).font(.caption).foregroundColor(.secondary)
                        HStack {
                            Button("Log aujourd'hui") {
                                logObservationToday(for: experiment)
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                            Spacer()
                            Text(experiment.status.rawValue.capitalized)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if let summary = state.experimentSummary(experimentId: experiment.id),
                           let control = summary.controlAverage,
                           let intervention = summary.interventionAverage {
                            Text(String(format: "%@: %.2f • %@: %.2f • Δ %.2f",
                                        experiment.controlLabel, control,
                                        experiment.interventionLabel, intervention,
                                        summary.delta ?? 0))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("En attente de mesures.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // Moyenne pour la période et le regroupement
    private func averageRow(for metric: Metric, series: [ChartSeries]) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text("Moyenne sur la période : ")
                .font(.subheadline).foregroundColor(.secondary)
            switch grouping {
            case .metrics:
                ForEach(series) { s in
                    let m = state.metrics.first(where: { $0.name == s.name }) ?? metric
                    let vals = filteredEntries(for: m).map { $0.value }
                    let avg = (vals.reduce(0, +) / max(Double(vals.count), 1))
                    HStack(spacing: 6) {
                        Circle().fill(s.color).frame(width: 8, height: 8)
                        Text("\(m.name): \(formatValue(avg, for: m))")
                    }.font(.subheadline.weight(.semibold))
                }
            case .protocols, .supplements:
                let all = series.flatMap { $0.points.map(\.displayValue) }
                let avg = (all.reduce(0, +) / max(Double(all.count), 1))
                Text(String(format: "%.1f / jour", avg)).font(.subheadline.weight(.semibold))
            }
        }
    }

    private func formatValue(_ v: Double, for m: Metric) -> String {
        let name = m.name.lowercased()
        if m.kind == .hoursMinutes || name.contains("sommeil") {
            let mins = max(0, Int(round(v)))
            let h = mins/60
            let mm = mins%60
            return String(format: "%dh%02d", h, mm)
        }
        if name.contains("poids") { return String(format: "%.1f %@", v, (m.unit ?? "kg")) }
        return String(format: "%.1f %@", v, (m.unit ?? ""))
    }

    private func averageValue(for m: Metric, series: [ChartSeries]) -> Double? {
        switch grouping {
        case .metrics:
            let vals = filteredEntries(for: m).map { $0.value }
            guard !vals.isEmpty else { return nil }
            return vals.reduce(0, +) / Double(vals.count)
        case .protocols, .supplements:
            let all = series.flatMap { $0.points.map(\.displayValue) }
            guard !all.isEmpty else { return nil }
            return all.reduce(0, +) / Double(all.count)
        }
    }

    private func rangeChip(_ title: String, _ value: Range) -> some View {
        Button(action: { range = value }) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(range == value ? Color("Primary") : Color(UIColor.secondarySystemBackground))
                .foregroundColor(range == value ? Color("OnPrimary") : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }.buttonStyle(.plain)
    }
    private func filterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(isSelected ? Color("Primary") : Color(UIColor.secondarySystemBackground))
                .foregroundColor(isSelected ? Color("OnPrimary") : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }.buttonStyle(.plain)
    }

    private func metricsWithData() -> [Metric] {
        let ids = Set(state.metricEntries.map { $0.metricId })
        return state.metrics.filter { ids.contains($0.id) }
    }

    private func metricsForSelection() -> [Metric] {
        state.metrics.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func hasData(for metric: Metric) -> Bool {
        state.metricEntries.contains(where: { $0.metricId == metric.id })
    }
    private func filteredEntries(for metric: Metric) -> [MetricEntry] {
        var entries = state.metricEntries.filter { $0.metricId == metric.id }
        let cal = Calendar.current
        switch range {
        case .d7:
            entries = entries.filter { $0.date >= cal.date(byAdding: .day, value: -7, to: Date())! }
        case .d30:
            entries = entries.filter { $0.date >= cal.date(byAdding: .day, value: -30, to: Date())! }
        case .d90:
            entries = entries.filter { $0.date >= cal.date(byAdding: .day, value: -90, to: Date())! }
        case .all:
            break
        }
        return entries.sorted { $0.date < $1.date }
    }

    // MARK: - Series building
    private func unitLabel(baseMetric: Metric) -> String {
        switch grouping {
        case .metrics: return baseMetric.unit ?? ""
        case .protocols, .supplements: return "occurrences"
        }
    }

    private func metricsListForDisplay(baseMetric: Metric) -> [Metric] {
        switch grouping {
        case .metrics:
            if selectedMetricIds.isEmpty { return [baseMetric] }
            // Ordre stable basé sur l’ordre des métriques dans l’état
            return state.metrics.filter { selectedMetricIds.contains($0.id) }
        case .protocols, .supplements:
            return []
        }
    }

    private func shouldNormalizeMetricsComparison(metricsList: [Metric]) -> Bool {
        guard grouping == .metrics, metricsList.count >= 2 else { return false }
        let compatibilityKeys = Set(metricsList.map(metricCompatibilityKey))
        return compatibilityKeys.count > 1
    }

    private func metricCompatibilityKey(_ metric: Metric) -> String {
        switch metric.kind {
        case .hoursMinutes:
            return "duration_minutes"
        case .number:
            return "number:\(normalizedUnit(metric.unit))"
        }
    }

    private func normalizedUnit(_ unit: String?) -> String {
        guard let unit else { return "" }
        return unit
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }

    private func yAxisMode(for baseMetric: Metric, isNormalizedComparison: Bool) -> MultiSeriesChart.YAxisMode {
        guard !isNormalizedComparison else { return .numeric }
        switch grouping {
        case .metrics:
            let normalizedName = baseMetric.name
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
            return (baseMetric.kind == .hoursMinutes || normalizedName.contains("sommeil")) ? .durationMinutes : .numeric
        case .protocols, .supplements:
            return .numeric
        }
    }

    private func tooltipUnit(for metric: Metric) -> String {
        let normalizedName = metric.name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        if metric.kind == .hoursMinutes || normalizedName.contains("sommeil") {
            return ""
        }
        return metric.unit ?? ""
    }

    private func buildSeries(from metricsList: [Metric], normalizeMetrics: Bool) -> [ChartSeries] {
        let cal = Calendar.current
        let startDate = dateBounds().0

        switch grouping {
        case .metrics:
            let palette = colorPalette()
            return metricsList.enumerated().map { idx, m in
                let entries = filteredEntries(for: m)
                let rawValues = entries.map(\.value)
                let minRaw = rawValues.min() ?? 0
                let maxRaw = rawValues.max() ?? 0
                let points = entries.map { entry -> ChartPoint in
                    let raw = entry.value
                    let display: Double
                    if normalizeMetrics {
                        if abs(maxRaw - minRaw) < 1e-6 {
                            display = 50
                        } else {
                            display = ((raw - minRaw) / (maxRaw - minRaw)) * 100
                        }
                    } else {
                        display = raw
                    }
                    return ChartPoint(date: entry.date, displayValue: display, rawValue: raw)
                }
                return ChartSeries(
                    name: m.name,
                    color: palette[idx % palette.count],
                    points: points,
                    rawUnit: tooltipUnit(for: m),
                    rawValueFormatter: valueFormatterForMetric(m)
                )
            }
        case .protocols:
            // construire une série 0/1 par protocole selon complétions (uniquement quand actif à la date)
            let ids = Set(state.protocolCompletions.map { $0.protocolId })
            let items = state.protocols.filter { ids.contains($0.id) }
            let palette = colorPalette()
            return items.enumerated().map { idx, p in
                let comps = state.protocolCompletions.filter { $0.protocolId == p.id && $0.date >= startDate && p.isActive(on: $0.date) }
                let grouped = Dictionary(grouping: comps) { cal.startOfDay(for: $0.date) }
                let points = grouped.keys.sorted().map { day in
                    let value = Double(grouped[day]?.filter { $0.completed }.count ?? 0)
                    return ChartPoint(date: day, displayValue: value, rawValue: value)
                }
                return ChartSeries(name: p.name, color: palette[idx % palette.count], points: points, rawUnit: "occurrences", rawValueFormatter: nil)
            }
        case .supplements:
            let ids = Set(state.supplementIntakes.map { $0.supplementId })
            let items = state.supplements.filter { ids.contains($0.id) }
            let palette = colorPalette()
            return items.enumerated().map { idx, s in
                let ints = state.supplementIntakes.filter { $0.supplementId == s.id && $0.date >= startDate && s.isActive(on: $0.date) }
                let grouped = Dictionary(grouping: ints) { cal.startOfDay(for: $0.date) }
                let points = grouped.keys.sorted().map { day in
                    let value = Double(grouped[day]?.filter { $0.taken }.count ?? 0)
                    return ChartPoint(date: day, displayValue: value, rawValue: value)
                }
                return ChartSeries(name: s.name, color: palette[idx % palette.count], points: points, rawUnit: "occurrences", rawValueFormatter: nil)
            }
        }
    }
    private func colorPalette() -> [Color] { [.blue, .green, .orange, .pink, .purple, .teal, .indigo, .brown, .mint, .red] }

    private func dateBounds() -> (Date, Date) {
        let cal = Calendar.current
        let end = Date()
        switch range {
        case .d7: return (cal.date(byAdding: .day, value: -7, to: end)!, end)
        case .d30: return (cal.date(byAdding: .day, value: -30, to: end)!, end)
        case .d90: return (cal.date(byAdding: .day, value: -90, to: end)!, end)
        case .all: return (Date.distantPast, end)
        }
    }

    private var rangeDays: Int {
        switch range {
        case .d7: return 7
        case .d30: return 30
        case .d90: return 90
        case .all: return 120
        }
    }

    private func metricName(for id: UUID) -> String {
        state.metrics.first(where: { $0.id == id })?.name ?? "—"
    }

    private func logObservationToday(for experiment: NOf1Experiment) {
        let todayEntries = state.metricEntries
            .filter { $0.metricId == experiment.targetMetricId && Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
        let fallbackEntries = state.metricEntries
            .filter { $0.metricId == experiment.targetMetricId }
            .sorted { $0.date > $1.date }
        let value = todayEntries.first?.value ?? fallbackEntries.first?.value ?? 0
        state.recordObservation(experimentId: experiment.id, value: value, date: Date(), notes: nil)
    }

    private func customTicks() -> [Date]? {
        let cal = Calendar.current
        let (start, end) = dateBounds()
        let days = max(1, Int((cal.startOfDay(for: end).timeIntervalSince1970 - cal.startOfDay(for: start).timeIntervalSince1970) / 86400))
        var step = 1
        if days <= 7 { step = 1 }
        else if days <= 30 { step = 5 }
        else if days <= 90 { step = 10 }
        else { step = days / 6 }
        var arr: [Date] = []
        var d = cal.startOfDay(for: start)
        while d <= end { arr.append(d); d = cal.date(byAdding: .day, value: step, to: d)! }
        arr.append(cal.startOfDay(for: end))
        return Array(Set(arr)).sorted()
    }

    // Forcer éventuellement une plage Y (sinon laisser dynamique au composant)
    private func forcedYRange(for m: Metric, series: [ChartSeries]) -> (Double?, Double?) {
        let name = m.name.lowercased()
        // Heures/minutes (ex: sommeil): bornes alignées sur des multiples de 30 minutes
        if m.kind == .hoursMinutes || name.contains("sommeil") {
            let values = series.flatMap { $0.points.map { max(0, $0.displayValue) } }
            guard let minVal0 = values.min(), let maxVal0 = values.max() else { return (0, 16*60) }
            let step: Double = 30
            var yMin = floor(minVal0 / step) * step
            var yMax = ceil(maxVal0 / step) * step
            if yMax - yMin < step * 4 { yMax = yMin + step * 4 } // au moins 2h de hauteur
            return (yMin, yMax)
        }
        if name.contains("poids") {
            // Optionnel: recadrer autour du poids courant si les variations sont faibles
            let entries = state.metricEntries.filter { $0.metricId == m.id }
            let values = entries.map { $0.value }
            if let base = values.last ?? values.first {
                return (base*0.9, base*1.1)
            }
        }
        return (nil, nil)
    }

    private func legendRow(series: [ChartSeries]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(series) { s in
                    HStack(spacing: 6) {
                        Circle().fill(s.color).frame(width: 8, height: 8)
                        Text(s.name).font(.caption)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func valueFormatterForMetric(_ m: Metric) -> ((Double) -> String)? {
        let name = m.name.lowercased()
        if m.kind == .hoursMinutes || name.contains("sommeil") {
            return { v in
                let mins = max(0, Int(round(v)))
                let h = mins / 60
                let mm = mins % 60
                return String(format: "%dh%02d", h, mm)
            }
        }
        if name.contains("poids") {
            return { v in String(format: "%.1f", v) }
        }
        if m.unit == "ms" {
            return { v in String(format: "%.1f", v) }
        }
        return { v in String(format: "%.0f", v) }
    }

    func share(text: String) {
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true)
    }
}

struct SimpleLineChart: View {
    let entries: [MetricEntry]
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let sorted = entries.sorted{ $0.date < $1.date }
            let values = sorted.map{$0.value}
            let maxV = max(values.max() ?? 1, 1)
            let points: [CGPoint] = sorted.enumerated().map { (idx, e) in
                let x = CGFloat(idx) / CGFloat(max(sorted.count-1,1)) * w
                let y = h - CGFloat(e.value / maxV) * h
                return CGPoint(x: x, y: y)
            }
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                for p in points.dropFirst() { path.addLine(to: p) }
            }
            .stroke(Color("Secondary"), lineWidth: 2)
        }
    }
}

#Preview { StatsView().environmentObject(AppState()) }
