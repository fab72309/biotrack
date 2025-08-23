import SwiftUI

struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let currentSelection: String
    let onDone: (String) -> Void

    @State private var workingSelection: String = ""

    private struct Category: Identifiable {
        let id = UUID()
        let title: String
        let systemImage: String
    }

    private let categories: [Category] = [
        .init(title: "Nootropiques", systemImage: "brain.head.profile"),
        .init(title: "Vitamines", systemImage: "asterisk.circle"),
        .init(title: "Minéraux", systemImage: "flask"),
        .init(title: "Protéines", systemImage: "dumbbell"),
        .init(title: "Énergie", systemImage: "bolt"),
        .init(title: "Récupération", systemImage: "heart"),
        .init(title: "Sommeil", systemImage: "moon"),
        .init(title: "Digestif", systemImage: "fork.knife"),
        .init(title: "Immunité", systemImage: "shield"),
        .init(title: "Traitement médical", systemImage: "pills"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(categories) { cat in
                        CategoryTile(title: cat.title, systemImage: cat.systemImage, isSelected: workingSelection == cat.title)
                            .onTapGesture { workingSelection = cat.title }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Button(action: { workingSelection = "Autre" }) {
                    HStack(spacing: 12) {
                        Image(systemName: "circle.grid.3x3")
                            .font(.system(size: 22, weight: .semibold))
                        Text("Autre")
                            .font(.system(size: 17, weight: .semibold))
                        Spacer()
                        if workingSelection == "Autre" {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(tileBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .onAppear { workingSelection = currentSelection }
    }

    private var header: some View {
        SheetHeader(
            title: "Sélectionner une catégorie",
            leadingTitle: "Annuler",
            onLeading: { dismiss() },
            trailingTitle: "Terminé",
            onTrailing: { onDone(workingSelection); dismiss() }
        )
    }

    private var tileBackground: some ShapeStyle {
        if #available(iOS 15.0, *) {
            return AnyShapeStyle(Color(uiColor: .secondarySystemBackground))
        } else {
            return AnyShapeStyle(Color.gray.opacity(0.12))
        }
    }
}

private struct CategoryTile: View {
    let title: String
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(isSelected ? Color("OnPrimary") : colorForCategory(title))
            Text(title)
                .font(.system(size: 15, weight: .semibold))
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .padding(.vertical, 12)
        .background(isSelected ? Color("Primary") : Color(UIColor.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color("Primary") : Color.clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var tileBackground: some ShapeStyle {
        if #available(iOS 15.0, *) {
            return AnyShapeStyle(Color(uiColor: .secondarySystemBackground))
        } else {
            return AnyShapeStyle(Color.gray.opacity(0.12))
        }
    }
}

// Couleurs catégorie cohérentes avec le filtre
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
    CategoryPickerSheet(currentSelection: "Autre", onDone: { _ in })
}


