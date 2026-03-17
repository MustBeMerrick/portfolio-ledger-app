import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var searchText = ""
    @State private var filterSymbol: String?
    @State private var showingLinkedDeleteAlert = false
    @State private var pendingDeleteTransactions: [Transaction] = []
    @State private var pendingLinkedTransactions: [Transaction] = []

    private var allTransactions: [Transaction] {
        dataStore.transactions + dataStore.ledgerOutput.syntheticTransactions
    }

    private var filteredTransactions: [Transaction] {
        var txns = allTransactions

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

        let allRealizedPLs = dataStore.ledgerOutput.realizedPLs

        // Map: buy transactionId -> EquityLot (to check if fully closed)
        let lotByBuyTxId: [UUID: EquityLot] = dataStore.ledgerOutput.equityLots
            .reduce(into: [:]) { $0[$1.transactionId] = $1 }

        // Map: buy transactionId -> sell transactionIds that closed it (via realizedPLs)
        var sellIdsByBuyTxId: [UUID: [UUID]] = [:]
        for pl in allRealizedPLs {
            guard let instrument = dataStore.instruments[pl.instrumentId], instrument.type == .equity else { continue }
            sellIdsByBuyTxId[pl.openTransactionId, default: []].append(pl.transactionId)
        }

        // Pre-compute which sell txIds are absorbed into an equity group row.
        // Any buy with P/L (fully OR partially consumed) owns its closing sell(s).
        // Use ALL transactions so search filters don't break grouping.
        let allTxById: [UUID: Transaction] = allTransactions.reduce(into: [:]) { $0[$1.id] = $1 }
        var groupedSellTxIds = Set<UUID>()
        for txn in allTransactions {
            guard let instrument = dataStore.instruments[txn.instrumentId],
                  instrument.type == .equity, txn.action == .buy,
                  let sellIds = sellIdsByBuyTxId[txn.id] else { continue }
            sellIds.forEach { groupedSellTxIds.insert($0) }
        }

        for txn in filteredTransactions {
            guard let instrument = dataStore.instruments[txn.instrumentId] else {
                rows.append(LedgerRow.single(transaction: txn, instrument: nil))
                continue
            }

            if instrument.type == .option {
                let key = txn.instrumentId.uuidString
                optionGroups[key, default: []].append(txn)
            } else if instrument.type == .equity {
                if txn.action == .buy, let sellIds = sellIdsByBuyTxId[txn.id] {
                    // This buy has been at least partially closed — show a closed group row
                    let pls = allRealizedPLs.filter { $0.openTransactionId == txn.id }
                    let sells = Set(sellIds).compactMap { allTxById[$0] }.sorted { $0.timestamp < $1.timestamp }
                    rows.append(LedgerRow.equityGroup(transactions: [txn] + sells, instrument: instrument, realizedPLs: pls))

                    // If partially consumed, also show the remaining open shares as a separate row
                    if let lot = lotByBuyTxId[txn.id], lot.isOpen {
                        rows.append(LedgerRow.openRemainder(buyTransaction: txn, remainingQty: lot.remainingQuantity, instrument: instrument))
                    }
                } else if txn.action == .sell && groupedSellTxIds.contains(txn.id) {
                    // This sell is absorbed into a buy group — skip
                    continue
                } else {
                    // Untouched buy or standalone sell: individual row
                    rows.append(LedgerRow.single(transaction: txn, instrument: instrument, realizedPLs: []))
                }
            } else {
                rows.append(LedgerRow.single(transaction: txn, instrument: instrument))
            }
        }

        for (_, txns) in optionGroups {
            guard let first = txns.first else { continue }
            let instrument = dataStore.instruments[first.instrumentId]
            let pls = allRealizedPLs.filter { $0.instrumentId == first.instrumentId }
            rows.append(LedgerRow.optionGroup(transactions: txns, instrument: instrument, realizedPLs: pls))
        }

        return rows.sorted { $0.openingTimestamp > $1.openingTimestamp }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(ledgerRows) { row in
                    TransactionDetailRow(row: row)
                        .listRowBackground(row.isClosed ? Color(red: 0.82, green: 0.82, blue: 0.84) : nil)
                }
                .onDelete(perform: deleteTransactions)
            }
            .searchable(text: $searchText, prompt: "Search notes or tags")
            .navigationTitle("Ledger")
            .alert("Delete Assignment", isPresented: $showingLinkedDeleteAlert) {
                Button("Delete Both", role: .destructive) {
                    dataStore.deleteTransactions(pendingDeleteTransactions + pendingLinkedTransactions)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                let names = pendingLinkedTransactions
                    .compactMap { dataStore.instruments[$0.instrumentId]?.displayName }
                    .joined(separator: ", ")
                Text("This transaction is linked to an option assignment. Deleting it will also delete \(names.isEmpty ? "a linked transaction" : names). This cannot be undone.")
            }
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
            let rowTxns = row.isOptionGroup || row.isEquityGroup ? row.transactions : [row.transaction].compactMap { $0 }
            let linked = dataStore.linkedAssignmentTransactions(for: rowTxns)
            if !linked.isEmpty {
                pendingDeleteTransactions = rowTxns
                pendingLinkedTransactions = linked
                showingLinkedDeleteAlert = true
            } else {
                dataStore.deleteTransactions(rowTxns)
            }
        }
    }
}

struct TransactionDetailRow: View {
    let row: LedgerRow

    var body: some View {
        let isEquityRow = row.isEquityGroup || (row.transaction?.action.isEquity == true)
        VStack(alignment: .leading, spacing: 8) {

            if isEquityRow {
                let buyColor  = Color(red: 0.55, green: 0.10, blue: 0.15)
                let sellColor = Color(red: 0.00, green: 0.38, blue: 0.10)
                let plColor: Color = equityDisplayPL.map { $0 >= 0 ? .green : .red } ?? .secondary
                let qtyStr  = equityDisplayQty.asQuantity
                let buyStr  = equityDisplayBuyPrice.map  { "$\(formatPrice($0))" } ?? "—"
                let sellStr = equityDisplaySellPrice.map { "$\(formatPrice($0))" } ?? "—"
                let plStr   = equityDisplayPL.map { formatCurrency($0) } ?? "—"
                let openDate  = row.openingTransactions.first?.timestamp
                let closeDate = row.closingTransactions.first?.timestamp

                // Symbol + P/L on same top row
                HStack(alignment: .firstTextBaseline) {
                    Text(row.instrument?.displayName ?? "Unknown")
                        .font(.headline).fontWeight(.bold)
                    Spacer()
                    Text("P/L")
                        .font(.subheadline).foregroundColor(.secondary)
                    Text(plStr)
                        .font(.body).fontWeight(.bold).foregroundColor(plColor)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }

                // Shares | Buy | Sell
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(" ").font(.caption)
                        Spacer().frame(height: 4)
                        Text("Shares").font(.subheadline).foregroundColor(.secondary)
                        Text(qtyStr).font(.body).fontWeight(.semibold)
                    }
                    .frame(width: 60, alignment: .leading)
                    VStack(alignment: .center, spacing: 0) {
                        if let d = openDate {
                            Text(d, format: .dateTime.month(.abbreviated).day())
                                .font(.caption).foregroundColor(.secondary)
                        } else {
                            Text(" ").font(.caption)
                        }
                        Spacer().frame(height: 4)
                        Text("Buy").font(.subheadline).foregroundColor(buyColor)
                        Text(buyStr).font(.body).fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    VStack(alignment: .center, spacing: 0) {
                        if let d = closeDate {
                            Text(d, format: .dateTime.month(.abbreviated).day())
                                .font(.caption).foregroundColor(.secondary)
                        } else {
                            Text(" ").font(.caption)
                        }
                        Spacer().frame(height: 4)
                        Text("Sell").font(.subheadline).foregroundColor(sellColor)
                        Text(sellStr).font(.body).fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                if row.isOptionGroup {
                    // Title + P/L on same top row (mirrors equity layout)
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.instrument?.displayName ?? "Unknown Instrument")
                            .font(.headline).fontWeight(.bold)
                        Spacer()
                        if !row.realizedPLs.isEmpty {
                            Text("P/L")
                                .font(.subheadline).foregroundColor(.secondary)
                            Text(formatCurrency(optionTotalPL))
                                .font(.body).fontWeight(.bold)
                                .foregroundColor(optionTotalPL >= 0 ? .green : .red)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                } else {
                    // Non-option single rows
                    if let inst = row.instrument {
                        Text(inst.displayName).font(.headline).fontWeight(.bold)
                    } else {
                        Text("Unknown Instrument").font(.headline).foregroundColor(.secondary)
                    }
                }

                if row.isOptionGroup {

                    // Qty | Open | Close columns
                    HStack(alignment: .top, spacing: 0) {
                        // Qty
                        VStack(alignment: .leading, spacing: 0) {
                            Text(" ").font(.caption)
                            Spacer().frame(height: 4)
                            Text("Qty").font(.subheadline).foregroundColor(.secondary)
                            Text(optionQuantity.asQuantity).font(.body).fontWeight(.semibold)
                        }
                        .frame(width: 50, alignment: .leading)

                        // Open column (STO / BTO)
                        VStack(alignment: .center, spacing: 0) {
                            if let d = row.openingTransactions.first?.timestamp {
                                Text(d, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption).foregroundColor(.secondary)
                            } else {
                                Text(" ").font(.caption)
                            }
                            Spacer().frame(height: 4)
                            Text(openLabel).font(.subheadline).foregroundColor(openActionColor)
                            Text("$\(formatPrice(optionOpenPrice))").font(.body).fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                        // Close column (BTC / STC / ASSIGN / EXPIRE)
                        VStack(alignment: .center, spacing: 0) {
                            if let d = row.closingTransactions.first?.timestamp {
                                Text(d, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption).foregroundColor(.secondary)
                            } else {
                                Text(" ").font(.caption)
                            }
                            Spacer().frame(height: 4)
                            if hasClosing {
                                Text(closeLabel).font(.subheadline).foregroundColor(closeActionColor)
                                Text("$\(formatPrice(optionClosePrice))").font(.body).fontWeight(.medium)
                            } else {
                                Text("—").font(.subheadline).foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }

            // Fees if present
            if let transaction = row.transaction, transaction.fees > 0 {
                Text("Fees: \(transaction.fees.asCurrency)")
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
        case .expire:
            return .gray
        case .assign:
            return .purple
        }
    }

    private var badgeAction: TransactionAction {
        if row.isOptionGroup {
            if let open = row.openingTransactions.first {
                return open.action
            }
        }
        if row.isEquityGroup {
            // Always show the opening action — the position was opened by buying
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
        if row.closingTransactions.contains(where: { $0.action == .assign || $0.flags.consumedByAssignment }) { return "ASSIGN" }
        if row.closingTransactions.contains(where: { $0.action == .expire }) { return "EXPIRE" }
        return row.closingTransactions.contains { $0.action == .buyToClose } ? "BTC" : "STC"
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
        // For closed groups, use P/L qty — it reflects only the shares from this
        // specific lot, even if the sell transaction spanned multiple lots.
        if row.isEquityGroup && !row.realizedPLs.isEmpty {
            return row.realizedPLs.reduce(0) { $0 + $1.quantity }
        }
        return row.openingTransactions.reduce(0) { $0 + $1.quantity }
    }

    private var equityBuyPrice: Decimal {
        weightedAveragePrice(for: row.openingTransactions)
    }

    private var equitySellPrice: Decimal {
        weightedAveragePrice(for: row.closingTransactions)
    }

    private var equityTotalPL: Decimal {
        row.realizedPLs.reduce(0) { $0 + $1.realizedPL }
    }

    // Unified equity display helpers — work for both group and single rows

    private var equityDisplayQty: Decimal {
        if row.isEquityGroup { return equityQuantity }
        return row.quantityOverride ?? (row.transaction?.quantity ?? 0)
    }

    private var equityDisplayBuyPrice: Decimal? {
        if row.isEquityGroup { return equityBuyPrice }
        guard row.transaction?.action == .buy else { return nil }
        return row.transaction?.price
    }

    private var equityDisplaySellPrice: Decimal? {
        if row.isEquityGroup { return equitySellPrice }
        guard row.transaction?.action == .sell else { return nil }
        return row.transaction?.price
    }

    private var equityDisplayPL: Decimal? {
        guard !row.realizedPLs.isEmpty else { return nil }
        return equityTotalPL
    }

    private var optionTotalPL: Decimal {
        row.realizedPLs.reduce(0) { $0 + $1.realizedPL }
    }

    private var openActionColor: Color {
        let isSell = row.openingTransactions.contains { $0.action == .sellToOpen }
        return isSell ? Color(red: 0.00, green: 0.38, blue: 0.10) : Color(red: 0.55, green: 0.10, blue: 0.15)
    }

    private var closeActionColor: Color {
        if row.closingTransactions.contains(where: { $0.action == .assign || $0.flags.consumedByAssignment }) { return .purple }
        if row.closingTransactions.contains(where: { $0.action == .expire }) { return .gray }
        let isBuy = row.closingTransactions.contains { $0.action == .buyToClose }
        return isBuy ? Color(red: 0.55, green: 0.10, blue: 0.15) : Color(red: 0.00, green: 0.38, blue: 0.10)
    }

    private func weightedAveragePrice(for txns: [Transaction]) -> Decimal {
        let totalQty = txns.reduce(0) { $0 + $1.quantity }
        guard totalQty > 0 else { return 0 }
        let total = txns.reduce(0) { $0 + ($1.price * $1.quantity) }
        return total / totalQty
    }

    private func formatPrice(_ value: Decimal) -> String { value.asPrice }

    private func formatCurrency(_ value: Decimal) -> String { value.asCurrency }
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
    let realizedPLs: [RealizedPL]
    /// Overrides the displayed quantity for open-remainder rows (partial lot split).
    let quantityOverride: Decimal?

    static func single(transaction: Transaction, instrument: Instrument?, realizedPLs: [RealizedPL] = []) -> LedgerRow {
        LedgerRow(
            id: transaction.id.uuidString,
            transaction: transaction,
            transactions: [transaction],
            instrument: instrument,
            latestTimestamp: transaction.timestamp,
            openingTimestamp: transaction.timestamp,
            isOptionGroup: false,
            isEquityGroup: false,
            realizedPLs: realizedPLs,
            quantityOverride: nil
        )
    }

    /// An open sub-row representing the remaining shares of a partially-consumed buy lot.
    static func openRemainder(buyTransaction: Transaction, remainingQty: Decimal, instrument: Instrument?) -> LedgerRow {
        LedgerRow(
            id: "equity-remainder-\(buyTransaction.id.uuidString)",
            transaction: buyTransaction,
            transactions: [buyTransaction],
            instrument: instrument,
            latestTimestamp: buyTransaction.timestamp,
            openingTimestamp: buyTransaction.timestamp,
            isOptionGroup: false,
            isEquityGroup: false,
            realizedPLs: [],
            quantityOverride: remainingQty
        )
    }

    static func optionGroup(transactions: [Transaction], instrument: Instrument?, realizedPLs: [RealizedPL] = []) -> LedgerRow {
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
            isEquityGroup: false,
            realizedPLs: realizedPLs,
            quantityOverride: nil
        )
    }

    static func equityGroup(transactions: [Transaction], instrument: Instrument?, realizedPLs: [RealizedPL] = []) -> LedgerRow {
        let latest = transactions.map(\.timestamp).max() ?? Date.distantPast
        let openingTxns = transactions.filter { $0.action == .buy }
        let opening = openingTxns.map(\.timestamp).min() ?? transactions.map(\.timestamp).min() ?? Date.distantPast
        // Use the buy transaction ID (not instrument ID) to avoid collisions across multiple
        // closed positions in the same stock.
        let buyTxId = openingTxns.first?.id.uuidString ?? UUID().uuidString
        return LedgerRow(
            id: "equity-\(buyTxId)",
            transaction: nil,
            transactions: transactions,
            instrument: instrument,
            latestTimestamp: latest,
            openingTimestamp: opening,
            isOptionGroup: false,
            isEquityGroup: true,
            realizedPLs: realizedPLs,
            quantityOverride: nil
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
            $0.action == .sell ||
            $0.action == .assign ||
            $0.action == .expire
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
            // Equity groups are created whenever a buy has P/L records (fully or partially
            // consumed). The group always represents the closed portion, so it's always closed.
            return !realizedPLs.isEmpty
        }

        return false
    }
}
