import SwiftUI

struct ProtocolOnboardingView: View {
    @Binding var isPresented: Bool
    let onCreate: (ProtocolItem) -> Void

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

    private let quickCategories = ["Cognition", "Énergie", "Récupération", "Sommeil", "Métabolisme"]

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
                Section { Button("Créer") { create() }.frame(maxWidth: .infinity, alignment: .center) }
            }
            .navigationTitle("Nouveau protocole")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { isPresented = false } } }
            .sheet(isPresented: $showingTemplates) {
                TemplatesSheet { tmpl in
                    name = tmpl.name
                    detail = tmpl.goal
                    category = tmpl.category
                    minutes = tmpl.minutes
                    frequency = tmpl.frequency
                    hour = tmpl.hour
                    minute = tmpl.minute
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
        }
        .withSheetDetentsIfAvailable()
    }

    private func create() {
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
        onCreate(item)
        if reminders {
            NotificationService.shared.scheduleDailyReminder(id: "protocol-\(item.id.uuidString)", title: item.name, hour: hour, minute: minute)
        }
        isPresented = false
    }

    private func labelForFrequency(_ f: Frequency) -> String {
        switch f {
        case .daily: return "Quotidienne"
        case .timesPerDay(let n): return n <= 1 ? "1 fois/jour" : "\(n) fois/jour"
        case .weekly(let days): return days.isEmpty ? "Si besoin" : "Jours spécifiques"
        }
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
