import SwiftUI

// MARK: - Library Models

enum LibraryCategory: String, Codable, CaseIterable, Identifiable {
    case nootropics = "Nootropiques"
    case vitamins   = "Vitamines"
    case minerals   = "Minéraux"
    case performance = "Énergie"
    case sleep      = "Sommeil"
    var id: String { rawValue }
}

enum LibraryStatus: String, Codable {
    case added = "Ajouté"
    case add   = "Ajouter"
}

struct LibrarySupplement: Identifiable, Codable {
    let id: String
    let name: String
    let mainDose: String
    let range: String
    let categories: [LibraryCategory]
    let badges: [String]
    let benefits: [String]
    let status: LibraryStatus
    let note: String?
    let sources: [String]
}

let supplementLibrary: [LibrarySupplement] = [
    .init(
        id: "vitD3",
        name: "Vitamine D3",
        mainDose: "2000 UI",
        range: "1000–5000 UI",
        categories: [.vitamins],
        badges: ["Populaire"],
        benefits: ["Santé osseuse", "Soutien immunitaire", "Humeur"],
        status: .added,
        note: "Disponible chez de nombreux fabricants",
        sources: ["Endocrine Society 2024", "NIH ODS"]
    ),
    .init(
        id: "vitB12",
        name: "Vitamine B12",
        mainDose: "1000 µg",
        range: "500–2500 µg",
        categories: [.vitamins],
        badges: ["Populaire"],
        benefits: ["Énergie", "Système nerveux", "Globules rouges"],
        status: .add,
        note: "Disponible chez de nombreux fabricants",
        sources: ["NIH ODS", "Guides cliniques carences B12"]
    ),
    .init(
        id: "vitC",
        name: "Vitamine C",
        mainDose: "1000 mg",
        range: "500–2000 mg",
        categories: [.vitamins],
        badges: ["Populaire"],
        benefits: ["Antioxydant", "Immunité", "Collagène"],
        status: .add,
        note: "Disponible chez de nombreux fabricants",
        sources: ["NIH ODS"]
    ),
    .init(
        id: "mgGly",
        name: "Magnésium (glycinate)",
        mainDose: "300–400 mg",
        range: "200–600 mg",
        categories: [.minerals],
        badges: ["Populaire"],
        benefits: ["Relaxation musculaire", "Sommeil", "Stress ↓"],
        status: .add,
        note: "Privilégier formes bien tolérées (glycinate/citrate)",
        sources: ["EFSA/IOM (UL supplément)", "Revue sommeil (ECR variables)"]
    ),
    .init(
        id: "zinc",
        name: "Zinc (picolinate/citrate)",
        mainDose: "15 mg",
        range: "8–30 mg",
        categories: [.minerals],
        badges: ["Populaire"],
        benefits: ["Immunité", "Cicatrisation", "Synthèse protéique"],
        status: .add,
        note: "Éviter >40 mg/j au long cours (risque cuivre↓)",
        sources: ["NIH ODS"]
    ),
    .init(
        id: "omega3",
        name: "Oméga-3 (EPA+DHA)",
        mainDose: "1 g",
        range: "1–3 g",
        categories: [.performance],
        badges: ["Populaire"],
        benefits: ["Inflammation ↓", "Courbatures (DOMS) ↓", "Triglycérides ↓"],
        status: .add,
        note: "Adapter selon apport alimentaire (poissons gras)",
        sources: ["EFSA/AHA", "Revues DOMS"]
    ),
    .init(
        id: "creatine",
        name: "Créatine monohydrate",
        mainDose: "5 g",
        range: "3–5 g",
        categories: [.performance],
        badges: ["Populaire"],
        benefits: ["Force/puissance ↑", "Masse maigre ↑", "Cognition (modeste)"],
        status: .add,
        note: "Sans phase de charge nécessaire",
        sources: ["ISSN Position Stand", "Revues 2023–2024"]
    ),
    .init(
        id: "theanineCaffeine",
        name: "L-théanine + caféine",
        mainDose: "200 mg + 100 mg",
        range: "Théanine 100–200 mg ; Caféine 40–100 mg",
        categories: [.nootropics],
        badges: [],
        benefits: ["Attention/précision ↑", "Jitter ↓ vs caféine seule"],
        status: .add,
        note: "Éviter tard (>15 h) si sensibilité sommeil",
        sources: ["ECR combinés théanine+caféine"]
    ),
    .init(
        id: "rhodiola",
        name: "Rhodiola rosea (SHR-5)",
        mainDose: "300 mg",
        range: "200–400 mg",
        categories: [.nootropics],
        badges: [],
        benefits: ["Fatigue/stress ↓", "Soutien performance (variable)"],
        status: .add,
        note: "Standardisation ~3% rosavines / 1% salidroside",
        sources: ["Revue 2022", "EMA/HMPC monographie"]
    ),
    .init(
        id: "bacopa",
        name: "Bacopa monnieri (≥45% bacosides)",
        mainDose: "300 mg",
        range: "300–450 mg",
        categories: [.nootropics],
        badges: [],
        benefits: ["Mémoire ↑", "Attention ↑ (8–12 sem)"],
        status: .add,
        note: "Effets retardés ; qualité d’extrait importante",
        sources: ["Méta-analyse 2014", "StatPearls"]
    ),
    .init(
        id: "melatonin",
        name: "Mélatonine",
        mainDose: "0,5–1 mg",
        range: "0,5–5 mg",
        categories: [.sleep],
        badges: [],
        benefits: ["Endormissement/jet-lag (modeste)"],
        status: .add,
        note: "Usage ponctuel ; AASM prudente en insomnie chronique",
        sources: ["Cochrane Jet-lag", "AASM"]
    )
]

// MARK: - Sheet UI

struct SupplementLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: AppState

    @State private var searchText: String = ""
    @State private var selectedCategory: LibraryCategory? = nil

    var body: some View {
        VStack(spacing: 10) {
            searchBar
            categoryChips
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredLibrary) { item in
                        LibraryCard(item: item, isAdded: isAdded(item)) {
                            addToUser(item)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Bibliothèque de supplément")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    // MARK: - Views
    private var searchBar: some View {
        SearchField(placeholder: "Rechercher des compléments...", text: $searchText)
            .padding(.horizontal, 12)
            .padding(.top, 8)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(title: "Tous", selected: selectedCategory == nil) { selectedCategory = nil }
                ForEach(LibraryCategory.allCases) { cat in
                    chipForCategory(cat, selected: selectedCategory == cat) { selectedCategory = cat }
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private func chipForCategory(_ category: LibraryCategory, selected: Bool, action: @escaping () -> Void) -> some View {
        let title = category.rawValue
        return SelectableChip(title: title,
                              selected: selected,
                              iconSystemName: CategoryAppearance.iconName(for: title),
                              tintColor: CategoryAppearance.color(for: title),
                              action: action)
    }

    private func categoryChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        SelectableChip(title: title, selected: selected, action: action)
    }

    // MARK: - Helpers
    private var filteredLibrary: [LibrarySupplement] {
        let base: [LibrarySupplement]
        if let cat = selectedCategory { base = supplementLibrary.filter { $0.categories.contains(cat) } } else { base = supplementLibrary }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }
        return base.filter { s in
            s.name.localizedCaseInsensitiveContains(q) || s.benefits.contains(where: { $0.localizedCaseInsensitiveContains(q) })
        }
    }

    private func iconForCategory(_ cat: LibraryCategory) -> String {
        switch cat {
        case .nootropics: return "brain.head.profile"
        case .vitamins: return "asterisk.circle"
        case .minerals: return "flask"
        case .performance: return "bolt"
        case .sleep: return "moon"
        }
    }

    private func colorForCategory(_ title: String) -> Color {
        let key = title.lowercased()
        switch key {
        case "nootropiques", "nootropics": return .purple
        case "vitamines", "vitamins": return .yellow
        case "minéraux", "minerals", "mineraux": return .teal
        case "protéines", "proteins", "proteine": return .orange
        case "énergie", "energy", "performance", "energie": return .pink
        case "récupération", "recovery", "recuperation": return .green
        case "sommeil", "sleep": return .indigo
        case "digestif", "digestive": return .brown
        case "immunité", "immune", "immunite": return .mint
        case "traitement médical", "traitement", "medical": return .red
        default: return .secondary
        }
    }

    private func isAdded(_ item: LibrarySupplement) -> Bool {
        state.supplements.contains { $0.name.localizedCaseInsensitiveCompare(item.name) == .orderedSame }
    }

    private func addToUser(_ item: LibrarySupplement) {
        guard !isAdded(item) else { return }
        // Map library item to app's Supplement model
        let categoryTitle: String = item.categories.first?.rawValue ?? "Autre"
        let benefitsText = item.benefits.joined(separator: " • ")
        let note = item.note
        let combinedNotes = [benefitsText, note].compactMap { $0 }.joined(separator: "\n")
        let newSup = Supplement(
            name: item.name,
            brand: nil,
            dose: item.mainDose,
            category: categoryTitle,
            timeOfDay: nil,
            timeContext: nil,
            frequency: .daily,
            timesPerDay: nil,
            daysOfWeek: nil,
            durationNote: "Plage: \(item.range)",
            notes: combinedNotes.isEmpty ? nil : combinedNotes,
            active: true
        )
        state.supplements.append(newSup)
        state.save()
    }
}

// MARK: - Card

private struct LibraryCard: View {
    let item: LibrarySupplement
    let isAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    if let first = item.categories.first {
                        HStack(spacing: 6) {
                            Image(systemName: iconForCategory(first))
                            Text(first.rawValue)
                        }
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(Capsule())
                    }
                }
            }
            Text(item.mainDose)
                .font(.footnote.weight(.semibold))
            Text("Plage: \(item.range)")
                .foregroundColor(.secondary)
            if !item.benefits.isEmpty {
                Text(item.benefits.joined(separator: " • "))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let n = item.note {
                Text(n)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack {
                Spacer()
                if isAdded {
                    Label("Ajouté", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Button(action: onAdd) {
                        Label("Ajouter", systemImage: "plus")
                            .font(.caption)
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(UIColor.secondarySystemBackground)))
    }

    private func iconForCategory(_ cat: LibraryCategory) -> String {
        switch cat {
        case .nootropics: return "brain.head.profile"
        case .vitamins: return "asterisk.circle"
        case .minerals: return "flask"
        case .performance: return "bolt"
        case .sleep: return "moon"
        }
    }
}


