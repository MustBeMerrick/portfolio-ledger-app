import Foundation

/// Transaction action types
enum TransactionAction: String, Codable {
    // Equity actions
    case buy
    case sell

    // Option actions
    case buyToOpen = "buy_to_open"
    case sellToOpen = "sell_to_open"
    case buyToClose = "buy_to_close"
    case sellToClose = "sell_to_close"

    var isEquity: Bool {
        self == .buy || self == .sell
    }

    var isOption: Bool {
        !isEquity
    }

    var isOpening: Bool {
        self == .buy || self == .buyToOpen || self == .sellToOpen
    }

    var isClosing: Bool {
        self == .sell || self == .buyToClose || self == .sellToClose
    }

    var isBuy: Bool {
        self == .buy || self == .buyToOpen || self == .buyToClose
    }

    var isSell: Bool {
        self == .sell || self == .sellToOpen || self == .sellToClose
    }
}

/// Flags for transaction state
struct TransactionFlags: Codable, Hashable {
    var consumedByAssignment: Bool = false

    init(consumedByAssignment: Bool = false) {
        self.consumedByAssignment = consumedByAssignment
    }
}

/// Immutable transaction record
struct Transaction: Identifiable, Codable, Hashable {
    let id: UUID
    let instrumentId: UUID
    let timestamp: Date
    let action: TransactionAction
    let quantity: Decimal // shares or contracts
    let price: Decimal // per share / per contract
    let fees: Decimal
    var notes: String
    var tags: [String]
    var linkGroupId: UUID? // For rolls & assignments
    var flags: TransactionFlags

    init(
        id: UUID = UUID(),
        instrumentId: UUID,
        timestamp: Date = Date(),
        action: TransactionAction,
        quantity: Decimal,
        price: Decimal,
        fees: Decimal = 0,
        notes: String = "",
        tags: [String] = [],
        linkGroupId: UUID? = nil,
        flags: TransactionFlags = TransactionFlags()
    ) {
        self.id = id
        self.instrumentId = instrumentId
        self.timestamp = timestamp
        self.action = action
        self.quantity = quantity
        self.price = price
        self.fees = fees
        self.notes = notes
        self.tags = tags
        self.linkGroupId = linkGroupId
        self.flags = flags
    }

    /// Total cost/proceeds (not including fees)
    var totalAmount: Decimal {
        quantity * price
    }

    /// Net amount including fees
    var netAmount: Decimal {
        if action.isBuy {
            return totalAmount + fees
        } else {
            return totalAmount - fees
        }
    }
}
