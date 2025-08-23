import SwiftUI

struct SupplementFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    let currentActiveOnly: Bool
    let currentCategories: Set<String>
    let onApply: (Bool, Set<String>) -> Void

    @State private var activeOnly: Bool
    @State private var selectedCategories: Set<String>

    init(currentActiveOnly: Bool, currentCategories: Set<String>, onApply: @escaping (Bool, Set<String>) -> Void) {
        self.currentActiveOnly = currentActiveOnly
        self.currentCategories = currentCategories
        self.onApply = onApply
        _activeOnly = State(initialValue: currentActiveOnly)
        _selectedCategories = State(initialValue: currentCategories)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            List {
                Section(header: Text("Statut")) {
                    selectableRow(title: "Actifs uniquement", selected: activeOnly) { activeOnly = true }
                    selectableRow(title: "Tout (y compris inactifs)", selected: !activeOnly) { activeOnly = false }
                }
                Section(header: Text("Catégories")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(allCategories(), id: \.self) { cat in
                            categoryChip(title: cat)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section { Button("Réinitialiser", role: .destructive) { activeOnly = false; selectedCategories.removeAll() } }
            }
        }
    }

    private var header: some View {
        SheetHeader(
            title: "Filtres",
            trailingTitle: "Appliquer",
            onTrailing: { onApply(activeOnly, selectedCategories); dismiss() }
        )
    }

    private func selectableRow(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if selected { Image(systemName: "checkmark").foregroundColor(Color("Primary")) }
            }
        }
    }

    private func categoryChip(title: String) -> some View {
        let isSelected = selectedCategories.contains(title.lowercased())
        return SelectableChip(
            title: title,
            selected: isSelected,
            iconSystemName: CategoryAppearance.iconName(for: title),
            tintColor: CategoryAppearance.color(for: title)
        ) {
            if isSelected { selectedCategories.remove(title.lowercased()) }
            else { selectedCategories.insert(title.lowercased()) }
        }
    }
}

func allCategories() -> [String] {
    [
        "Nootropiques", "Vitamines", "Minéraux", "Protéines",
        "Énergie", "Récupération", "Sommeil", "Digestif",
        "Immunité", "Traitement médical", "Autre"
    ]
}

// Local util to avoid cross-file dependency
private func iconForCategory(_ category: String) -> String {
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

private func colorForCategory(_ category: String) -> Color {
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

#Preview {
    SupplementFilterSheet(currentActiveOnly: true, currentCategories: []) {_,_ in }
}


