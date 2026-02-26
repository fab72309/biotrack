import SwiftUI

struct ManageRemindersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: AppState
    @State private var showingNew = false
    @State private var showingEdit: Reminder? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SheetHeader(
                    title: "Gérer les rappels",
                    leadingTitle: "Fermer",
                    onLeading: { dismiss() },
                    trailingTitle: "Ajouter",
                    onTrailing: { showingNew = true }
                )
                List {
                    if state.reminders.isEmpty {
                        Section { Text("Aucun rappel").foregroundStyle(.secondary) }
                    } else {
                        Section(header: Text("Rappels")) {
                            ForEach(state.reminders) { r in
                                SwipeableRow(
                                    onEdit: { showingEdit = r },
                                    onDelete: { delete(r) }
                                ) {
                                    HStack {
                                        Image(systemName: r.enabled ? "bell.fill" : "bell.slash")
                                            .foregroundColor(r.enabled ? Color("Primary") : .secondary)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(r.title).font(.headline)
                                            Text(timeText(r) + weekdayText(r)).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingNew) {
            ReminderSheet { data in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: data.time)
                let r = Reminder(title: data.title,
                                  hour: comps.hour ?? 8,
                                  minute: comps.minute ?? 0,
                                  weekdays: Array(data.days).sorted(),
                                  notes: data.description,
                                  enabled: data.notificationsEnabled)
                state.reminders.append(r)
                state.save()
                if r.enabled {
                    NotificationService.shared.scheduleReminder(r)
                }
            }
        }
        .sheet(item: $showingEdit) { r in
            EditReminderSheet(reminder: r) { updated in
                if let idx = state.reminders.firstIndex(where: { $0.id == r.id }) {
                    NotificationService.shared.cancelReminder(baseId: state.reminders[idx].notificationBaseId)
                    state.reminders[idx] = updated
                    state.save()
                    if updated.enabled {
                        NotificationService.shared.scheduleReminder(updated)
                    }
                }
            }
        }
    }

    private func delete(_ r: Reminder) {
        if let idx = state.reminders.firstIndex(where: { $0.id == r.id }) {
            NotificationService.shared.cancelReminder(baseId: state.reminders[idx].notificationBaseId)
            state.reminders.remove(at: idx)
            state.save()
            Haptics.success()
        }
    }

    private func timeText(_ r: Reminder) -> String { String(format: "%02d:%02d", r.hour, r.minute) }

    private func weekdayText(_ r: Reminder) -> String {
        guard !r.weekdays.isEmpty else { return "" }
        let map = [1:"Dim",2:"Lun",3:"Mar",4:"Mer",5:"Jeu",6:"Ven",7:"Sam"]
        let str = r.weekdays.map { map[$0] ?? "" }.joined(separator: ", ")
        return "  •  " + str
    }
}

