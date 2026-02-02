import SwiftUI

struct TradeEntryMenuView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedTab: Int
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List {
                NavigationLink {
                    AddEquityTradeView(selectedTab: $selectedTab, isPresented: $isPresented)
                } label: {
                    Label("Buy/Sell Stock", systemImage: "chart.line.uptrend.xyaxis")
                }

                NavigationLink {
                    AddOptionTradeView(selectedTab: $selectedTab, isPresented: $isPresented)
                } label: {
                    Label("Option Trade", systemImage: "list.bullet.rectangle")
                }
            }
            .navigationTitle("Add Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TradeEntryMenuView_Previews: PreviewProvider {
    static var previews: some View {
        TradeEntryMenuView(selectedTab: .constant(0), isPresented: .constant(true))
    }
}
