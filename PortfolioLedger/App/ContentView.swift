import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var selectedTab = 0
    @State private var navigationID = UUID()

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(0)
                .id(selectedTab == 0 ? navigationID : UUID())

            PositionsMenuView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Positions", systemImage: "list.bullet.rectangle")
                }
                .tag(1)
                .id(selectedTab == 1 ? navigationID : UUID())

            TransactionsView()
                .tabItem {
                    Label("Ledger", systemImage: "book.closed")
                }
                .tag(2)
                .id(selectedTab == 2 ? navigationID : UUID())

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(3)
                .id(selectedTab == 3 ? navigationID : UUID())
        }
        .onChange(of: selectedTab) { _ in
            navigationID = UUID()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(DataStore.shared)
    }
}
