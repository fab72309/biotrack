import SwiftUI

// MARK: - Modal surfaces

/// Shared visual language for the two custom, in-app popups.
/// System sheets keep their native presentation chrome; overlay popups use
/// `BioTrackPopupBackdrop` around the same card surface.
enum BioTrackModalMetrics {
    static let cornerRadius: CGFloat = 28
    static let horizontalPadding: CGFloat = 20
    static let borderWidth: CGFloat = 0.75
}

struct BioTrackPopupCard<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: BioTrackModalMetrics.cornerRadius, style: .continuous)
                .fill(Color("Surface"))
        )
        .clipShape(RoundedRectangle(cornerRadius: BioTrackModalMetrics.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BioTrackModalMetrics.cornerRadius, style: .continuous)
                .stroke(Color("Separator"), lineWidth: BioTrackModalMetrics.borderWidth)
        )
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 12)
    }
}

struct BioTrackPopupBackdrop<Content: View>: View {
    private let content: () -> Content
    private let onDismiss: (() -> Void)?

    init(onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss?() }

            content()
                .frame(maxWidth: 520)
                .padding(.horizontal, BioTrackModalMetrics.horizontalPadding)
                .padding(.vertical, 28)
        }
    }
}

struct BioTrackModalCloseButton: View {
    let action: () -> Void
    var accessibilityLabel: String = "Fermer"
    var foregroundColor: Color = .primary
    var backgroundColor: Color = Color("Background")

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(foregroundColor)
                .frame(width: 34, height: 34)
                .background(backgroundColor, in: Circle())
                .overlay(Circle().stroke(Color("Separator"), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

// MARK: - Sheet Header

struct SheetHeader: View {
    let title: String

    let leadingTitle: String?
    let leadingIcon: String?
    let onLeading: (() -> Void)?

    let trailingTitle: String?
    let trailingIcon: String?
    let onTrailing: (() -> Void)?
    var trailingDisabled: Bool = false

    init(title: String,
         leadingTitle: String? = nil,
         leadingIcon: String? = nil,
         onLeading: (() -> Void)? = nil,
         trailingTitle: String? = nil,
         trailingIcon: String? = nil,
         onTrailing: (() -> Void)? = nil,
         trailingDisabled: Bool = false) {
        self.title = title
        self.leadingTitle = leadingTitle
        self.leadingIcon = leadingIcon
        self.onLeading = onLeading
        self.trailingTitle = trailingTitle
        self.trailingIcon = trailingIcon
        self.onTrailing = onTrailing
        self.trailingDisabled = trailingDisabled
    }

    var body: some View {
        HStack {
            if let onLeading = onLeading, (leadingTitle != nil || leadingIcon != nil) {
                Button(action: onLeading) {
                    if let title = leadingTitle {
                        Text(title)
                    } else if let icon = leadingIcon {
                        Image(systemName: icon)
                            .font(.headline)
                    }
                }
            } else {
                // maintain layout
                Color.clear.frame(width: 1, height: 1).opacity(0)
            }

            Spacer()

            Text(title)
                .font(.headline)

            Spacer()

            if let onTrailing = onTrailing, (trailingTitle != nil || trailingIcon != nil) {
                Button(action: onTrailing) {
                    if let title = trailingTitle {
                        Text(title)
                    } else if let icon = trailingIcon {
                        Image(systemName: icon)
                            .font(.headline)
                    }
                }
                .disabled(trailingDisabled)
            } else {
                Color.clear.frame(width: 1, height: 1).opacity(0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Selectable Chip

struct SelectableChip: View {
    let title: String
    let selected: Bool
    let iconSystemName: String?
    let tintColor: Color?
    let selectedBackgroundColor: Color?
    let selectedForegroundColor: Color?
    let action: () -> Void

    init(title: String,
         selected: Bool,
         iconSystemName: String? = nil,
         tintColor: Color? = nil,
         selectedBackgroundColor: Color? = nil,
         selectedForegroundColor: Color? = nil,
         action: @escaping () -> Void) {
        self.title = title
        self.selected = selected
        self.iconSystemName = iconSystemName
        self.tintColor = tintColor
        self.selectedBackgroundColor = selectedBackgroundColor
        self.selectedForegroundColor = selectedForegroundColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = iconSystemName {
                    Image(systemName: icon)
                        .foregroundColor(selected ? (selectedForegroundColor ?? Color("OnPrimary")) : (tintColor ?? .primary))
                        .accessibilityHidden(true)
                }
                Text(title)
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(selected ? (selectedBackgroundColor ?? Color("Primary")) : Color(UIColor.secondarySystemBackground))
            .foregroundColor(selected ? (selectedForegroundColor ?? Color("OnPrimary")) : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement()
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(selected ? "Sélectionné" : "Non sélectionné"))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .animation(.easeInOut(duration: 0.15), value: selected)
    }
}

// MARK: - Search Field

struct SearchField: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .onSubmit { onSubmit?() }
        }
        .padding(10)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Surface Card

struct SurfaceCard<Content: View>: View {
    let content: () -> Content
    var contentPadding: CGFloat = 12
    var cornerRadius: CGFloat = 16
    var addBorder: Bool = true

    init(contentPadding: CGFloat = 12,
         cornerRadius: CGFloat = 16,
         addBorder: Bool = true,
         @ViewBuilder content: @escaping () -> Content) {
        self.contentPadding = contentPadding
        self.cornerRadius = cornerRadius
        self.addBorder = addBorder
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(contentPadding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(UIColor.systemBackground))
        )
        .overlay(
            Group {
                if addBorder {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color(UIColor.separator), lineWidth: 0.5)
                }
            }
        )
    }
}

// MARK: - Category Appearance (icons / colors)

struct CategoryAppearance {
    static func iconName(for category: String) -> String {
        let key = category.lowercased()
        switch key {
        case "nootropiques", "nootropics": return "brain.head.profile"
        case "cognition": return "brain.head.profile"
        case "vitamines", "vitamins": return "asterisk.circle"
        case "minéraux", "minerals", "mineraux": return "flask"
        case "protéines", "proteins", "protéine", "proteine": return "dumbbell"
        case "énergie", "energy", "performance", "energie": return "bolt"
        case "récupération", "recovery", "recuperation": return "heart"
        case "sommeil", "sleep": return "moon"
        case "digestif", "digestive": return "fork.knife"
        case "immunité", "immune", "immunite": return "shield"
        case "métabolisme", "metabolisme": return "chart.line.uptrend.xyaxis"
        case "traitement médical", "traitement", "medical": return "pills"
        default: return "circle.grid.3x3"
        }
    }

    static func color(for category: String) -> Color {
        let key = category.lowercased()
        switch key {
        case "nootropiques", "nootropics": return .purple
        case "cognition": return .purple
        case "vitamines", "vitamins": return .yellow
        case "minéraux", "minerals", "mineraux": return .teal
        case "protéines", "proteins", "protéine", "proteine": return .orange
        case "énergie", "energy", "performance", "energie": return .pink
        case "récupération", "recovery", "recuperation": return .green
        case "sommeil", "sleep": return .indigo
        case "digestif", "digestive": return .brown
        case "immunité", "immune", "immunite": return .mint
        case "métabolisme", "metabolisme": return .blue
        case "traitement médical", "traitement", "medical": return .red
        default: return .secondary
        }
    }
}
