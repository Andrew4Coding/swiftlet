//
//  CurrencyFormatter.swift
//  Swiftlet
//

import Foundation

/// Centralized Indonesian Rupiah formatting/parsing so every screen renders amounts consistently.
enum CurrencyFormatter {
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    /// Formats a decimal amount as "Rp 150.000".
    static func rupiah(_ amount: Decimal) -> String {
        let number = NSDecimalNumber(decimal: amount)
        let formatted = numberFormatter.string(from: number) ?? "0"
        return "Rp \(formatted)"
    }

    /// Compact formatting for chart axis labels, e.g. "Rp 1,2jt" / "Rp 500rb".
    static func rupiahCompact(_ amount: Decimal) -> String {
        let value = (amount as NSDecimalNumber).doubleValue
        let absValue = abs(value)
        switch absValue {
        case 1_000_000...:
            return String(format: "Rp %.1fjt", value / 1_000_000)
        case 1000...:
            return String(format: "Rp %.0frb", value / 1000)
        default:
            return rupiah(amount)
        }
    }

    /// Parses free-form user input (may contain "Rp", dots, commas, spaces) into a Decimal.
    static func parse(_ text: String) -> Decimal? {
        let digitsOnly = text.filter(\.isNumber)
        guard !digitsOnly.isEmpty, let value = Decimal(string: digitsOnly) else { return nil }
        return value
    }

    /// Digits-only string for editing in a text field, e.g. `45000`. Empty for zero.
    static func plainAmount(_ amount: Decimal) -> String {
        var input = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 0, .plain)
        let whole = NSDecimalNumber(decimal: rounded).intValue
        return whole == 0 ? "" : String(whole)
    }
}
