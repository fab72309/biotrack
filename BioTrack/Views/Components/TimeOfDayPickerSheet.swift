import SwiftUI

struct TimeOfDayPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let current: String
    let onDone: (String) -> Void

    @State private var working: String = "Matin"

    private let options = [
        "Matin",
        "Après‑midi",
        "Soir",
        "Avant le repas",
        "Avec le repas",
        "Après le repas",
        "Avant le coucher",
        "Après l'effort"
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Annuler") { dismiss() }
                Spacer()
                Text("Sélectionner le moment").font(.headline)
                Spacer()
                Button("Terminé") { onDone(working); dismiss() }
                    .font(.headline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)

            List {
                ForEach(options, id: \.self) { label in
                    Button(action: { working = label }) {
                        HStack {
                            Text(label)
                            Spacer()
                            if working == label { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                        }
                    }
                }
            }
        }
        .onAppear { working = current }
    }
}


