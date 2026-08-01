import SwiftUI

struct ObjectivesDetailSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var pageIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(titleForPage(pageIndex))
                    .font(.headline)
                Spacer()
                Button("Fermer") { dismiss() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)

            ObjectivesDetailContent(pageIndex: $pageIndex)
                .environmentObject(state)

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { idx in
                    Circle()
                        .fill(idx == pageIndex ? Color("Primary") : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 8)
        }
        .withSheetDetentsIfAvailable()
    }

    private func titleForPage(_ index: Int) -> String {
        switch index { case 0: return "Aujourd'hui"; case 1: return "7 derniers jours"; default: return "30 derniers jours" }
    }

}

struct ObjectivesDetailContent: View {
    @EnvironmentObject var state: AppState
    @Binding var pageIndex: Int

    var body: some View {
        TabView(selection: $pageIndex) {
            todayView.tag(0)
            periodListView(days: 7).tag(1)
            periodListView(days: 30).tag(2)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }

    private var todayView: some View {
        let remainingCheckIns = CheckInPeriod.allCases.filter { !isCheckInDone(on: Date(), period: $0) }
        let todaysProtocols = scheduledProtocolsToday()
        let todaysSupplements = scheduledSupplementsToday()
        let completedProtocols = todaysProtocols.filter { isProtocolDone(on: Date(), item: $0) }.sorted { $0.name < $1.name }
        let completedSupps = todaysSupplements.filter { isSupplementDone(on: Date(), item: $0) }.sorted { $0.name < $1.name }
        let remainingProtocols = todaysProtocols.filter { !isProtocolDone(on: Date(), item: $0) }.sorted { $0.name < $1.name }
        let remainingSupps = todaysSupplements.filter { !isSupplementDone(on: Date(), item: $0) }.sorted { $0.name < $1.name }
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if remainingCheckIns.isEmpty && remainingProtocols.isEmpty && remainingSupps.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color("Primary"))
                        Text("Tout est à jour pour aujourd'hui")
                            .font(.subheadline.weight(.semibold))
                        Text("Les objectifs terminés apparaîtront ci-dessous.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                if !remainingCheckIns.isEmpty {
                    Text("Check-ins").font(.subheadline.weight(.semibold)).padding(.horizontal, 16)
                    ForEach(remainingCheckIns) { period in
                        statusRow(
                            title: "Check-in du \(period == .morning ? "matin" : "soir")",
                            subtitle: "À compléter aujourd'hui",
                            systemImage: "square.and.pencil"
                        )
                    }
                }
                if !remainingProtocols.isEmpty {
                    Text("Protocoles").font(.subheadline.weight(.semibold)).padding(.horizontal, 16).padding(.top, remainingCheckIns.isEmpty ? 0 : 8)
                    ForEach(remainingProtocols) { p in
                        interactiveCompactRow(title: p.name, isDone: false) {
                            toggleProtocol(p)
                        }
                    }
                }
                if !remainingSupps.isEmpty {
                    Text("Compléments").font(.subheadline.weight(.semibold)).padding(.horizontal, 16).padding(.top, 8)
                    ForEach(remainingSupps) { s in
                        interactiveCompactRow(title: s.name, isDone: false) {
                            toggleSupplement(s)
                        }
                    }
                }
                // Complétés en bas
                if !completedProtocols.isEmpty || !completedSupps.isEmpty {
                    Text("Complétés").font(.subheadline.weight(.semibold)).padding(.horizontal, 16).padding(.top, 8)
                    ForEach(completedProtocols) { p in
                        interactiveCompactRow(title: p.name, isDone: true) { toggleProtocol(p) }
                    }
                    ForEach(completedSupps) { s in
                        interactiveCompactRow(title: s.name, isDone: true) { toggleSupplement(s) }
                    }
                }
            }
            .padding(.vertical, 14)
        }
    }

    private func periodListView(days: Int) -> some View {
        let calendar = Calendar.current
        let dates: [Date] = (0..<days).compactMap { calendar.date(byAdding: .day, value: -$0, to: Date()) }.sorted()
        return ScrollView {
            VStack(spacing: 8) {
                ForEach(dates, id: \.self) { d in
                    let total = objectivesTotal()
                    let done = objectivesDone(on: d)
                    let percent = total == 0 ? 0.0 : Double(done) / Double(total)
                    HStack(spacing: 10) {
                        Text(dateLabel(d))
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.0f%%", percent * 100))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(done)/\(total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color("Surface"))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color("Separator"), lineWidth: 0.5)
                            .padding(.horizontal, 16)
                    )
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func dateLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: d)
    }
    private func objectivesTotal() -> Int { state.protocols.count + state.supplements.count }
    private func objectivesDone(on date: Date) -> Int {
        let protocolsDone = state.protocolCompletions.filter { Calendar.current.isDate($0.date, inSameDayAs: date) && $0.completed }.count
        let suppsDone = state.supplementIntakes.filter { Calendar.current.isDate($0.date, inSameDayAs: date) && $0.taken }.count
        return protocolsDone + suppsDone
    }
    private func isProtocolDone(on date: Date, item: ProtocolItem) -> Bool {
        state.protocolCompletions.contains { $0.protocolId == item.id && Calendar.current.isDate($0.date, inSameDayAs: date) && $0.completed }
    }
    private func isSupplementDone(on date: Date, item: Supplement) -> Bool {
        state.supplementIntakes.contains { $0.supplementId == item.id && Calendar.current.isDate($0.date, inSameDayAs: date) && $0.taken }
    }
    private func isCheckInDone(on date: Date, period: CheckInPeriod) -> Bool {
        state.dailyCheckIns.contains {
            $0.period == period && Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    private func currentWeekdayMon1ToSun7() -> Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return ((weekday + 5) % 7) + 1
    }

    private func isScheduledToday(_ frequency: Frequency, daysFallback: [Int]?) -> Bool {
        switch frequency {
        case .daily:
            return true
        case .timesPerDay:
            return true
        case .weekly(let days):
            let set = Set((!days.isEmpty ? days : (daysFallback ?? [])).map { $0 })
            if set.isEmpty { return true }
            return set.contains(currentWeekdayMon1ToSun7())
        }
    }

    private func scheduledProtocolsToday() -> [ProtocolItem] {
        let profile = state.currentRoutineProfile()
        let base = state.protocols.filter { item in
            guard item.isActive(on: Date()) else { return false }
            switch item.frequency {
            case .daily, .timesPerDay:
                return true
            case .weekly(let days):
                let set = Set(days)
                if set.isEmpty { return true }
                return set.contains(currentWeekdayMon1ToSun7())
            }
        }
        return DailyPlanner.applyProfileFilters(to: base, profile: profile)
    }

    private func scheduledSupplementsToday() -> [Supplement] {
        let profile = state.currentRoutineProfile()
        let base = state.supplements.filter { item in
            guard item.isActive(on: Date()) else { return false }
            return isScheduledToday(item.frequency, daysFallback: item.daysOfWeek)
        }
        return DailyPlanner.applyProfileFilters(to: base, profile: profile)
    }

    // Toggle helpers (compact interaction in popup)
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
}

// Compact rows with checkbox
private extension ObjectivesDetailContent {
    func statusRow(title: String, subtitle: String? = nil, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color("Primary"))
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color("Surface"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color("Separator"), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
    }

    func interactiveCompactRow(title: String, isDone: Bool, toggle: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Button(action: toggle) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isDone ? Color("Primary") : Color("Separator"), lineWidth: 2)
                        .background(isDone ? Color("Primary").opacity(0.15) : Color.clear)
                        .frame(width: 22, height: 22)
                    if isDone { Image(systemName: "checkmark").font(.caption2).foregroundColor(Color("Primary")) }
                }
            }
            .buttonStyle(.plain)
            Text(title)
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color("Surface"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isDone ? Color("Primary").opacity(0.35) : Color("Separator"), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
    }
}

// Objectives detail presented as a native sheet. The sheet owns the surface;
// no second dimmed card is drawn inside it.
struct ObjectivesDetailPopup: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var pageIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 14)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Objectifs")
                        .font(.title3.weight(.bold))
                    Text(titleForPage(pageIndex))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                BioTrackModalCloseButton { dismiss() }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 16) {
                ProgressCircle(days: daysFor(pageIndex))
                    .environmentObject(state)
                    .frame(width: 112, height: 112)

                VStack(alignment: .leading, spacing: 6) {
                    Label("Progression", systemImage: "chart.pie.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("Primary"))
                    Text("Objectifs réalisés")
                        .font(.headline)
                    Text("Sur la période sélectionnée")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color("Background"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color("Separator"), lineWidth: 0.5)
            )
            .padding(.horizontal, 20)
            .padding(.top, 18)

            ObjectivesDetailContent(pageIndex: $pageIndex)
                .environmentObject(state)
                .frame(maxHeight: .infinity)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { idx in
                    let label = ["Aujourd'hui", "7 jours", "30 jours"][idx]
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { pageIndex = idx }
                    } label: {
                        Text(label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(idx == pageIndex ? Color("OnPrimary") : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(idx == pageIndex ? Color("Primary") : Color("Background"))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(idx == pageIndex ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(Color("Background").ignoresSafeArea())
        .withSheetDetentsIfAvailable()
    }

    private func titleForPage(_ index: Int) -> String {
        switch index { case 0: return "Aujourd'hui"; case 1: return "7 derniers jours"; default: return "30 derniers jours" }
    }

    private func daysFor(_ index: Int) -> Int {
        switch index { case 0: return 1; case 1: return 7; default: return 30 }
    }
}

// Circular progress header
private struct ProgressCircle: View {
    @EnvironmentObject var state: AppState
    var days: Int = 1

    private var total: Int {
        let perDay = state.protocols.count + state.supplements.count
        return max(1, perDay * max(1, days))
    }
    private var done: Int {
        let calendar = Calendar.current
        if days <= 1 {
            let protocolIds = Set(state.protocolCompletions.filter { calendar.isDateInToday($0.date) && $0.completed }.map { $0.protocolId })
            let supplementIds = Set(state.supplementIntakes.filter { calendar.isDateInToday($0.date) && $0.taken }.map { $0.supplementId })
            return protocolIds.count + supplementIds.count
        } else {
            let dates: [Date] = (0..<days).compactMap { calendar.date(byAdding: .day, value: -$0, to: Date()) }
            var totalDone = 0
            for d in dates {
                let p = Set(state.protocolCompletions.filter { calendar.isDate($0.date, inSameDayAs: d) && $0.completed }.map { $0.protocolId }).count
                let s = Set(state.supplementIntakes.filter { calendar.isDate($0.date, inSameDayAs: d) && $0.taken }.map { $0.supplementId }).count
                totalDone += (p + s)
            }
            return totalDone
        }
    }
    private var progress: Double { total == 0 ? 0 : Double(done) / Double(total) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color("Separator").opacity(0.65), lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(LinearGradient(colors: [Color("Primary"), Color("Primary").opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
            VStack(spacing: 4) {
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.title3.weight(.bold))
                Text("\(done)/\(total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progression des objectifs")
        .accessibilityValue("\(Int(progress * 100)) pour cent, \(done) sur \(total)")
    }
}
