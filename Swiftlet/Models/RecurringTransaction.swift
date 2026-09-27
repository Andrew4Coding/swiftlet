//
//  RecurringTransaction.swift
//  Swiftlet
//

import Foundation
import SwiftData

enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly
    case yearly

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    var component: Calendar.Component {
        switch self {
        case .weekly: .weekOfYear
        case .monthly: .month
        case .yearly: .year
        }
    }

    /// Rough monthly weight, used only for the "per month" estimate on the subscriptions screen.
    var monthlyFactor: Decimal {
        switch self {
        case .weekly: Decimal(52) / Decimal(12)
        case .monthly: 1
        case .yearly: Decimal(1) / Decimal(12)
        }
    }
}

@Model
final class RecurringTransaction {
    var title: String = ""
    var amount: Decimal = 0
    var typeRaw: String = TransactionType.expense.rawValue
    var frequencyRaw: String = RecurrenceFrequency.monthly.rawValue
    var startDate: Date = Date.now
    var nextDueDate: Date = Date.now
    var isActive: Bool = true
    var remindsBeforeDue: Bool = true
    var note: String = ""
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \TransactionCategory.recurringTransactions)
    var category: TransactionCategory?

    @Relationship(deleteRule: .nullify, inverse: \Wallet.recurringTransactions)
    var wallet: Wallet?

    @Relationship(deleteRule: .nullify, inverse: \Transaction.recurringSource)
    var generatedTransactions: [Transaction]? = []

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var frequency: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    var monthlyEstimate: Decimal {
        amount * frequency.monthlyFactor
    }

    init(
        title: String,
        amount: Decimal,
        type: TransactionType,
        frequency: RecurrenceFrequency,
        startDate: Date,
        category: TransactionCategory?,
        wallet: Wallet?
    ) {
        self.title = title
        self.amount = amount
        typeRaw = type.rawValue
        frequencyRaw = frequency.rawValue
        self.startDate = startDate
        nextDueDate = startDate
        self.category = category
        self.wallet = wallet
    }

    /// Steps from `startDate` rather than from the previous occurrence so month-end dates don't
    /// drift (Jan 31 → Feb 28 → Mar 31, not Mar 28).
    func occurrence(after date: Date, calendar: Calendar = .current) -> Date {
        var step = 1
        while let candidate = calendar.date(byAdding: frequency.component, value: step, to: startDate) {
            if candidate > date {
                return candidate
            }
            step += 1
        }
        return date
    }
}
