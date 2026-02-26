import SwiftUI

struct DailyCheckInInput {
    var energy: Int
    var mood: Int
    var sleepQuality: Int?
    var stress: Int?
    var note: String
    var metricValues: [UUID: Double] = [:]
}

struct DailyCheckInSheet: View {
    let period: CheckInPeriod
    let existing: DailyCheckIn?
    let selectedMetrics: [Metric]
    let existingMetricValues: [UUID: Double]
    let onSave: (DailyCheckInInput) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var energy: Int = 7
    @State private var mood: Int = 7
    @State private var sleepQuality: Int = 7
    @State private var stress: Int = 4
    @State private var note: String = ""
    @State private var metricNumberValues: [UUID: String] = [:]
    @State private var metricScoreValues: [UUID: Int] = [:]
    @State private var metricDurationValues: [UUID: DurationParts] = [:]

    init(
        period: CheckInPeriod,
        existing: DailyCheckIn?,
        selectedMetrics: [Metric] = [],
        existingMetricValues: [UUID: Double] = [:],
        onSave: @escaping (DailyCheckInInput) -> Void
    ) {
        self.period = period
        self.existing = existing
        self.selectedMetrics = selectedMetrics
        self.existingMetricValues = existingMetricValues
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Énergie")) {
                    scorePicker(selection: $energy)
                }
                Section(header: Text("Humeur")) {
                    scorePicker(selection: $mood)
                }
                if period == .morning {
                    Section(header: Text("Sommeil perçu")) {
                        scorePicker(selection: $sleepQuality)
                    }
                } else {
                    Section(header: Text("Stress")) {
                        scorePicker(selection: $stress)
                    }
                }
                if !inputMetrics.isEmpty {
                    Section(header: Text("Métriques personnalisées (Suivi)")) {
                        ForEach(inputMetrics) { metric in
                            metricInputRow(metric)
                        }
                    }
                }
                Section(header: Text("Note (optionnel)")) {
                    TextEditor(text: $note).frame(minHeight: 90)
                }
            }
            .navigationTitle("Check-in \(period.displayName.lowercased())")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        onSave(
                            DailyCheckInInput(
                                energy: energy,
                                mood: mood,
                                sleepQuality: period == .morning ? sleepQuality : nil,
                                stress: period == .evening ? stress : nil,
                                note: note,
                                metricValues: mergedMetricValuesForSave()
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let existing {
                energy = existing.energy
                mood = existing.mood
                sleepQuality = existing.sleepQuality ?? sleepQuality
                stress = existing.stress ?? stress
                note = existing.note ?? ""
            }
            prefillCustomMetrics()
            ensureDefaultScoreMetrics()
        }
    }

    private func scorePicker(selection: Binding<Int>) -> some View {
        HStack {
            Stepper(value: selection, in: 1...10) {
                Text("\(selection.wrappedValue)/10")
                    .font(.headline)
            }
        }
    }

    @ViewBuilder
    private func metricInputRow(_ metric: Metric) -> some View {
        switch metric.kind {
        case .hoursMinutes:
            let binding = Binding<DurationParts>(
                get: { metricDurationValues[metric.id] ?? DurationParts() },
                set: { metricDurationValues[metric.id] = $0 }
            )
            VStack(alignment: .leading, spacing: 8) {
                Text(metric.name)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Heures")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker(
                            "Heures",
                            selection: Binding(
                                get: { binding.wrappedValue.hours },
                                set: { newValue in
                                    var value = binding.wrappedValue
                                    value.hours = newValue
                                    binding.wrappedValue = value
                                }
                            )
                        ) {
                            ForEach(0...16, id: \.self) { value in
                                Text("\(value) h").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .frame(height: 90)
                        .clipped()
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Minutes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker(
                            "Minutes",
                            selection: Binding(
                                get: { binding.wrappedValue.minutes },
                                set: { newValue in
                                    var value = binding.wrappedValue
                                    value.minutes = newValue
                                    binding.wrappedValue = value
                                }
                            )
                        ) {
                            ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) { value in
                                Text("\(value) min").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .frame(height: 90)
                        .clipped()
                    }
                }
            }
        case .number:
            if isScoreMetric(metric) {
                let binding = Binding<Int>(
                    get: { metricScoreValues[metric.id] ?? 7 },
                    set: { metricScoreValues[metric.id] = min(10, max(1, $0)) }
                )
                VStack(alignment: .leading, spacing: 6) {
                    Text(metric.name)
                        .font(.subheadline.weight(.semibold))
                    scorePicker(selection: binding)
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(metric.name)
                        if let unit = metric.unit, !unit.isEmpty {
                            Text(unit)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    TextField(
                        "Valeur",
                        text: Binding(
                            get: { metricNumberValues[metric.id] ?? "" },
                            set: { metricNumberValues[metric.id] = $0 }
                        )
                    )
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: 120)
                }
            }
        }
    }

    private func prefillCustomMetrics() {
        for metric in inputMetrics {
            guard let value = existingMetricValues[metric.id] else { continue }
            switch metric.kind {
            case .hoursMinutes:
                let total = Int(value.rounded())
                metricDurationValues[metric.id] = DurationParts(hours: max(0, total / 60), minutes: max(0, total % 60))
            case .number:
                if isScoreMetric(metric) {
                    metricScoreValues[metric.id] = min(10, max(1, Int(value.rounded())))
                } else {
                    metricNumberValues[metric.id] = formatNumber(value)
                }
            }
        }
    }

    private func parseMetricValues() -> [UUID: Double] {
        var result: [UUID: Double] = [:]
        for metric in inputMetrics {
            switch metric.kind {
            case .hoursMinutes:
                guard let duration = metricDurationValues[metric.id] else { continue }
                let totalMinutes = (duration.hours * 60) + duration.minutes
                if totalMinutes > 0 {
                    result[metric.id] = Double(totalMinutes)
                }
            case .number:
                if isScoreMetric(metric) {
                    guard let score = metricScoreValues[metric.id] else { continue }
                    result[metric.id] = Double(score)
                } else {
                    guard let raw = metricNumberValues[metric.id],
                          let parsed = parseNumber(raw) else { continue }
                    result[metric.id] = parsed
                }
            }
        }
        return result
    }

    private func mergedMetricValuesForSave() -> [UUID: Double] {
        var values = parseMetricValues()
        for metric in selectedMetrics {
            switch defaultMetricKind(for: metric) {
            case .energy:
                values[metric.id] = Double(energy)
            case .mood:
                values[metric.id] = Double(mood)
            case .sleepQuality:
                if period == .morning {
                    values[metric.id] = Double(sleepQuality)
                }
            case .stress:
                if period == .evening {
                    values[metric.id] = Double(stress)
                }
            case .none:
                break
            }
        }
        return values
    }

    private func parseNumber(_ raw: String) -> Double? {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    private func formatNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
            .replacingOccurrences(of: ".", with: ",")
    }

    private func ensureDefaultScoreMetrics() {
        for metric in inputMetrics where metric.kind == .number && isScoreMetric(metric) {
            if metricScoreValues[metric.id] == nil {
                metricScoreValues[metric.id] = 7
            }
        }
    }

    private func isScoreMetric(_ metric: Metric) -> Bool {
        guard metric.kind == .number else { return false }
        let unit = normalize(metric.unit ?? "")
        if unit.contains("1-10") || unit.contains("1/10") || unit.contains("sur10") {
            return true
        }
        let name = normalize(metric.name)
        return name.contains("humeur") || name.contains("mood")
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private var inputMetrics: [Metric] {
        selectedMetrics.filter {
            switch defaultMetricKind(for: $0) {
            case .none:
                return true
            case .sleepQuality:
                // Sleep quality is a default field only in the morning check-in.
                return period != .morning
            case .stress:
                // Stress is a default field only in the evening check-in.
                return period != .evening
            case .energy, .mood:
                return false
            }
        }
    }

    private enum DefaultMetricKind {
        case energy
        case mood
        case sleepQuality
        case stress
        case none
    }

    private func defaultMetricKind(for metric: Metric) -> DefaultMetricKind {
        guard metric.kind == .number else { return .none }
        let name = normalize(metric.name)
        if name.contains("energie") || name.contains("energy") {
            return .energy
        }
        if name.contains("humeur") || name.contains("mood") {
            return .mood
        }
        if name.contains("stress") {
            return .stress
        }
        if name.contains("qualitedusommeil") || name.contains("sleepquality") {
            return .sleepQuality
        }
        return .none
    }
}

private struct DurationParts: Equatable {
    var hours: Int = 0
    var minutes: Int = 0
}
