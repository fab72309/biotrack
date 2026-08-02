import SwiftUI

struct ProtocolOnboardingView: View {
    @EnvironmentObject var state: AppState
    @Binding var isPresented: Bool
    let onCreate: (ProtocolItem, ReminderSheet.ReminderData?) -> Void

    @State private var name: String = ""
    @State private var detail: String = ""
    @State private var category: String = ""
    @State private var minutes: Int = 10
    @State private var hour: Int = 7
    @State private var minute: Int = 0
    @State private var reminders: Bool = false
    @State private var showingTemplates: Bool = false
    @State private var showingCategory: Bool = false
    @State private var showingFrequency: Bool = false
    @State private var showingTime: Bool = false
    @State private var frequency: Frequency = .daily
    @State private var showingCustomReminderSheet: Bool = false
    @State private var customReminderData: ReminderSheet.ReminderData? = nil
    @State private var didSelectTemplate: Bool = false
    @State private var pendingProtocolForCreate: ProtocolItem? = nil
    @State private var pendingReminderForCreate: ReminderSheet.ReminderData? = nil
    @State private var showSaveTemplatePrompt: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Modèles")) {
                    Button { showingTemplates = true } label: {
                        HStack {
                            Image(systemName: "square.grid.2x2")
                            Text("Choisir un modèle…")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                }
                Section(header: Text("Informations")) {
                    TextField("Nom", text: $name)
                    if !protocolSuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Suggestions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(protocolSuggestions) { suggestion in
                                Button(action: { applyProtocolSuggestion(suggestion) }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "sparkles")
                                            .font(.caption)
                                            .foregroundColor(Color("Primary"))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(suggestion.name)
                                                .font(.subheadline.weight(.semibold))
                                            Text("\(suggestion.category) • \(suggestion.minutes) min")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    TextField("Détail", text: $detail)
                    // Sélecteur de catégorie (feuille)
                    Button(action: { showingCategory = true }) {
                        HStack {
                            Text("Catégorie")
                            Spacer()
                            Text(category.isEmpty ? "Autre" : category).foregroundColor(.secondary)
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                    // Chips rapides supprimés pour éviter la redondance avec le sélecteur de catégorie
                    // Sélecteur de fréquence (feuille)
                    Button(action: { showingFrequency = true }) {
                        HStack {
                            Text("Fréquence")
                            Spacer()
                            Text(labelForFrequency(frequency)).foregroundColor(.secondary)
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                    Stepper(value: $minutes, in: 1...180) { Text("Durée cible: \(minutes) min") }
                    Button(action: { showingTime = true }) {
                        HStack {
                            Text("Heure préférée")
                            Spacer()
                            Text(String(format: "%02d:%02d", hour, minute)).foregroundColor(.secondary)
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                    Toggle("Activer les rappels (quotidiens)", isOn: $reminders)
                }
                Section(header: Text("Objectifs & Notes")) {
                    NavigationLink(destination: NotesGoalForm(detail: $detail)) {
                        HStack {
                            Image(systemName: "square.and.pencil")
                            Text("Renseigner objectif/notes")
                            Spacer()
                            if !detail.isEmpty { Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
                        }
                    }
                }
                Section(header: Text("Rappel personnalisé (optionnel)")) {
                    Button(action: { showingCustomReminderSheet = true }) {
                        HStack {
                            Image(systemName: "bell.badge")
                            Text(customReminderData == nil ? "Ajouter un rappel personnalisé" : "Modifier le rappel personnalisé")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                    if let reminder = customReminderData {
                        Text(customReminderSummary(reminder))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Supprimer le rappel", role: .destructive) {
                            customReminderData = nil
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    SheetHeader(
                        title: "Nouveau protocole",
                        leadingTitle: "Annuler",
                        onLeading: { isPresented = false },
                        trailingTitle: "Enregistrer",
                        onTrailing: { saveProtocol() },
                        trailingDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
            .sheet(isPresented: $showingTemplates) {
                TemplatesSheet { tmpl in
                    name = tmpl.name
                    detail = tmpl.goal
                    category = tmpl.category
                    minutes = tmpl.minutes
                    frequency = tmpl.frequency
                    hour = tmpl.hour
                    minute = tmpl.minute
                    didSelectTemplate = true
                }
            }
            .sheet(isPresented: $showingCategory) {
                ProtocolCategoryPickerSheet(currentSelection: category.isEmpty ? "Autre" : category) { sel in
                    category = sel
                }
                .withSheetDetentsIfAvailable()
            }
            .sheet(isPresented: $showingFrequency) {
                FrequencyPickerSheet(current: frequency) { f in frequency = f }
                .withSheetDetentsIfAvailable()
            }
            .sheet(isPresented: $showingTime) {
                PreferredHourPickerSheet(currentHour: hour, currentMinute: minute) { h, m in
                    hour = h; minute = m
                }
                .withSheetDetentsIfAvailable()
            }
            .sheet(isPresented: $showingCustomReminderSheet) {
                ReminderSheet(initialData: customReminderData ?? defaultCustomReminderData()) { data in
                    customReminderData = data
                }
                .withSheetDetentsIfAvailable()
            }
            .bioTrackChoice(
                isPresented: $showSaveTemplatePrompt,
                title: "Enregistrer dans les modèles ?",
                message: "Voulez-vous ajouter ce protocole à votre base de modèles personnalisés ?",
                primaryTitle: "Créer uniquement",
                secondaryTitle: "Créer + enregistrer le modèle",
                onCancel: {
                    pendingProtocolForCreate = nil
                    pendingReminderForCreate = nil
                },
                onPrimary: { finalizeCreate(saveAsTemplate: false) },
                onSecondary: { finalizeCreate(saveAsTemplate: true) }
            )
        }
        .withSheetDetentsIfAvailable()
    }

    private func saveProtocol() {
        let item = ProtocolItem(name: name.isEmpty ? "Protocole" : name,
                                 detail: detail.isEmpty ? nil : detail,
                                 goal: nil,
                                 intervention: nil,
                                 frequency: frequency,
                                 preferredHour: DateComponents(hour: hour, minute: minute),
                                 targetMinutes: minutes,
                                 notes: nil,
                                 remindersEnabled: reminders,
                                 isArchived: false,
                                 startDate: Date(),
                                 endDate: nil,
                                 active: true,
                                 activationSpans: [],
                                 category: category.isEmpty ? nil : category)

        if shouldProposeTemplateSave(for: item) {
            pendingProtocolForCreate = item
            pendingReminderForCreate = customReminderData
            showSaveTemplatePrompt = true
            return
        }
        finalizeCreate(item: item, reminder: customReminderData, saveAsTemplate: false)
    }

    private func finalizeCreate(saveAsTemplate: Bool) {
        guard let item = pendingProtocolForCreate else { return }
        finalizeCreate(item: item, reminder: pendingReminderForCreate, saveAsTemplate: saveAsTemplate)
        pendingProtocolForCreate = nil
        pendingReminderForCreate = nil
    }

    private func finalizeCreate(item: ProtocolItem, reminder: ReminderSheet.ReminderData?, saveAsTemplate: Bool) {
        if saveAsTemplate {
            _ = state.addProtocolTemplate(from: item)
        }
        // Always route protocol reminders through the persisted Reminder model so they can
        // be edited/cancelled later and don't become orphan notifications.
        let managedReminder = reminder ?? (reminders ? defaultCustomReminderData() : nil)
        onCreate(item, managedReminder)
        isPresented = false
    }

    private func shouldProposeTemplateSave(for item: ProtocolItem) -> Bool {
        guard !didSelectTemplate else { return false }
        let normalizedName = normalized(item.name)
        guard !normalizedName.isEmpty else { return false }

        let existsInBuiltIn = protocolTemplateLibrary.contains { normalized($0.name) == normalizedName }
        if existsInBuiltIn { return false }

        return !state.hasProtocolTemplate(named: item.name)
    }

    private func labelForFrequency(_ f: Frequency) -> String {
        switch f {
        case .daily: return "Quotidienne"
        case .timesPerDay(let n): return n <= 1 ? "1 fois/jour" : "\(n) fois/jour"
        case .weekly(let days): return days.isEmpty ? "Si besoin" : "Jours spécifiques"
        }
    }

    private var protocolSuggestions: [ProtocolTemplate] {
        let query = normalized(name)
        let compactQuery = compact(query)
        guard compactQuery.count >= 4 else { return [] }

        return availableProtocolTemplates
            .filter { template in
                let candidate = normalized(template.name)
                let compactCandidate = compact(candidate)
                guard compactCandidate != compactQuery else { return false }
                return candidate.contains(query) || compactCandidate.contains(compactQuery)
            }
            .sorted { lhs, rhs in
                let lhsName = normalized(lhs.name)
                let rhsName = normalized(rhs.name)
                let lhsPrefix = lhsName.hasPrefix(query)
                let rhsPrefix = rhsName.hasPrefix(query)
                if lhsPrefix != rhsPrefix { return lhsPrefix && !rhsPrefix }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            .prefix(5)
            .map { $0 }
    }

    private func applyProtocolSuggestion(_ template: ProtocolTemplate) {
        name = template.name
        if detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            detail = template.goal
        }
        if category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || category == "Autre" {
            category = template.category
        }
        if minutes == 10 {
            minutes = template.minutes
        }
        frequency = template.frequency
        hour = template.hour
        minute = template.minute
        didSelectTemplate = true
    }

    private func defaultCustomReminderData() -> ReminderSheet.ReminderData {
        let protocolName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let reminderTitle = protocolName.isEmpty ? "Lancer ce protocole" : "Lancer \(protocolName)"
        let defaultTime = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return ReminderSheet.ReminderData(
            title: reminderTitle,
            time: defaultTime,
            days: Set(1...7),
            description: "",
            notificationsEnabled: true
        )
    }

    private func customReminderSummary(_ data: ReminderSheet.ReminderData) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: data.time)
        let summaryTime = String(format: "%02d:%02d", comps.hour ?? 8, comps.minute ?? 0)
        let daysText = data.days.isEmpty ? "Tous les jours" : "\(data.days.count) jour(s)"
        return "\(data.title) • \(summaryTime) • \(daysText)"
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func compact(_ value: String) -> String {
        value.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private var availableProtocolTemplates: [ProtocolTemplate] {
        var merged: [ProtocolTemplate] = []
        var seen: Set<String> = []
        for template in protocolTemplateLibrary {
            let key = normalized(template.name)
            if seen.insert(key).inserted {
                merged.append(template)
            }
        }
        for custom in state.customProtocolTemplates {
            let key = normalized(custom.name)
            if seen.insert(key).inserted {
                let detail = custom.detail?.trimmingCharacters(in: .whitespacesAndNewlines)
                let fallbackDetail = "Modèle personnalisé"
                merged.append(
                    ProtocolTemplate(
                        id: "custom-\(custom.id.uuidString)",
                        name: custom.name,
                        goal: (detail?.isEmpty == false ? detail! : fallbackDetail),
                        intervention: (detail?.isEmpty == false ? detail! : fallbackDetail),
                        category: custom.category,
                        minutes: max(1, custom.minutes),
                        frequency: custom.frequency,
                        hour: max(0, min(custom.hour, 23)),
                        minute: max(0, min(custom.minute, 59)),
                        isUserDefined: true
                    )
                )
            }
        }
        return merged
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

// Form de notes/objectif
private struct NotesGoalForm: View {
    @Binding var detail: String

    var body: some View {
        Form {
            Section(header: Text("Objectif / Notes")) {
                TextEditor(text: $detail)
                    .frame(minHeight: 160)
            }
        }
        .navigationTitle("Objectifs & Notes")
    }
}

// MARK: - Feuilles dédiées (catégorie & heure)
private struct ProtocolCategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let currentSelection: String
    let onDone: (String) -> Void

    @State private var working: String = "Autre"

    private let categories = ["Cognition", "Énergie", "Récupération", "Sommeil", "Métabolisme", "Autre"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Annuler") { dismiss() }
                Spacer()
                Text("Sélectionner une catégorie").font(.headline)
                Spacer()
                Button("Terminé") { onDone(working); dismiss() }.font(.headline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(categories, id: \.self) { c in
                        VStack(spacing: 12) {
                            Image(systemName: iconForCategory(c))
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(working == c ? Color("OnPrimary") : colorForCategory(c))
                            Text(c).font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 96)
                        .padding(.vertical, 12)
                        .background(working == c ? Color("Primary") : Color(UIColor.secondarySystemBackground))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(working == c ? Color("Primary") : Color.clear, lineWidth: 2))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .onTapGesture { working = c }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .onAppear { working = currentSelection }
    }
}

private struct PreferredHourPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let currentHour: Int
    let currentMinute: Int
    let onDone: (Int, Int) -> Void

    @State private var workingDate: Date = Date()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Annuler") { dismiss() }
                Spacer()
                Text("Heure préférée").font(.headline)
                Spacer()
                Button("Terminé") {
                    let comps = Calendar.current.dateComponents([.hour, .minute], from: workingDate)
                    onDone(comps.hour ?? 7, comps.minute ?? 0)
                    dismiss()
                }.font(.headline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)

            VStack {
                if #available(iOS 15.0, *) {
                    DatePicker("", selection: $workingDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .padding(.vertical, 8)
                } else {
                    DatePicker("", selection: $workingDate, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .padding(.vertical, 8)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            var comps = DateComponents()
            comps.hour = currentHour
            comps.minute = currentMinute
            workingDate = Calendar.current.date(from: comps) ?? Date()
        }
    }
}
