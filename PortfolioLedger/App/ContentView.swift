import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var selectedTab = 0
    @State private var tabIDs = [UUID(), UUID(), UUID(), UUID()]

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(0)
                .id(tabIDs[0])

            PositionsMenuView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Positions", systemImage: "list.bullet.rectangle")
                }
                .tag(1)
                .id(tabIDs[1])

            TransactionsView()
                .tabItem {
                    Label("Ledger", systemImage: "book.closed")
                }
                .tag(2)
                .id(tabIDs[2])

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(3)
                .id(tabIDs[3])
        }
        .onChange(of: selectedTab) { oldTab, newTab in
          tabIDs[newTab] = UUID()   // only reset the newly selected tab
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(DataStore.shared)
    }
}
