import SwiftUI

struct TradeEntryMenuView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Equity") {
                    NavigationLink {
                        AddEquityTradeView()
                    } label: {
                        Label("Buy/Sell Stock", systemImage: "chart.line.uptrend.xyaxis")
                    }
                }

                Section("Options") {
                    NavigationLink {
                        AddOptionTradeView()
                    } label: {
                        Label("Option Trade", systemImage: "list.bullet.rectangle")
                    }
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
        TradeEntryMenuView()
    }
}
