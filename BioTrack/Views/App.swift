import SwiftUI

@main
struct BioTrackApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("darkMode") private var darkMode: Bool = false
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        let selectedColor = UIColor(named: "Primary") ?? .systemTeal
        let unselectedColor = UIColor.secondaryLabel
        // Stacked (iPhone portrait), Inline, CompactInline appearances
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        appearance.stackedLayoutAppearance.normal.iconColor = unselectedColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselectedColor]

        appearance.inlineLayoutAppearance.selected.iconColor = selectedColor
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        appearance.inlineLayoutAppearance.normal.iconColor = unselectedColor
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselectedColor]

        appearance.compactInlineLayoutAppearance.selected.iconColor = selectedColor
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        appearance.compactInlineLayoutAppearance.normal.iconColor = unselectedColor
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselectedColor]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = selectedColor
        UITabBar.appearance().unselectedItemTintColor = unselectedColor
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .tint(Color("Primary"))
                .preferredColorScheme(darkMode ? .dark : nil)
        }
    }
}
