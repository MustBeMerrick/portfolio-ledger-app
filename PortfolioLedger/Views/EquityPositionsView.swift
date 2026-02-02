import SwiftUI

struct EquityPositionsView: View {
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

    private var equityPositions: [UnderlierSummary] {
        dataStore.ledgerOutput.underlierSummaries.values
            .filter { $0.totalEquityShares > 0 }
            .sorted(by: { latestTransactionDate(for: $0.symbol) > latestTransactionDate(for: $1.symbol) })
    }

    var body: some View {
        List {
            if equityPositions.isEmpty {
                Text("No equity positions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(equityPositions) { summary in
                    NavigationLink {
                        UnderlierDetailView(summary: summary)
                    } label: {
                        EquitySummaryRow(summary: summary)
                    }
                }
            }
        }
        .navigationTitle("Equity Positions")
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
            AddEquityTradeView(selectedTab: $selectedTab, isPresented: $showingTradeEntry)
        }
    }
}

struct EquitySummaryRow: View {
    let summary: UnderlierSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summary.symbol)
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Text("\(summary.totalEquityShares.description) shares")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

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
        .padding(.vertical, 4)
    }
}

struct EquityPositionsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EquityPositionsView(selectedTab: .constant(1))
                .environmentObject(DataStore.shared)
        }
    }
}
