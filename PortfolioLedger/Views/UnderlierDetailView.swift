import SwiftUI

struct UnderlierDetailView: View {
    @EnvironmentObject var dataStore: DataStore
    let summary: UnderlierSummary
    @State private var showingEquityCloseSheet = false

    var relatedTransactions: [Transaction] {
        dataStore.transactions.filter { txn in
            guard let instrument = dataStore.instruments[txn.instrumentId] else { return false }
            return instrument.underlyingTicker == summary.symbol
        }.sorted { $0.timestamp > $1.timestamp }
    }

    var relatedRealizedPLs: [RealizedPL] {
        dataStore.ledgerOutput.realizedPLs.filter { pl in
            guard let instrument = dataStore.instruments[pl.instrumentId] else { return false }
            return instrument.underlyingTicker == summary.symbol
        }
    }

    var body: some View {
        List {
            // Equity Position Section
            if let equityPos = summary.equityPosition, equityPos.isOpen {
                Section("Equity Position") {
                    HStack {
                        Text("Shares")
                        Spacer()
                        Text(summary.totalEquityShares.description)
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Average Cost")
                        Spacer()
                        Text("$\(summary.averageEquityCost.description)")
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("Total Cost Basis")
                        Spacer()
                        Text("$\(summary.totalEquityCostBasis.description)")
                            .fontWeight(.bold)
                    }

                    HStack {
                        Spacer()
                        Button {
                            showingEquityCloseSheet = true
                        } label: {
                            Text("Close")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                    }
                }
            }

            // Option Positions Section
            if !summary.optionPositions.isEmpty {
                Section("Option Positions") {
                    ForEach(summary.optionPositions) { position in
                        if let instrument = dataStore.instruments[position.instrumentId] {
                            OptionPositionRow(
                                position: position,
                                instrument: instrument
                            )
                        }
                    }
                }
            }

            // Realized P/L Section
            if !relatedRealizedPLs.isEmpty {
                Section("Realized P/L") {
                    HStack {
                        Text("Total Realized")
                        Spacer()
                        let total = relatedRealizedPLs.reduce(0) { $0 + $1.realizedPL }
                        Text("$\(total.description)")
                            .fontWeight(.bold)
                            .foregroundColor(total >= 0 ? .green : .red)
                    }

                    ForEach(relatedRealizedPLs.prefix(10)) { pl in
                        RealizedPLRow(realizedPL: pl)
                    }
                }
            }
        }
        .navigationTitle(summary.symbol)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingEquityCloseSheet) {
            if let equityPos = summary.equityPosition,
               let instrument = dataStore.instruments[equityPos.instrumentId] {
                ClosePositionView(position: equityPos, instrument: instrument)
            }
        }
    }
}

struct OptionPositionRow: View {
    let position: Position
    let instrument: Instrument
    @State private var showingCloseSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(instrument.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        Text("Contracts:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(abs(position.quantity).description)
                            .font(.caption)

                        Spacer()

                        Text(position.quantity < 0 ? "SHORT" : "LONG")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(position.quantity < 0 ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                            .foregroundColor(position.quantity < 0 ? .orange : .blue)
                            .cornerRadius(4)
                    }

                    HStack {
                        Text("Cost Basis:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("$\(position.costBasis.description)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }

                Spacer()

                Button {
                    showingCloseSheet = true
                } label: {
                    Text("Close")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingCloseSheet) {
            ClosePositionView(position: position, instrument: instrument)
        }
    }
}

struct RealizedPLRow: View {
    let realizedPL: RealizedPL

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(realizedPL.closeDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(realizedPL.quantity.description) @ $\((realizedPL.proceeds / realizedPL.quantity).description)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(realizedPL.realizedPL.description)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(realizedPL.realizedPL >= 0 ? .green : .red)

                Text("\(realizedPL.holdingDays)d hold")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct UnderlierDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            UnderlierDetailView(
                summary: UnderlierSummary(
                    symbol: "AAPL",
                    equityPosition: nil,
                    optionPositions: []
                )
            )
            .environmentObject(DataStore.shared)
        }
    }
}
