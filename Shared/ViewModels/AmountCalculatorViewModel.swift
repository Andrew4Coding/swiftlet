//
//  AmountCalculatorViewModel.swift
//  Swiftlet
//

import Foundation
import Observation

/// Drives the custom numpad in `AmountCalculatorView`. Behaves like a standard calculator
/// (single pending operator, left-to-right evaluation) but rounds every intermediate result
/// to a whole Rupiah, since the app has no fractional-currency support.
@Observable
final class AmountCalculatorViewModel {
    enum Operator: String, CaseIterable, Identifiable {
        case add = "+"
        case subtract = "−"
        case multiply = "×"
        case divide = "÷"

        var id: String {
            rawValue
        }

        func apply(_ lhs: Decimal, _ rhs: Decimal) -> Decimal {
            switch self {
            case .add: return lhs + rhs
            case .subtract: return lhs - rhs
            case .multiply: return lhs * rhs
            case .divide: return rhs == 0 ? lhs : lhs / rhs
            }
        }
    }

    /// Digits-only string for the operand currently being entered (unformatted).
    private(set) var currentInput: String = "0"
    /// Small trailing label above the main display, e.g. "Rp 12.000 +".
    private(set) var expressionDisplay: String = ""

    private var accumulatedValue: Decimal = 0
    private var pendingOperator: Operator?
    private var isEnteringNewNumber = true

    init(initialText: String = "") {
        let digits = initialText.filter(\.isNumber)
        if !digits.isEmpty {
            currentInput = digits
            isEnteringNewNumber = false
        }
    }

    private var currentValue: Decimal {
        Decimal(string: currentInput) ?? 0
    }

    /// The value that would be committed if Save were tapped right now.
    var finalValue: Decimal {
        if let pendingOperator {
            return roundedInteger(pendingOperator.apply(accumulatedValue, currentValue))
        }
        return currentValue
    }

    var formattedCurrentInput: String {
        CurrencyFormatter.rupiah(currentValue)
    }

    /// Appends `digits` to the operand being entered. Accepts multi-character input (e.g. "000")
    /// as well as single digits.
    func inputDigit(_ digits: String) {
        if isEnteringNewNumber {
            currentInput = digits
            isEnteringNewNumber = false
        } else if currentInput == "0" {
            currentInput = digits
        } else {
            currentInput += digits
        }
    }

    func inputOperator(_ op: Operator) {
        if !isEnteringNewNumber {
            if let pendingOperator {
                accumulatedValue = roundedInteger(pendingOperator.apply(accumulatedValue, currentValue))
            } else {
                accumulatedValue = currentValue
            }
        }
        pendingOperator = op
        expressionDisplay = "\(CurrencyFormatter.rupiah(accumulatedValue)) \(op.rawValue)"
        isEnteringNewNumber = true
    }

    func equals() {
        guard let pendingOperator else { return }
        let result = roundedInteger(pendingOperator.apply(accumulatedValue, currentValue))
        expressionDisplay = ""
        accumulatedValue = result
        currentInput = digitString(from: result)
        self.pendingOperator = nil
        isEnteringNewNumber = true
    }

    func setAmount(_ value: Int) {
        clear()
        currentInput = String(value)
        isEnteringNewNumber = false
    }

    func clear() {
        currentInput = "0"
        accumulatedValue = 0
        pendingOperator = nil
        expressionDisplay = ""
        isEnteringNewNumber = true
    }

    /// Deletes the rightmost digit of whatever is currently on screen, regardless of whether
    /// it's a fresh operand, a value the user just typed, or the result of `equals()`.
    func backspace() {
        if currentInput.count > 1 {
            currentInput.removeLast()
        } else {
            currentInput = "0"
        }
        isEnteringNewNumber = false
    }

    private func roundedInteger(_ value: Decimal) -> Decimal {
        var result = Decimal()
        var value = value
        NSDecimalRound(&result, &value, 0, .plain)
        return result
    }

    private func digitString(from value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
