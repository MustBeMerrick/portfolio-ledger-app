import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var searchText = ""
    @State private var filterSymbol: String?

    private var filteredTransactions: [Transaction] {
        var txns = dataStore.transactions

        if !searchText.isEmpty {
            txns = txns.filter { txn in
                txn.notes.localizedCaseInsensitiveContains(searchText) ||
                txn.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }

        return txns.sorted { $0.timestamp > $1.timestamp }
    }

    private var ledgerRows: [LedgerRow] {
        var rows: [LedgerRow] = []
        var optionGroups: [String: [Transaction]] = [:]
        var equityGroups: [String: [Transaction]] = [:]

        for txn in filteredTransactions {
            guard let instrument = dataStore.instruments[txn.instrumentId] else {
                rows.append(LedgerRow.single(transaction: txn, instrument: nil))
                continue
            }

            if instrument.type == .option {
                let key = txn.instrumentId.uuidString
                optionGroups[key, default: []].append(txn)
            } else if instrument.type == .equity {
                let key = txn.instrumentId.uuidString
                equityGroups[key, default: []].append(txn)
            } else {
                rows.append(LedgerRow.single(transaction: txn, instrument: instrument))
            }
        }

        for (_, txns) in optionGroups {
            guard let first = txns.first else { continue }
            let instrument = dataStore.instruments[first.instrumentId]
            rows.append(LedgerRow.optionGroup(transactions: txns, instrument: instrument))
        }

        for (_, txns) in equityGroups {
            guard let first = txns.first else { continue }
            let instrument = dataStore.instruments[first.instrumentId]
            rows.append(LedgerRow.equityGroup(transactions: txns, instrument: instrument))
        }

        return rows.sorted { $0.openingTimestamp > $1.openingTimestamp }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(ledgerRows) { row in
                    TransactionDetailRow(row: row)
                }
                .onDelete(perform: deleteTransactions)
            }
            .searchable(text: $searchText, prompt: "Search notes or tags")
            .navigationTitle("Ledger")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Add Trade") {
                            // Show trade entry
                        }
                        Button("Export CSV") {
                            // Export
                        }
                        Button("Import CSV") {
                            // Import
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private func deleteTransactions(at offsets: IndexSet) {
        for index in offsets {
            let row = ledgerRows[index]
            if row.isOptionGroup || row.isEquityGroup {
                for txn in row.transactions {
                    dataStore.deleteTransaction(txn)
                }
            } else if let transaction = row.transaction {
                dataStore.deleteTransaction(transaction)
            }
        }
    }
}

struct TransactionDetailRow: View {
    let row: LedgerRow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Action badge (hidden for fully closed groups)
                if !row.isClosed {
                    Text(badgeText)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(actionColor.opacity(0.2))
                        .foregroundColor(actionColor)
                        .cornerRadius(4)
                }

                Spacer()

                // Timestamp
                Text(row.latestTimestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Instrument
            if let inst = row.instrument {
                Text(inst.displayName)
                    .font(.headline)
            } else {
                Text("Unknown Instrument")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            // Trade details
            if row.isOptionGroup {
                HStack {
                    Text("Qty:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(optionQuantity.description)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(openLabel):")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("$\(formatPrice(optionOpenPrice))")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    if hasClosing {
                        Text("\(closeLabel):")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("$\(formatPrice(optionClosePrice))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    } else {
                        Text("Close:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("—")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }

                HStack {
                    Text("P/L:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(optionTotalPL))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(optionTotalPL >= 0 ? .green : .red)
                }
            } else if row.isEquityGroup {
                HStack {
                    Text("Qty:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(equityQuantity.description)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("BUY:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("$\(formatPrice(equityBuyPrice))")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("SELL:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("$\(formatPrice(equitySellPrice))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                HStack {
                    Text("P/L:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(equityTotalPL))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(equityTotalPL >= 0 ? .green : .red)
                }
            } else if let transaction = row.transaction {
                HStack {
                    Text("Qty:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(transaction.quantity.description)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("Price:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("$\(transaction.price.description)")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("Total:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("$\(transaction.totalAmount.description)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
            }

            // Fees if present
            if let transaction = row.transaction, transaction.fees > 0 {
                Text("Fees: $\(transaction.fees.description)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Notes if present
            if let transaction = row.transaction, !transaction.notes.isEmpty {
                Text(transaction.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }

            // Tags if present
            if let transaction = row.transaction, !transaction.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(transaction.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var actionColor: Color {
        switch badgeAction {
        case .buy, .buyToOpen, .buyToClose:
            return .blue
        case .sell, .sellToOpen, .sellToClose:
            return .orange
        }
    }

    private var badgeAction: TransactionAction {
        if row.isOptionGroup {
            if let open = row.openingTransactions.first {
                return open.action
            }
        }
        if row.isEquityGroup {
            if let sell = row.closingTransactions.first {
                return sell.action
            }
            if let buy = row.openingTransactions.first {
                return buy.action
            }
        }
        if let txn = row.transaction {
            return txn.action
        }
        return .buy
    }

    private var badgeText: String {
        if row.isOptionGroup || row.isEquityGroup {
            return badgeAction.rawValue.uppercased()
        }
        return row.transaction?.action.rawValue.uppercased() ?? "UNKNOWN"
    }

    private var optionQuantity: Decimal {
        row.openingTransactions.reduce(0) { $0 + $1.quantity }
    }

    private var openLabel: String {
        row.openingTransactions.contains { $0.action == .sellToOpen } ? "STO" : "BTO"
    }

    private var closeLabel: String {
        row.closingTransactions.contains { $0.action == .buyToClose } ? "BTC" : "STC"
    }

    private var optionOpenPrice: Decimal {
        weightedAveragePrice(for: row.openingTransactions)
    }

    private var optionClosePrice: Decimal {
        weightedAveragePrice(for: row.closingTransactions)
    }

    private var hasClosing: Bool {
        !row.closingTransactions.isEmpty
    }

    private var equityQuantity: Decimal {
        let buys = row.openingTransactions.reduce(0) { $0 + $1.quantity }
        let sells = row.closingTransactions.reduce(0) { $0 + $1.quantity }
        return max(buys, sells)
    }

    private var equityBuyPrice: Decimal {
        weightedAveragePrice(for: row.openingTransactions)
    }

    private var equitySellPrice: Decimal {
        weightedAveragePrice(for: row.closingTransactions)
    }

    private var equityTotalPL: Decimal {
        row.equityTransactions.reduce(0) { partial, txn in
            let cashFlow = txn.action.isSell ? txn.netAmount : -txn.netAmount
            return partial + cashFlow
        }
    }

    private var optionTotalPL: Decimal {
        guard let inst = row.instrument else { return 0 }
        let multiplier = Decimal(inst.multiplier ?? 100)
        return row.optionTransactions.reduce(0) { partial, txn in
            let cashFlow = txn.action.isSell ? txn.netAmount : -txn.netAmount
            return partial + (cashFlow * multiplier)
        }
    }

    private func weightedAveragePrice(for txns: [Transaction]) -> Decimal {
        let totalQty = txns.reduce(0) { $0 + $1.quantity }
        guard totalQty > 0 else { return 0 }
        let total = txns.reduce(0) { $0 + ($1.price * $1.quantity) }
        return total / totalQty
    }

    private func formatPrice(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0.00"
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }
}

struct TransactionsView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionsView()
            .environmentObject(DataStore.shared)
    }
}

struct LedgerRow: Identifiable {
    let id: String
    let transaction: Transaction?
    let transactions: [Transaction]
    let instrument: Instrument?
    let latestTimestamp: Date
    let openingTimestamp: Date
    let isOptionGroup: Bool
    let isEquityGroup: Bool

    static func single(transaction: Transaction, instrument: Instrument?) -> LedgerRow {
        LedgerRow(
            id: transaction.id.uuidString,
            transaction: transaction,
            transactions: [transaction],
            instrument: instrument,
            latestTimestamp: transaction.timestamp,
            openingTimestamp: transaction.timestamp,
            isOptionGroup: instrument?.type == .option,
            isEquityGroup: instrument?.type == .equity
        )
    }

    static func optionGroup(transactions: [Transaction], instrument: Instrument?) -> LedgerRow {
        let latest = transactions.map(\.timestamp).max() ?? Date.distantPast
        let openingTxns = transactions.filter { $0.action == .buyToOpen || $0.action == .sellToOpen }
        let opening = openingTxns.map(\.timestamp).min() ?? transactions.map(\.timestamp).min() ?? Date.distantPast
        let keyInstrument = transactions.first?.instrumentId.uuidString ?? UUID().uuidString
        return LedgerRow(
            id: keyInstrument,
            transaction: nil,
            transactions: transactions,
            instrument: instrument,
            latestTimestamp: latest,
            openingTimestamp: opening,
            isOptionGroup: true,
            isEquityGroup: false
        )
    }

    static func equityGroup(transactions: [Transaction], instrument: Instrument?) -> LedgerRow {
        let latest = transactions.map(\.timestamp).max() ?? Date.distantPast
        let openingTxns = transactions.filter { $0.action == .buy }
        let opening = openingTxns.map(\.timestamp).min() ?? transactions.map(\.timestamp).min() ?? Date.distantPast
        let keyInstrument = transactions.first?.instrumentId.uuidString ?? UUID().uuidString
        return LedgerRow(
            id: "equity-\(keyInstrument)",
            transaction: nil,
            transactions: transactions,
            instrument: instrument,
            latestTimestamp: latest,
            openingTimestamp: opening,
            isOptionGroup: false,
            isEquityGroup: true
        )
    }

    var openingTransactions: [Transaction] {
        transactions.filter {
            $0.action == .buyToOpen ||
            $0.action == .sellToOpen ||
            $0.action == .buy
        }
    }

    var closingTransactions: [Transaction] {
        transactions.filter {
            $0.action == .buyToClose ||
            $0.action == .sellToClose ||
            $0.action == .sell
        }
    }

    var optionTransactions: [Transaction] {
        transactions.filter { $0.action.isOption }
    }

    var equityTransactions: [Transaction] {
        transactions.filter { $0.action.isEquity }
    }

    var isClosed: Bool {
        if isOptionGroup {
            let openQty = openingTransactions.reduce(0) { $0 + $1.quantity }
            let closeQty = closingTransactions.reduce(0) { $0 + $1.quantity }
            return openQty > 0 && openQty == closeQty
        }

        if isEquityGroup {
            let buyQty = openingTransactions.reduce(0) { $0 + $1.quantity }
            let sellQty = closingTransactions.reduce(0) { $0 + $1.quantity }
            return buyQty > 0 && buyQty == sellQty
        }

        return false
    }
}
