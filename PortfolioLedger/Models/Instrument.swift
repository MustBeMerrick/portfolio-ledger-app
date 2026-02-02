import Foundation

/// Type of instrument
enum InstrumentType: String, Codable {
    case equity
    case option
}

/// Call or Put option type
enum OptionType: String, Codable {
    case call
    case put
}

/// Represents a financial instrument (equity or option)
struct Instrument: Identifiable, Codable, Hashable {
    let id: UUID
    let type: InstrumentType

    // Equity fields
    var symbol: String? // For equity

    // Option fields
    var underlyingSymbol: String? // For options
    var expiry: Date? // For options
    var strike: Decimal? // For options
    var callPut: OptionType? // For options
    var multiplier: Int? // For options (default 100)

    init(
        id: UUID = UUID(),
        symbol: String
    ) {
        self.id = id
        self.type = .equity
        self.symbol = symbol
    }

    init(
        id: UUID = UUID(),
        underlyingSymbol: String,
        expiry: Date,
        strike: Decimal,
        callPut: OptionType,
        multiplier: Int = 100
    ) {
        self.id = id
        self.type = .option
        self.underlyingSymbol = underlyingSymbol
        self.expiry = expiry
        self.strike = strike
        self.callPut = callPut
        self.multiplier = multiplier
    }

    /// Display name for the instrument
    var displayName: String {
        switch type {
        case .equity:
            return symbol ?? "Unknown"
        case .option:
            guard let underlying = underlyingSymbol,
                  let exp = expiry,
                  let stk = strike,
                  let cp = callPut else {
                return "Invalid Option"
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yy"
            let expStr = formatter.string(from: exp)
            let cpStr = cp == .call ? "C" : "P"
            return "\(underlying) \(expStr) \(stk)\(cpStr)"
        }
    }

    /// Get the underlying symbol (equity symbol or option's underlying)
    var underlyingTicker: String {
        switch type {
        case .equity:
            return symbol ?? ""
        case .option:
            return underlyingSymbol ?? ""
        }
    }
}
