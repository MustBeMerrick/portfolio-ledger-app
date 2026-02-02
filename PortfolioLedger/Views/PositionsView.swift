import SwiftUI

struct PositionsView: View {
    @EnvironmentObject var dataStore: DataStore
    @Binding var selectedTab: Int
    @State private var showingTradeEntry = false

    private func latestTransactionDate(for symbol: String) -> Date {
        let relatedTransactions = dataStore.transactions.filter { txn in
            guard let instrument = dataStore.instruments[txn.instrumentId] else { return false }
            return instrument.symbol == symbol
        }
        return relatedTransactions.map { $0.timestamp }.max() ?? Date.distantPast
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(Array(dataStore.ledgerOutput.underlierSummaries.values.sorted(by: {
                    latestTransactionDate(for: $0.symbol) > latestTransactionDate(for: $1.symbol)
                }))) { summary in
                    NavigationLink {
                        UnderlierDetailView(summary: summary)
                    } label: {
                        UnderlierSummaryRow(summary: summary)
                    }
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

struct UnderlierSummaryRow: View {
    let summary: UnderlierSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summary.symbol)
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                if summary.totalEquityShares > 0 {
                    Text("\(summary.totalEquityShares.description) shares")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if summary.totalEquityShares > 0 {
                HStack {
                    Text("Avg Cost:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(summary.averageEquityCost.description)")
                        .font(.caption)
                        .fontWeight(.medium)

                    Spacer()

                    Text("Basis:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(summary.totalEquityCostBasis.description)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            if summary.openOptionContracts > 0 {
                Text("\(summary.openOptionContracts) option contract\(summary.openOptionContracts == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PositionsView_Previews: PreviewProvider {
    static var previews: some View {
        PositionsView(selectedTab: .constant(1))
            .environmentObject(DataStore.shared)
    }
}
