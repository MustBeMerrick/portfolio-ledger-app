import Foundation

// MARK: - Equity Lot

/// FIFO lot for equity positions
struct EquityLot: Identifiable {
    let id: UUID
    let transactionId: UUID
    let instrumentId: UUID
    let openDate: Date
    let originalQuantity: Decimal
    var remainingQuantity: Decimal
    let costBasis: Decimal // total cost including fees for this lot
    let pricePerShare: Decimal

    var isOpen: Bool {
        remainingQuantity > 0
    }

    var averageCostPerShare: Decimal {
        guard originalQuantity > 0 else { return 0 }
        return costBasis / originalQuantity
    }
}

// MARK: - Option Lot

/// FIFO lot for option positions
struct OptionLot: Identifiable {
    let id: UUID
    let transactionId: UUID
    let instrumentId: UUID
    let openDate: Date
    let action: TransactionAction // sellToOpen or buyToOpen
    let originalQuantity: Decimal
    var remainingQuantity: Decimal
    let premium: Decimal // total premium received/paid including fees
    let pricePerContract: Decimal

    var isOpen: Bool {
        remainingQuantity > 0
    }

    var isShort: Bool {
        action == .sellToOpen
    }

    var isLong: Bool {
        action == .buyToOpen
    }

    var averagePremiumPerContract: Decimal {
        guard originalQuantity > 0 else { return 0 }
        return premium / originalQuantity
    }
}

// MARK: - Position

/// Current position (equity or option)
struct Position: Identifiable {
    let id = UUID()
    let instrumentId: UUID
    let type: InstrumentType
    var quantity: Decimal // net quantity (can be 0)
    var costBasis: Decimal // total cost basis
    var averagePrice: Decimal // average cost per share/contract

    var isOpen: Bool {
        quantity != 0
    }

    func unrealizedPL(currentPrice: Decimal?) -> Decimal? {
        guard let price = currentPrice, quantity > 0 else { return nil }
        return (price * quantity) - costBasis
    }
}

// MARK: - Realized P/L

/// Realized profit/loss from a closed trade
struct RealizedPL: Identifiable {
    let id = UUID()
    let instrumentId: UUID
    let closeDate: Date
    let openDate: Date
    let quantity: Decimal
    let proceeds: Decimal // what we got
    let costBasis: Decimal // what we paid
    let realizedPL: Decimal // proceeds - costBasis
    let transactionId: UUID // closing transaction
    let openTransactionId: UUID // opening transaction

    var holdingPeriod: TimeInterval {
        closeDate.timeIntervalSince(openDate)
    }

    var holdingDays: Int {
        Int(holdingPeriod / 86400)
    }
}

// MARK: - Underlier Summary

/// Summary of all positions for a specific underlying symbol
struct UnderlierSummary: Identifiable {
    let symbol: String
    var id: String { symbol }

    var equityPosition: Position?
    var optionPositions: [Position]

    var totalEquityShares: Decimal {
        equityPosition?.quantity ?? 0
    }

    var averageEquityCost: Decimal {
        equityPosition?.averagePrice ?? 0
    }

    var totalEquityCostBasis: Decimal {
        equityPosition?.costBasis ?? 0
    }

    var openOptionContracts: Int {
        optionPositions.filter { $0.isOpen }.count
    }

    func unrealizedEquityPL(currentPrice: Decimal?) -> Decimal? {
        equityPosition?.unrealizedPL(currentPrice: currentPrice)
    }

    func totalRealizedPL(from realizedPLs: [RealizedPL]) -> Decimal {
        realizedPLs.reduce(0) { $0 + $1.realizedPL }
    }
}

// MARK: - P/L Summary

/// Aggregated P/L metrics
struct PLSummary {
    var totalRealizedPL: Decimal = 0
    var equityRealizedPL: Decimal = 0
    var optionRealizedPL: Decimal = 0
    var totalUnrealizedPL: Decimal = 0

    var totalPL: Decimal {
        totalRealizedPL + totalUnrealizedPL
    }
}

// MARK: - Ledger Output

/// Complete derived state from the ledger engine
struct LedgerOutput {
    var equityLots: [EquityLot]
    var optionLots: [OptionLot]
    var positions: [Position]
    var realizedPLs: [RealizedPL]
    var underlierSummaries: [String: UnderlierSummary]
    var plSummary: PLSummary

    init() {
        self.equityLots = []
        self.optionLots = []
        self.positions = []
        self.realizedPLs = []
        self.underlierSummaries = [:]
        self.plSummary = PLSummary()
    }
}
