import SwiftUI

struct RoutineProfilesSettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedKind: RoutineProfileKind = .weekday

    var body: some View {
        List {
            Section(header: Text("Profil")) {
                Picker("Profil", selection: $selectedKind) {
                    ForEach(RoutineProfileKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                Button(action: {
                    state.setRoutineProfile(kind: selectedKind)
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Utiliser ce profil maintenant")
                        Spacer()
                        if state.activeRoutineProfileKind == selectedKind {
                            Text("Actif")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(state.activeRoutineProfileKind == selectedKind)
            }

            Section(header: Text("Protocoles")) {
                if sortedProtocols.isEmpty {
                    Text("Aucun protocole")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(sortedProtocols) { item in
                        Toggle(isOn: Binding(
                            get: { state.isProtocolEnabled(item.id, for: selectedKind) },
                            set: { state.setProtocolEnabled(item.id, enabled: $0, for: selectedKind) }
                        )) {
                            Text(item.name)
                        }
                    }
                }
            }

            Section(header: Text("Compléments")) {
                if sortedSupplements.isEmpty {
                    Text("Aucun complément")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(sortedSupplements) { item in
                        Toggle(isOn: Binding(
                            get: { state.isSupplementEnabled(item.id, for: selectedKind) },
                            set: { state.setSupplementEnabled(item.id, enabled: $0, for: selectedKind) }
                        )) {
                            Text(item.name)
                        }
                    }
                }
            }

            Section(header: Text("Rappels")) {
                if sortedReminders.isEmpty {
                    Text("Aucun rappel")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(sortedReminders) { item in
                        Toggle(isOn: Binding(
                            get: { state.isReminderEnabled(item.id, for: selectedKind) },
                            set: { state.setReminderEnabled(item.id, enabled: $0, for: selectedKind) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                Text(String(format: "%02d:%02d", item.hour, item.minute))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                Button("Réactiver tous les éléments de ce profil") {
                    state.resetRoutineProfileFilters(for: selectedKind)
                }
            }
        }
        .navigationTitle("Profils de routine")
        .onAppear {
            selectedKind = state.activeRoutineProfileKind
        }
    }

    private var sortedProtocols: [ProtocolItem] {
        state.protocols.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var sortedSupplements: [Supplement] {
        state.supplements.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var sortedReminders: [Reminder] {
        state.reminders.sorted { lhs, rhs in
            let left = lhs.hour * 60 + lhs.minute
            let right = rhs.hour * 60 + rhs.minute
            if left != right { return left < right }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

#Preview {
    NavigationView {
        RoutineProfilesSettingsView()
            .environmentObject(AppState())
    }
}
