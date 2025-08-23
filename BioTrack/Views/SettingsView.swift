import SwiftUI

struct SettingsView: View {
    @AppStorage("darkMode") private var darkMode: Bool = false
    @AppStorage("weightBaselineKg") private var weightBaselineKg: Double = 70

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Général")) {
                    Button(action: { NotificationService.shared.openSettings() }) {
                        HStack {
                            Image(systemName: "bell")
                            Text("Notifications")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    Toggle(isOn: $darkMode) {
                        HStack { Image(systemName: "moon.fill"); Text("Mode sombre") }
                    }
                }
                Section(header: Text("Métriques")) {
                    HStack {
                        Image(systemName: "scalemass")
                        Text("Poids de référence")
                        Spacer()
                        Text(String(format: "%.1f kg", weightBaselineKg)).foregroundColor(.secondary)
                    }
                    HStack {
                        Spacer(minLength: 20)
                        Stepper("", value: $weightBaselineKg, in: 30...200, step: 0.5)
                            .labelsHidden()
                    }
                }
                Section(header: Text("À propos")) {
                    HStack { Text("Version"); Spacer(); Text("0.1.0").foregroundColor(.secondary) }
                }
            }
            .navigationTitle(Text("Paramètres"))
        }
    }
}

#Preview { SettingsView() }


