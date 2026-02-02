import SwiftUI

struct PositionsMenuView: View {
    @EnvironmentObject var dataStore: DataStore
    @Binding var selectedTab: Int
    @State private var showingTradeEntry = false

    var body: some View {
        NavigationView {
            List {
                NavigationLink {
                    EquityPositionsView(selectedTab: $selectedTab)
                } label: {
                    Label("Equity", systemImage: "chart.line.uptrend.xyaxis")
                }

                NavigationLink {
                    OptionsPositionsView(selectedTab: $selectedTab)
                } label: {
                    Label("Options", systemImage: "list.bullet.rectangle")
                }
            }
            .navigationTitle("Positions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingTradeEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingTradeEntry) {
                TradeEntryMenuView(selectedTab: $selectedTab, isPresented: $showingTradeEntry)
            }
        }
    }
}

struct PositionsMenuView_Previews: PreviewProvider {
    static var previews: some View {
        PositionsMenuView(selectedTab: .constant(1))
            .environmentObject(DataStore.shared)
    }
}
