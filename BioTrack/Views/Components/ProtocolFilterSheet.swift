import SwiftUI

enum ProtocolFilterScope: String, CaseIterable, Identifiable {
    case active = "Actifs"
    case archived = "Archivés"
    case all = "Tous"
    var id: String { rawValue }
}

enum ProtocolStatusFilter: String, CaseIterable, Identifiable {
    case all = "Tous"
    case active = "Actifs"
    case planned = "Planifiés"
    case completed = "Terminés"
    var id: String { rawValue }
}

struct ProtocolFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    let currentScope: ProtocolFilterScope
    let currentStatus: ProtocolStatusFilter
    let onApply: (ProtocolFilterScope, ProtocolStatusFilter) -> Void

    @State private var scope: ProtocolFilterScope
    @State private var status: ProtocolStatusFilter

    init(currentScope: ProtocolFilterScope, currentStatus: ProtocolStatusFilter, onApply: @escaping (ProtocolFilterScope, ProtocolStatusFilter) -> Void) {
        self.currentScope = currentScope
        self.currentStatus = currentStatus
        self.onApply = onApply
        _scope = State(initialValue: currentScope)
        _status = State(initialValue: currentStatus)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            List {
                Section(header: Text("Filtrer les protocoles")) {
                    selectableRow(title: "Actifs", icon: "tray", selected: scope == .active) { scope = .active }
                    selectableRow(title: "Archivés", icon: "archivebox", selected: scope == .archived) { scope = .archived }
                    selectableRow(title: "Tous", icon: "square.grid.2x2", selected: scope == .all) { scope = .all }
                }
                Section(header: Text("Statut")) {
                    selectableRow(title: "Tous", selected: status == .all) { status = .all }
                    selectableRow(title: "Actifs", selected: status == .active) { status = .active }
                    selectableRow(title: "Planifiés", selected: status == .planned) { status = .planned }
                    selectableRow(title: "Terminés", selected: status == .completed) { status = .completed }
                }
                Section { Button("Réinitialiser", role: .destructive) { scope = .active; status = .all } }
            }
        }
    }

    private var header: some View {
        SheetHeader(
            title: "Filtres",
            trailingTitle: "Appliquer",
            onTrailing: { onApply(scope, status); dismiss() }
        )
    }

    private func selectableRow(title: String, icon: String? = nil, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if let icon = icon { Image(systemName: icon) }
                Text(title)
                Spacer()
                if selected { Image(systemName: "checkmark").foregroundColor(Color("Primary")) }
            }
        }
    }
}

#Preview {
    ProtocolFilterSheet(currentScope: .active, currentStatus: .all) {_,_ in }
}


