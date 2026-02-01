import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataStore: DataStore

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }

            PositionsView()
                .tabItem {
                    Label("Positions", systemImage: "list.bullet.rectangle")
                }

            TransactionsView()
                .tabItem {
                    Label("Ledger", systemImage: "book.closed")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(DataStore.shared)
    }
}
