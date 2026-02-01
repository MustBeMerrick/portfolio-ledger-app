import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingTradeEntry = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // P/L Summary Card
                    PLSummaryCard(plSummary: dataStore.ledgerOutput.plSummary)

                    // Open Positions Summary
                    OpenPositionsSummary(positions: dataStore.ledgerOutput.positions)

                    // Recent Activity
                    RecentActivityCard(
                        transactions: Array(dataStore.transactions.prefix(5))
                    )
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingTradeEntry = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingTradeEntry) {
                TradeEntryMenuView()
            }
        }
    }
}

struct PLSummaryCard: View {
    let plSummary: PLSummary

    var body: some View {
        VStack(spacing: 12) {
            Text("Total P/L")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(formatCurrency(plSummary.totalRealizedPL))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(plSummary.totalRealizedPL >= 0 ? .green : .red)

            HStack(spacing: 30) {
                VStack {
                    Text("Equity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(plSummary.equityRealizedPL))
                        .font(.headline)
                        .foregroundColor(plSummary.equityRealizedPL >= 0 ? .green : .red)
                }

                VStack {
                    Text("Options")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(plSummary.optionRealizedPL))
                        .font(.headline)
                        .foregroundColor(plSummary.optionRealizedPL >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }
}

struct OpenPositionsSummary: View {
    @EnvironmentObject var dataStore: DataStore
    let positions: [Position]

    var openPositions: [Position] {
        positions.filter { $0.isOpen }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Open Positions")
                    .font(.headline)
                Spacer()
                Text("\(openPositions.count)")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            if openPositions.isEmpty {
                Text("No open positions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(Array(openPositions.prefix(5))) { position in
                    PositionRowCompact(
                        position: position,
                        instrument: dataStore.instruments[position.instrumentId]
                    )
                }

                if openPositions.count > 5 {
                    NavigationLink("View All") {
                        PositionsView()
                    }
                    .font(.subheadline)
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct PositionRowCompact: View {
    let position: Position
    let instrument: Instrument?

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(instrument?.displayName ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(formatQuantity(position.quantity)) @ $\(formatPrice(position.averagePrice))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("$\(formatPrice(position.costBasis))")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }

    private func formatQuantity(_ value: Decimal) -> String {
        let num = NSDecimalNumber(decimal: value)
        return num.intValue == num.intValue ? "\(num.intValue)" : num.description
    }

    private func formatPrice(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0.00"
    }
}

struct RecentActivityCard: View {
    let transactions: [Transaction]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)

            if transactions.isEmpty {
                Text("No transactions yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(transactions) { txn in
                    TransactionRowCompact(transaction: txn)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct TransactionRowCompact: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(transaction.action.rawValue.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(transaction.action.isBuy ? .blue : .orange)
                Text(transaction.timestamp, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(transaction.quantity.description)")
                    .font(.subheadline)
                Text("@ \(transaction.price.description)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environmentObject(DataStore.shared)
    }
}
