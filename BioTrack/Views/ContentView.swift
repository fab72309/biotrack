import SwiftUI

struct ContentView: View {
    @AppStorage("selectedTab") private var selectedTab: Int = 0
    @AppStorage("healthAutoSync") private var healthAutoSync: Bool = true
    @AppStorage("healthImportRangeDays") private var healthImportRangeDays: Int = 30
    @AppStorage("healthDedupePolicy") private var healthDedupePolicyRaw: String = HealthDedupePolicy.replace.rawValue
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var didInitialHealthSync = false
    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)
                    .tabItem { Label(NSLocalizedString("tab.checklist", comment: ""), systemImage: "house") }
                TrackView()
                    .tag(1)
                    .tabItem { Label(NSLocalizedString("tab.track", comment: ""), systemImage: "slider.horizontal.3") }
                StatsView()
                    .tag(2)
                    .tabItem { Label(NSLocalizedString("tab.stats", comment: ""), systemImage: "chart.line.uptrend.xyaxis") }
                ProtocolsView()
                    .tag(3)
                    .tabItem { Label(NSLocalizedString("tab.protocols", comment: ""), systemImage: "target") }
                SupplementsView()
                    .tag(4)
                    .tabItem { Label(NSLocalizedString("tab.supplements", comment: ""), systemImage: "pills") }
            }
            .tint(Color("Primary"))
        }
        .task {
            await MainActor.run { appState.refreshHealthKitStatus() }
            await MainActor.run {
                appState.applyAdaptiveGoalPolicyIfNeeded()
                appState.refreshInsightsAndRecommendations()
            }
            if !didInitialHealthSync {
                didInitialHealthSync = true
                if healthAutoSync, appState.healthKitStatus == .authorized {
                    await appState.syncHealthKit(rangeDays: healthImportRangeDays, dedupePolicy: dedupePolicy)
                }
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task {
                    await MainActor.run { appState.load() }
                    await MainActor.run { appState.refreshHealthKitStatus() }
                    await MainActor.run {
                        appState.applyAdaptiveGoalPolicyIfNeeded()
                        appState.refreshInsightsAndRecommendations()
                    }
                    if healthAutoSync, appState.healthKitStatus == .authorized {
                        await appState.syncHealthKit(rangeDays: healthImportRangeDays, dedupePolicy: dedupePolicy)
                    }
                }
            }
        }
        .onOpenURL { url in
            guard url.scheme == "biotrack" else { return }
            let destination = (url.host ?? "").lowercased()
            let defaults = AppGroup.sharedDefaults()
            if !defaults.bool(forKey: "analytics.widget_added.logged") {
                defaults.set(true, forKey: "analytics.widget_added.logged")
                WidgetEventLogger.log("widget_added")
            }
            switch destination {
            case "home":
                selectedTab = 0
            case "track":
                selectedTab = 1
            case "stats":
                selectedTab = 2
            case "protocols":
                selectedTab = 3
            case "supplements":
                selectedTab = 4
            case "reminders":
                selectedTab = 0
            default:
                selectedTab = 0
            }
            WidgetEventLogger.log("widget_open_app_deeplink", metadata: ["destination": destination])
        }
        .alert(
            "Récupération des données",
            isPresented: Binding(
                get: { appState.storeRecoveryNoticeMessage != nil },
                set: { presented in
                    if !presented {
                        appState.dismissStoreRecoveryNotice()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                appState.dismissStoreRecoveryNotice()
            }
        } message: {
            Text(appState.storeRecoveryNoticeMessage ?? "")
        }
    }

    private var dedupePolicy: HealthDedupePolicy {
        HealthDedupePolicy(rawValue: healthDedupePolicyRaw) ?? .replace
    }
}

#Preview {
    ContentView().environmentObject(AppState())
}
