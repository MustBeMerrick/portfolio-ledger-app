import SwiftUI

struct OptionsPositionsView: View {
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

    private var optionPositions: [UnderlierSummary] {
        dataStore.ledgerOutput.underlierSummaries.values
            .filter { $0.openOptionContracts > 0 }
            .sorted(by: { latestTransactionDate(for: $0.symbol) > latestTransactionDate(for: $1.symbol) })
    }

    var body: some View {
        List {
            if optionPositions.isEmpty {
                Text("No option positions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(optionPositions) { summary in
                    NavigationLink {
                        UnderlierDetailView(summary: summary)
                    } label: {
                        OptionsSummaryRow(summary: summary)
                    }
                }
            }
        }
        .navigationTitle("Options Positions")
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
            AddOptionTradeView(selectedTab: $selectedTab, isPresented: $showingTradeEntry)
        }
    }
}

struct OptionsSummaryRow: View {
    let summary: UnderlierSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summary.symbol)
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Text("\(summary.openOptionContracts) contract\(summary.openOptionContracts == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

struct OptionsPositionsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            OptionsPositionsView(selectedTab: .constant(1))
                .environmentObject(DataStore.shared)
        }
    }
}
