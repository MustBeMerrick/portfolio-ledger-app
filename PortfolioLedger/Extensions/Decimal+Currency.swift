import Foundation

extension Decimal {
    /// Formats as a full USD currency string, e.g. "$1,234.56"
    var asCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$0.00"
    }

    /// Formats as a price string with 2 decimal places and thousands separators, e.g. "1,234.56"
    var asPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "0.00"
    }

    /// Formats as a quantity with thousands separators and no trailing zeros, e.g. "1,000" or "1,000.5"
    var asQuantity: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? self.description
    }
}
