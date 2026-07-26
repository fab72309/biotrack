import SwiftUI

struct PassphrasePromptSheet: View {
    let title: String
    let actionTitle: String
    let onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var passphrase: String = ""
    @State private var confirmation: String = ""
    var requiresConfirmation: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Passphrase")) {
                    SecureField("Saisir la passphrase", text: $passphrase)
                    if requiresConfirmation {
                        SecureField("Confirmer la passphrase", text: $confirmation)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(actionTitle) {
                        onConfirm(passphrase)
                        dismiss()
                    }
                    .disabled(passphrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (requiresConfirmation && passphrase != confirmation))
                }
            }
        }
    }
}

