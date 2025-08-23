import SwiftUI

struct ProtocolsView: View {
    @EnvironmentObject var state: AppState
    @State private var showingAdd = false
    @State private var editingProtocol: ProtocolItem? = nil
    @State private var searchText: String = ""
    @State private var showingFilters = false
    @State private var scope: ProtocolFilterScope = .active
    @State private var statusFilter: ProtocolStatusFilter = .all
    @State private var toDeleteProtocol: ProtocolItem? = nil
    @State private var showDeleteAlert: Bool = false
    @State private var selectedCategory: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 8) {
                    // Search + Filter row
                    HStack(spacing: 8) {
                        SearchField(placeholder: "Rechercher des protocoles...", text: $searchText)
                            .frame(maxWidth: .infinity)
                        Button(action: { showingFilters = true }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .imageScale(.large)
                        }
                        .accessibilityLabel("Filtrer")
                        .overlay(alignment: .topTrailing) {
                            if isFilterActive {
                                Circle().fill(Color("Primary")).frame(width: 8, height: 8).offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                    // Catégories (chips)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            SelectableChip(title: "Toutes", selected: selectedCategory == nil) { selectedCategory = nil }
                            ForEach(protocolCategories(), id: \.self) { c in
                                SelectableChip(title: c,
                                               selected: selectedCategory == c,
                                               iconSystemName: CategoryAppearance.iconName(for: c),
                                               tintColor: CategoryAppearance.color(for: c)) {
                                    selectedCategory = c
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    List {
                        ForEach(groupedProtocols().keys.sorted(), id: \.self) { cat in
                            Section(header: sectionHeader(for: cat)) {
                                ForEach(groupedProtocols()[cat] ?? []) { p in
                                    SwipeableRow(onEdit: {
                                        editingProtocol = p
                                    }, onDelete: {
                                        toDeleteProtocol = p
                                        showDeleteAlert = true
                                    }) {
                                        HStack(alignment: .top, spacing: 10) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(p.name).font(.headline)
                                                if let detail = p.detail { Text(detail).foregroundColor(.secondary) }
                                            }
                                            Spacer(minLength: 8)
                                            Button(action: { state.toggleProtocolActivation(p.id) }) {
                                                Text(p.active ? "Activé" : "Inactif")
                                                    .font(.caption2.weight(.semibold))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background((p.active ? Color("Primary") : Color.gray).opacity(0.15))
                                                    .foregroundColor(p.active ? Color("Primary") : .gray)
                                                    .clipShape(Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.vertical, 8)
                                    }
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                FloatingActionButton { showingAdd = true }
                    .padding(.trailing, 24)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .navigationTitle(Text(NSLocalizedString("tab.protocols", comment: "")))
            .sheet(isPresented: $showingFilters) {
                ProtocolFilterSheet(currentScope: scope, currentStatus: statusFilter) { newScope, newStatus in
                    scope = newScope
                    statusFilter = newStatus
                }
                .withSheetDetentsIfAvailable()
            }
            .sheet(isPresented: $showingAdd) {
                ProtocolOnboardingView(isPresented: $showingAdd) { newItem in
                    state.protocols.append(newItem)
                    state.save()
                }
            }
            .sheet(item: $editingProtocol) { item in
                ProtocolEditSheet(existing: item) { updated in
                    if let idx = state.protocols.firstIndex(where: { $0.id == item.id }) {
                        var current = state.protocols[idx]
                        if updated.active != current.active {
                            state.toggleProtocolActivation(item.id)
                        }
                        current.name = updated.name
                        current.detail = updated.detail
                        current.notes = updated.notes
                        current.category = updated.category ?? current.category
                        state.protocols[idx] = current
                        state.save()
                    }
                }
            }
            .alert("Supprimer le protocole ?", isPresented: $showDeleteAlert, presenting: toDeleteProtocol) { item in
                Button("Supprimer", role: .destructive) {
                    if let idx = state.protocols.firstIndex(where: { $0.id == item.id }) {
                        state.protocols.remove(at: idx)
                        state.save()
                    }
                }
                Button("Annuler", role: .cancel) {}
            } message: { item in Text("Supprimer '\(item.name)' ? Cette action est irréversible.") }
        }
    }

    // MARK: - Grouping
    private func groupedProtocols() -> [String: [ProtocolItem]] {
        var items = filteredProtocols()
        var grouped: [String: [ProtocolItem]] = [:]
        for p in items {
            let key = p.category ?? "Autre"
            grouped[key, default: []].append(p)
        }
        for (k, v) in grouped { grouped[k] = v.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } }
        if let cat = selectedCategory { return [cat: grouped[cat] ?? []] }
        return grouped
    }

    // MARK: - Filtering
    private func filteredProtocols() -> [ProtocolItem] {
        let now = Date()
        var items = state.protocols
        switch scope {
        case .active: items = items.filter { !$0.isArchived }
        case .archived: items = items.filter { $0.isArchived }
        case .all: break
        }
        switch statusFilter {
        case .all: break
        case .active: items = items.filter { protocolStatus(for: $0, now: now) == .active }
        case .planned: items = items.filter { protocolStatus(for: $0, now: now) == .planned }
        case .completed: items = items.filter { protocolStatus(for: $0, now: now) == .completed }
        }
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            items = items.filter { item in
                item.name.localizedCaseInsensitiveContains(query) || (item.detail?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }
        return items
    }

    private func protocolCategories() -> [String] {
        let set = Set(state.protocols.compactMap { $0.category })
        return Array(set).sorted()
    }

    private enum RuntimeStatus { case active, planned, completed }
    private func protocolStatus(for item: ProtocolItem, now: Date) -> RuntimeStatus {
        if let end = item.endDate, end < now { return .completed }
        if item.startDate > now { return .planned }
        return .active
    }

    private var isFilterActive: Bool { scope != .active || statusFilter != .all }

    private func labelForStatus(_ s: ProtocolStatusFilter) -> String { switch s { case .all: return "Tous"; case .active: return "Actifs"; case .planned: return "Planifiés"; case .completed: return "Terminés" } }

    private func categoryChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconForCategory(title))
                    .foregroundColor(selected ? Color("OnPrimary") : colorForCategory(title))
                Text(title)
            }
            .font(.footnote)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(selected ? Color("Primary") : Color(UIColor.secondarySystemBackground))
            .foregroundColor(selected ? Color("OnPrimary") : .primary)
            .clipShape(Capsule())
        }.buttonStyle(.plain)
    }

    private func sectionHeader(for category: String) -> some View {
        HStack {
            Image(systemName: iconForCategory(category))
                .foregroundColor(colorForCategory(category))
            Text(category)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}

// Helpers catégorie (icônes/couleurs)
private func iconForCategory(_ category: String) -> String {
    let key = category.lowercased()
    switch key {
    case "nootropiques", "nootropics", "cognition": return "brain.head.profile"
    case "vitamines", "vitamins": return "asterisk.circle"
    case "minéraux", "minerals", "mineraux": return "flask"
    case "protéines", "proteins", "proteine": return "dumbbell"
    case "énergie", "energy", "performance", "energie": return "bolt"
    case "récupération", "recovery", "recuperation": return "heart"
    case "sommeil", "sleep": return "moon"
    case "digestif", "digestive": return "fork.knife"
    case "immunité", "immune", "immunite": return "shield"
    case "traitement médical", "traitement", "medical": return "pills"
    case "métabolisme", "metabolisme": return "chart.line.uptrend.xyaxis"
    default: return "circle.grid.3x3"
    }
}

private func colorForCategory(_ category: String) -> Color {
    let key = category.lowercased()
    switch key {
    case "cognition", "nootropiques", "nootropics": return .purple
    case "vitamines", "vitamins": return .yellow
    case "minéraux", "minerals", "mineraux": return .teal
    case "protéines", "proteins", "proteine": return .orange
    case "énergie", "energy", "performance", "energie": return .pink
    case "récupération", "recovery", "recuperation": return .green
    case "sommeil", "sleep": return .indigo
    case "digestif", "digestive": return .brown
    case "immunité", "immune", "immunite": return .mint
    case "traitement médical", "traitement", "medical": return .red
    case "métabolisme", "metabolisme": return .blue
    default: return .secondary
    }
}

#Preview { ProtocolsView().environmentObject(AppState()) }
