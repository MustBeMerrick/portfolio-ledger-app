import SwiftUI

struct UnderlierDetailView: View {
    @EnvironmentObject var dataStore: DataStore
    let summary: UnderlierSummary
    @State private var showingEquityCloseSheet = false

    /// Shares locked as collateral for open short calls.
    var collateralizedShares: Decimal {
        summary.optionPositions.reduce(0) { total, position in
            guard position.isOpen, position.quantity < 0,
                  let instrument = dataStore.instruments[position.instrumentId],
                  instrument.callPut == .call else { return total }
            let multiplier = Decimal(instrument.multiplier ?? 100)
            return total + (abs(position.quantity) * multiplier)
        }
    }

    /// Shares available to close (not locked by a short call).
    var freeEquityShares: Decimal {
        max(0, summary.totalEquityShares - collateralizedShares)
    }

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
                        Text(summary.totalEquityShares.asQuantity)
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Average Cost")
                        Spacer()
                        Text(summary.averageEquityCost.asCurrency)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("Total Cost Basis")
                        Spacer()
                        Text(summary.totalEquityCostBasis.asCurrency)
                            .fontWeight(.bold)
                    }

                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Button {
                                showingEquityCloseSheet = true
                            } label: {
                                Text(freeEquityShares < summary.totalEquityShares && freeEquityShares > 0
                                     ? "Close \(freeEquityShares.asQuantity) shares"
                                     : "Close")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(freeEquityShares <= 0 ? Color.gray : Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                            .disabled(freeEquityShares <= 0)

                            if freeEquityShares <= 0 {
                                Text("Close short call first")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            } else if collateralizedShares > 0 {
                                Text("\(collateralizedShares.asQuantity) shares collateralized")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
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
                        Text(total.asCurrency)
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
                ClosePositionView(
                    position: equityPos,
                    instrument: instrument,
                    closeQuantity: freeEquityShares < summary.totalEquityShares ? freeEquityShares : nil
                )
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
                        Text(abs(position.quantity).asQuantity)
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
                        Text(position.costBasis.asCurrency)
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

                Text("\(realizedPL.quantity.asQuantity) @ \((realizedPL.proceeds / realizedPL.quantity).asCurrency)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(realizedPL.realizedPL.asCurrency)
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
