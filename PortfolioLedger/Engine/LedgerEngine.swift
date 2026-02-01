import Foundation

/// Pure functional ledger engine that processes transactions into derived state
class LedgerEngine {

    // MARK: - Main Processing Function

    /// Process all transactions and return derived ledger state
    static func process(
        transactions: [Transaction],
        instruments: [UUID: Instrument]
    ) -> LedgerOutput {
        var output = LedgerOutput()

        // Sort transactions by timestamp (chronological order)
        let sortedTxns = transactions.sorted { $0.timestamp < $1.timestamp }

        // Track lots
        var equityLots: [UUID: [EquityLot]] = [:] // keyed by instrumentId
        var optionLots: [UUID: [OptionLot]] = [:] // keyed by instrumentId

        // Process each transaction
        for txn in sortedTxns {
            guard let instrument = instruments[txn.instrumentId] else {
                continue // Skip transactions for unknown instruments
            }

            if instrument.type == .equity {
                processEquityTransaction(
                    txn: txn,
                    lots: &equityLots,
                    output: &output
                )
            } else if instrument.type == .option {
                processOptionTransaction(
                    txn: txn,
                    lots: &optionLots,
                    output: &output,
                    instrument: instrument
                )
            }
        }

        // Convert lots to positions
        output.equityLots = equityLots.values.flatMap { $0 }
        output.optionLots = optionLots.values.flatMap { $0 }
        output.positions = calculatePositions(
            equityLots: equityLots,
            optionLots: optionLots,
            instruments: instruments
        )

        // Build underlier summaries
        output.underlierSummaries = buildUnderlierSummaries(
            positions: output.positions,
            instruments: instruments,
            realizedPLs: output.realizedPLs
        )

        // Calculate P/L summary
        output.plSummary = calculatePLSummary(
            realizedPLs: output.realizedPLs,
            positions: output.positions,
            instruments: instruments
        )

        return output
    }

    // MARK: - Equity Processing

    private static func processEquityTransaction(
        txn: Transaction,
        lots: inout [UUID: [EquityLot]],
        output: inout LedgerOutput
    ) {
        switch txn.action {
        case .buy:
            // Create a new FIFO lot
            let lot = EquityLot(
                id: UUID(),
                transactionId: txn.id,
                instrumentId: txn.instrumentId,
                openDate: txn.timestamp,
                originalQuantity: txn.quantity,
                remainingQuantity: txn.quantity,
                costBasis: txn.netAmount,
                pricePerShare: txn.price
            )

            if lots[txn.instrumentId] == nil {
                lots[txn.instrumentId] = []
            }
            lots[txn.instrumentId]?.append(lot)

        case .sell:
            // Consume FIFO lots
            consumeEquityLots(
                txn: txn,
                lots: &lots,
                output: &output
            )

        default:
            break
        }
    }

    private static func consumeEquityLots(
        txn: Transaction,
        lots: inout [UUID: [EquityLot]],
        output: inout LedgerOutput
    ) {
        guard var instrumentLots = lots[txn.instrumentId] else {
            return
        }

        var remainingToSell = txn.quantity
        let proceeds = txn.netAmount
        let pricePerShare = txn.price

        for i in 0..<instrumentLots.count {
            guard remainingToSell > 0 else { break }

            var lot = instrumentLots[i]
            guard lot.isOpen else { continue }

            let quantityToConsume = min(lot.remainingQuantity, remainingToSell)
            let proportionConsumed = quantityToConsume / lot.originalQuantity
            let costBasisConsumed = lot.costBasis * proportionConsumed
            let proceedsForThisLot = pricePerShare * quantityToConsume - (txn.fees * (quantityToConsume / txn.quantity))

            // Create realized P/L record
            let realizedPL = RealizedPL(
                instrumentId: txn.instrumentId,
                closeDate: txn.timestamp,
                openDate: lot.openDate,
                quantity: quantityToConsume,
                proceeds: proceedsForThisLot,
                costBasis: costBasisConsumed,
                realizedPL: proceedsForThisLot - costBasisConsumed,
                transactionId: txn.id,
                openTransactionId: lot.transactionId
            )
            output.realizedPLs.append(realizedPL)

            // Update lot
            lot.remainingQuantity -= quantityToConsume
            instrumentLots[i] = lot

            remainingToSell -= quantityToConsume
        }

        lots[txn.instrumentId] = instrumentLots
    }

    // MARK: - Option Processing

    private static func processOptionTransaction(
        txn: Transaction,
        lots: inout [UUID: [OptionLot]],
        output: inout LedgerOutput,
        instrument: Instrument
    ) {
        let multiplier = Decimal(instrument.multiplier ?? 100)
        let scaledNetAmount = txn.netAmount * multiplier

        switch txn.action {
        case .buyToOpen, .sellToOpen:
            // Create a new option lot
            let lot = OptionLot(
                id: UUID(),
                transactionId: txn.id,
                instrumentId: txn.instrumentId,
                openDate: txn.timestamp,
                action: txn.action,
                originalQuantity: txn.quantity,
                remainingQuantity: txn.quantity,
                premium: scaledNetAmount,
                pricePerContract: txn.price
            )

            if lots[txn.instrumentId] == nil {
                lots[txn.instrumentId] = []
            }
            lots[txn.instrumentId]?.append(lot)

            // CASH BASIS: Record immediate P/L for option opening transactions
            // Sell to open = premium received (positive P/L)
            // Buy to open = premium paid (negative P/L)
            let cashFlow = txn.action == .sellToOpen ? scaledNetAmount : -scaledNetAmount

            let plRecord = RealizedPL(
                instrumentId: txn.instrumentId,
                closeDate: txn.timestamp,
                openDate: txn.timestamp,
                quantity: txn.quantity,
                proceeds: txn.action == .sellToOpen ? scaledNetAmount : 0,
                costBasis: txn.action == .buyToOpen ? scaledNetAmount : 0,
                realizedPL: cashFlow,
                transactionId: txn.id,
                openTransactionId: txn.id
            )
            output.realizedPLs.append(plRecord)

        case .buyToClose, .sellToClose:
            // Consume FIFO option lots
            consumeOptionLots(
                txn: txn,
                lots: &lots,
                output: &output,
                instrument: instrument
            )

        default:
            break
        }
    }

    private static func consumeOptionLots(
        txn: Transaction,
        lots: inout [UUID: [OptionLot]],
        output: inout LedgerOutput,
        instrument: Instrument
    ) {
        let multiplier = Decimal(instrument.multiplier ?? 100)
        let scaledNetAmount = txn.netAmount * multiplier

        guard var instrumentLots = lots[txn.instrumentId] else {
            return
        }

        var remainingToClose = txn.quantity

        for i in 0..<instrumentLots.count {
            guard remainingToClose > 0 else { break }

            var lot = instrumentLots[i]
            guard lot.isOpen else { continue }

            // Check if we're closing the right side (BTC closes STO, STC closes BTO)
            let isValidClose = (txn.action == .buyToClose && lot.action == .sellToOpen) ||
                              (txn.action == .sellToClose && lot.action == .buyToOpen)

            guard isValidClose else { continue }

            let quantityToConsume = min(lot.remainingQuantity, remainingToClose)

            // CASH BASIS: Record P/L based on closing transaction cash flow only
            // Buy to close = cash out (negative P/L)
            // Sell to close = cash in (positive P/L)
            let closePremiumPerContract = scaledNetAmount / txn.quantity
            let closePremiumForThisClose = closePremiumPerContract * quantityToConsume
            let cashFlow = txn.action == .sellToClose ? closePremiumForThisClose : -closePremiumForThisClose

            // Create realized P/L record for the closing transaction
            let plRecord = RealizedPL(
                instrumentId: txn.instrumentId,
                closeDate: txn.timestamp,
                openDate: lot.openDate,
                quantity: quantityToConsume,
                proceeds: txn.action == .sellToClose ? closePremiumForThisClose : 0,
                costBasis: txn.action == .buyToClose ? closePremiumForThisClose : 0,
                realizedPL: cashFlow,
                transactionId: txn.id,
                openTransactionId: lot.transactionId
            )
            output.realizedPLs.append(plRecord)

            // Update lot
            lot.remainingQuantity -= quantityToConsume
            instrumentLots[i] = lot

            remainingToClose -= quantityToConsume
        }

        lots[txn.instrumentId] = instrumentLots
    }

    // MARK: - Position Calculation

    private static func calculatePositions(
        equityLots: [UUID: [EquityLot]],
        optionLots: [UUID: [OptionLot]],
        instruments: [UUID: Instrument]
    ) -> [Position] {
        var positions: [Position] = []

        // Equity positions
        for (instrumentId, lots) in equityLots {
            let openLots = lots.filter { $0.isOpen }
            guard !openLots.isEmpty else { continue }

            let totalQuantity = openLots.reduce(0) { $0 + $1.remainingQuantity }
            let totalCostBasis = openLots.reduce(0) { $0 + ($1.costBasis * ($1.remainingQuantity / $1.originalQuantity)) }
            let avgPrice = totalQuantity > 0 ? totalCostBasis / totalQuantity : 0

            let position = Position(
                instrumentId: instrumentId,
                type: .equity,
                quantity: totalQuantity,
                costBasis: totalCostBasis,
                averagePrice: avgPrice
            )
            positions.append(position)
        }

        // Option positions
        for (instrumentId, lots) in optionLots {
            let openLots = lots.filter { $0.isOpen }
            guard !openLots.isEmpty else { continue }

            // Group by short vs long
            let shortLots = openLots.filter { $0.isShort }
            let longLots = openLots.filter { $0.isLong }

            // Net position (short contracts are negative, long are positive)
            let shortQuantity = shortLots.reduce(0) { $0 + $1.remainingQuantity }
            let longQuantity = longLots.reduce(0) { $0 + $1.remainingQuantity }
            let netQuantity = longQuantity - shortQuantity

            // For cost basis: longs increase cost, shorts reduce it (credit received)
            let longCostBasis = longLots.reduce(0) { $0 + ($1.premium * ($1.remainingQuantity / $1.originalQuantity)) }
            let shortCostBasis = shortLots.reduce(0) { $0 + ($1.premium * ($1.remainingQuantity / $1.originalQuantity)) }
            let totalCostBasis = longCostBasis - shortCostBasis // shorts are credits

            let avgPrice = abs(netQuantity) > 0 ? abs(totalCostBasis / netQuantity) : 0

            let position = Position(
                instrumentId: instrumentId,
                type: .option,
                quantity: netQuantity,
                costBasis: totalCostBasis,
                averagePrice: avgPrice
            )
            positions.append(position)
        }

        return positions
    }

    // MARK: - Underlier Summaries

    private static func buildUnderlierSummaries(
        positions: [Position],
        instruments: [UUID: Instrument],
        realizedPLs: [RealizedPL]
    ) -> [String: UnderlierSummary] {
        var summaries: [String: UnderlierSummary] = [:]

        // Group positions by underlying symbol
        for position in positions {
            guard let instrument = instruments[position.instrumentId] else { continue }
            let symbol = instrument.underlyingTicker

            if summaries[symbol] == nil {
                summaries[symbol] = UnderlierSummary(
                    symbol: symbol,
                    equityPosition: nil,
                    optionPositions: []
                )
            }

            if instrument.type == .equity {
                summaries[symbol]?.equityPosition = position
            } else {
                summaries[symbol]?.optionPositions.append(position)
            }
        }

        return summaries
    }

    // MARK: - P/L Summary

    private static func calculatePLSummary(
        realizedPLs: [RealizedPL],
        positions: [Position],
        instruments: [UUID: Instrument]
    ) -> PLSummary {
        var summary = PLSummary()

        summary.totalRealizedPL = realizedPLs.reduce(0) { $0 + $1.realizedPL }
        summary.equityRealizedPL = realizedPLs.filter { pl in
            instruments[pl.instrumentId]?.type == .equity
        }.reduce(0) { $0 + $1.realizedPL }
        summary.optionRealizedPL = realizedPLs.filter { pl in
            instruments[pl.instrumentId]?.type == .option
        }.reduce(0) { $0 + $1.realizedPL }

        // Unrealized P/L would require current prices, which we don't have here
        summary.totalUnrealizedPL = 0

        return summary
    }
}

// MARK: - Assignment Handling

extension LedgerEngine {

    /// Generate transactions for option assignment
    /// - Parameters:
    ///   - optionTransaction: The original option sell-to-open transaction
    ///   - instrument: The option instrument being assigned
    ///   - assignmentDate: When the assignment occurred
    ///   - equityInstrument: The underlying equity instrument
    /// - Returns: Tuple of (option close transaction, equity transaction)
    static func generateAssignmentTransactions(
        optionTransaction: Transaction,
        instrument: Instrument,
        assignmentDate: Date,
        equityInstrument: Instrument
    ) -> (optionClose: Transaction, equityTrade: Transaction) {

        guard instrument.type == .option,
              let strike = instrument.strike,
              let callPut = instrument.callPut,
              let multiplier = instrument.multiplier else {
            fatalError("Invalid option instrument for assignment")
        }

        let linkGroupId = UUID()
        let contractQuantity = optionTransaction.quantity
        let shareQuantity = contractQuantity * Decimal(multiplier)
        let premiumPerShare = optionTransaction.price / Decimal(multiplier)

        // Close the option position (consumed by assignment)
        let optionClose = Transaction(
            instrumentId: optionTransaction.instrumentId,
            timestamp: assignmentDate,
            action: .buyToClose,
            quantity: contractQuantity,
            price: 0, // Assignment closes at $0
            fees: 0,
            notes: "Assigned",
            tags: ["assignment"],
            linkGroupId: linkGroupId,
            flags: TransactionFlags(consumedByAssignment: true)
        )

        // Generate equity trade at effective price
        let effectivePrice: Decimal
        let equityAction: TransactionAction

        if callPut == .put {
            // Put assignment = we buy stock at strike minus premium received
            effectivePrice = strike - premiumPerShare
            equityAction = .buy
        } else {
            // Call assignment = we sell stock at strike plus premium received
            effectivePrice = strike + premiumPerShare
            equityAction = .sell
        }

        let equityTrade = Transaction(
            instrumentId: equityInstrument.id,
            timestamp: assignmentDate,
            action: equityAction,
            quantity: shareQuantity,
            price: effectivePrice,
            fees: 0,
            notes: "Option assignment",
            tags: ["assignment"],
            linkGroupId: linkGroupId
        )

        return (optionClose, equityTrade)
    }
}
