import SwiftUI

struct HomeView: View {
    @EnvironmentObject var state: AppState
    @AppStorage("selectedTab") private var selectedTab: Int = 0

    @State private var selectedProtocol: ProtocolItem? = nil
    @State private var selectedSupplement: Supplement? = nil

    @State private var showSettings = false
    @State private var showingObjectives = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    remindersCard
                    objectivesCard
                    protocolsSection
                    supplementsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("BioTrack")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showSettings = true }) { Image(systemName: "gearshape") }
                }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView().withSheetDetentsIfAvailable() }
        .sheet(item: $selectedProtocol) { item in
            ProtocolLogSheet(item: item) { completed, note in
                if completed {
                    let completion = ProtocolCompletion(protocolId: item.id, date: Date(), completed: true)
                    state.protocolCompletions.append(completion)
                    state.save()
                }
            }.withSheetDetentsIfAvailable()
        }
        .sheet(item: $selectedSupplement) { sup in
            SupplementLogSheet(supplement: sup) { taken, note in
                if taken {
                    let intake = SupplementIntake(supplementId: sup.id, date: Date(), taken: true)
                    state.supplementIntakes.append(intake)
                    state.save()
                }
            }.withSheetDetentsIfAvailable()
        }
        .sheet(isPresented: $showingReminder) {
            ReminderSheet { data in
                // Persist the reminder locally
                let comps = Calendar.current.dateComponents([.hour, .minute], from: data.time)
                let r = Reminder(title: data.title,
                                  hour: comps.hour ?? 8,
                                  minute: comps.minute ?? 0,
                                  weekdays: Array(data.days).sorted(),
                                  notes: data.description,
                                  enabled: data.notificationsEnabled)
                state.reminders.append(r)
                state.save()

                NotificationService.shared.getAuthorizationStatus { status in
                    let comps = Calendar.current.dateComponents([.hour, .minute], from: data.time)
                    let hour = comps.hour ?? 8
                    let minute = comps.minute ?? 0
                    if data.notificationsEnabled && (status == .authorized || status == .provisional || status == .ephemeral) {
                        if data.days.isEmpty {
                            NotificationService.shared.scheduleDailyReminder(id: UUID().uuidString, title: data.title, hour: hour, minute: minute)
                        } else {
                            for d in data.days { NotificationService.shared.scheduleWeeklyReminder(id: UUID().uuidString, title: data.title, hour: hour, minute: minute, weekday: d) }
                        }
                    }
                }
            }.withSheetDetentsIfAvailable()
        }
    }

    private var header: some View {
        HStack {
            Text("Votre Checklist quotidienne")
                .font(.title3.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)
                .truncationMode(.tail)
            Spacer()
            Text(Date(), style: .date)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(Capsule())
        }
    }

    private var remindersCard: some View {
        SurfaceCard {
            HStack {
                Text("Rappels pour aujourd'hui").font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                Spacer()
                Button("Gérer") { showingManageReminders = true }
            }
            VStack(spacing: 8) {
                if state.reminders.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bell").font(.title3).foregroundColor(.secondary)
                        Text("Aucun rappel").foregroundColor(.secondary)
                        Button("Ajouter un rappel") { showingReminder = true }
                            .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 120)
                } else {
                    ForEach(sortedReminders.prefix(3)) { r in
                        HStack {
                            Image(systemName: r.enabled ? "bell.fill" : "bell.slash")
                                .foregroundColor(r.enabled ? Color("Primary") : .secondary)
                                .imageScale(.small)
                            Text(r.title)
                            Spacer()
                            Text(String(format: "%02d:%02d", r.hour, r.minute))
                                .foregroundColor(.secondary)
                            Toggle("", isOn: Binding(
                                get: { r.enabled },
                                set: { newValue in
                                    if let idx = state.reminders.firstIndex(where: { $0.id == r.id }) {
                                        state.reminders[idx].enabled = newValue
                                        state.save()
                                    }
                                }
                            ))
                            .labelsHidden()
                        }
                    }
                }
            }
        }
    }
    @State private var showingReminder = false
    @State private var showingManageReminders = false

    // MARK: - Objectifs (Progress Card)
    private var objectivesCard: some View {
        let total = objectivesTotalToday()
        let done = objectivesDoneToday()
        let progress = total == 0 ? 0.0 : Double(done) / Double(total)
        return SurfaceCard {
            HStack {
                Text("Objectifs").font(.headline)
                Spacer()
            }
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color("Primary").opacity(0.25), Color("Primary").opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(height: 80)
                GeometryReader { geo in
                    let width = geo.size.width
                    let fillWidth = CGFloat(progress) * width
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color("Primary"), Color("Primary").opacity(0.7)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: max(0, fillWidth), height: 80)
                        .opacity(progress <= 0 ? 0 : 1)
                        .animation(.easeInOut(duration: 0.25), value: progress)

                    // Infos centrées dans la jauge (texte seul)
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f%%", progress * 100))
                            .font(.headline.weight(.bold))
                            .foregroundColor(.primary)
                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 0)
                        Text("\(done)/\(total) objectifs réalisés")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.primary.opacity(0.9))
                            .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 80)
            }
            // Ligne d’info enlevée car désormais affichée dans la barre
        }
        .contentShape(Rectangle())
        .onTapGesture { showingObjectives = true }
        .sheet(isPresented: $showingObjectives) {
            ObjectivesDetailPopup()
                .environmentObject(state)
        }
    }

    private var protocolsSection: some View {
        SurfaceCard {
            HStack {
                Text("Protocoles à suivre aujourd'hui").font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedTab = 3 }
                Spacer()
                Button("Voir tous") { selectedTab = 3 }
            }
            VStack(spacing: 12) {
                ForEach(protocolsScheduledToday().prefix(3)) { p in
                    HStack(spacing: 12) {
                        checkBox(isOn: isProtocolDoneToday(p)) {
                            toggleProtocol(p)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.name)
                                .font(.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .overlay(
                                    Group { if isProtocolDoneToday(p) { Rectangle().fill(Color.clear) } }
                                )
                                .modifier(StrikethroughCompat(active: isProtocolDoneToday(p)))
                            Text(label(for: p.frequency))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedTab = 3 }
                        }
                        Spacer()
                        Button { selectedProtocol = p } label: { Image(systemName: "chevron.right").foregroundColor(.secondary) }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(UIColor.secondarySystemBackground)))
                    .contentShape(Rectangle())
                    .onTapGesture { selectedTab = 3 }
                }
                progressRow(done: protocolsDoneCount(), total: max(1, protocolsScheduledToday().count))
            }
        }
        .sheet(isPresented: $showingManageReminders) { ManageRemindersSheet().environmentObject(state) }
    }

    private var supplementsSection: some View {
        SurfaceCard {
            HStack {
                Text("Compléments à prendre aujourd'hui").font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .truncationMode(.tail)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedTab = 4 }
                Spacer()
                Button("Voir tous") { selectedTab = 4 }
            }
            VStack(spacing: 12) {
                ForEach(supplementsScheduledToday().prefix(5)) { s in
                    HStack(spacing: 12) {
                        checkBox(isOn: isSupplementTakenToday(s)) {
                            toggleSupplement(s)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                if let cat = s.category {
                                    Image(systemName: categoryIconName(for: cat))
                                        .imageScale(.medium)
                                        .foregroundColor(categoryColor(for: cat))
                                }
                                Text(s.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                    .modifier(StrikethroughCompat(active: isSupplementTakenToday(s)))
                            }
                            HStack(spacing: 6) {
                                if let dose = s.dose { Text(dose) }
                                if let t = s.timeContext ?? (s.timeOfDay != nil ? "matin" : nil) { Text("• \(t)") }
                            }
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedTab = 4 }
                        }
                        Spacer()
                        Button { selectedSupplement = s } label: { Image(systemName: "chevron.right").foregroundColor(.secondary) }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(UIColor.secondarySystemBackground)))
                    .contentShape(Rectangle())
                    .onTapGesture { selectedTab = 4 }
                }
                progressRow(done: supplementsDoneCount(), total: max(1, supplementsScheduledToday().count))
            }
        }
    }

    private func progressRow(done: Int, total: Int) -> some View {
        HStack(spacing: 8) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color(UIColor.secondarySystemFill))
                    .frame(height: 4)
                GeometryReader { geo in
                    let ratio = total == 0 ? 0.0 : min(1.0, Double(done) / Double(total))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color("Primary"))
                        .frame(width: CGFloat(ratio) * geo.size.width, height: 4)
                        .animation(.easeInOut(duration: 0.25), value: ratio)
                }
            }
            .frame(height: 4)
            .frame(maxWidth: .infinity)

            Text("\(done) sur \(total) complété")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }

    private func label(for frequency: Frequency) -> String {
        switch frequency {
        case .daily: return "Quotidien"
        case .weekly(let days):
            let map = [1:"Lun",2:"Mar",3:"Mer",4:"Jeu",5:"Ven",6:"Sam",7:"Dim"]
            return days.map { map[$0] ?? "" }.joined(separator: ", ")
        case .timesPerDay(let n): return n <= 1 ? "Quotidien" : "\(n)x / jour"
        }
    }

    // MARK: - Checkboxes and state
    private func checkBox(isOn: Bool, toggle: @escaping () -> Void) -> some View {
        Button(action: toggle) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isOn ? Color("Primary") : Color(UIColor.separator), lineWidth: 2)
                    .background(isOn ? Color("Primary").opacity(0.15) : Color.clear)
                    .frame(width: 24, height: 24)
                if isOn { Image(systemName: "checkmark").font(.footnote).foregroundColor(Color("Primary")) }
            }
        }
        .buttonStyle(.plain)
    }

    private func isProtocolDoneToday(_ item: ProtocolItem) -> Bool {
        state.protocolCompletions.contains { $0.protocolId == item.id && Calendar.current.isDateInToday($0.date) && $0.completed }
    }

    private func isSupplementTakenToday(_ s: Supplement) -> Bool {
        state.supplementIntakes.contains { $0.supplementId == s.id && Calendar.current.isDateInToday($0.date) && $0.taken }
    }

    private func toggleProtocol(_ item: ProtocolItem) {
        if let idx = state.protocolCompletions.firstIndex(where: { $0.protocolId == item.id && Calendar.current.isDateInToday($0.date) }) {
            state.protocolCompletions.remove(at: idx)
        } else {
            let completion = ProtocolCompletion(protocolId: item.id, date: Date(), completed: true)
            state.protocolCompletions.append(completion)
        }
        state.save()
    }

    private func toggleSupplement(_ s: Supplement) {
        if let idx = state.supplementIntakes.firstIndex(where: { $0.supplementId == s.id && Calendar.current.isDateInToday($0.date) }) {
            state.supplementIntakes.remove(at: idx)
        } else {
            let intake = SupplementIntake(supplementId: s.id, date: Date(), taken: true)
            state.supplementIntakes.append(intake)
        }
        state.save()
    }

    private func protocolsDoneCount() -> Int { protocolsScheduledToday().filter { isProtocolDoneToday($0) }.count }
    private func supplementsDoneCount() -> Int { supplementsScheduledToday().filter { isSupplementTakenToday($0) }.count }

    private func categoryIconName(for category: String) -> String {
        let key = category.lowercased()
        switch key {
        case "nootropiques", "nootropics": return "brain.head.profile"
        case "vitamines", "vitamins": return "asterisk.circle"
        case "minéraux", "minerals": return "flask"
        case "protéines", "proteins", "protéine": return "dumbbell"
        case "énergie", "energy": return "bolt"
        case "récupération", "recovery": return "heart"
        case "sommeil", "sleep": return "moon"
        case "digestif", "digestive": return "fork.knife"
        case "immunité", "immune": return "shield"
        case "traitement médical", "traitement", "medical": return "pills"
        default: return "circle.grid.3x3"
        }
    }

    private func categoryColor(for category: String) -> Color {
        let key = category.lowercased()
        switch key {
        case "nootropiques", "nootropics": return .purple
        case "vitamines", "vitamins": return .yellow
        case "minéraux", "minerals": return .teal
        case "protéines", "proteins", "protéine": return .orange
        case "énergie", "energy": return .pink
        case "récupération", "recovery": return .green
        case "sommeil", "sleep": return .indigo
        case "digestif", "digestive": return .brown
        case "immunité", "immune": return .mint
        case "traitement médical", "traitement", "medical": return .red
        default: return .secondary
        }
    }

    private var sortedReminders: [Reminder] {
        state.reminders.sorted { a, b in
            if a.hour == b.hour { return a.minute < b.minute }
            return a.hour < b.hour
        }
    }

    private func objectivesTotalToday() -> Int {
        let protocolsCount = protocolsScheduledToday().count
        let supplementsCount = supplementsScheduledToday().count
        return protocolsCount + supplementsCount
    }

    private func objectivesDoneToday() -> Int {
        let protocolsDone = protocolsDoneCount()
        let supplementsDone = supplementsDoneCount()
        return protocolsDone + supplementsDone
    }
    private func currentWeekdayMon1ToSun7() -> Int {
        // Calendar .weekday: 1=Sun ... 7=Sat → convert to Mon=1 ... Sun=7
        let wd = Calendar.current.component(.weekday, from: Date())
        return ((wd + 5) % 7) + 1
    }

    private func isScheduledToday(_ frequency: Frequency, daysFallback: [Int]?) -> Bool {
        switch frequency {
        case .daily: return true
        case .timesPerDay: return true
        case .weekly(let days):
            let set = Set((!days.isEmpty ? days : (daysFallback ?? [])).map { $0 })
            if set.isEmpty { return true }
            return set.contains(currentWeekdayMon1ToSun7())
        }
    }

    private func protocolsScheduledToday() -> [ProtocolItem] {
        state.protocols.filter { item in
            guard item.isActive(on: Date()) else { return false }
            switch item.frequency {
            case .daily: return true
            case .timesPerDay: return true
            case .weekly(let days):
                let set = Set(days)
                if set.isEmpty { return true }
                return set.contains(currentWeekdayMon1ToSun7())
            }
        }
    }

    private func supplementsScheduledToday() -> [Supplement] {
        state.supplements.filter { s in
            guard s.isActive(on: Date()) else { return false }
            return isScheduledToday(s.frequency, daysFallback: s.daysOfWeek)
        }
    }
}

#Preview {
    HomeView().environmentObject(AppState())
}


