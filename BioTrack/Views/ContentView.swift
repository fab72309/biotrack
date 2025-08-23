import SwiftUI

struct ContentView: View {
    @AppStorage("selectedTab") private var selectedTab: Int = 0
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
    }
}

#Preview {
    ContentView()
}
