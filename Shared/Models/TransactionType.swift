//
//  TransactionType.swift
//  Swiftlet
//

import AppIntents
import Foundation

enum TransactionType: String, Codable, CaseIterable, Identifiable, AppEnum {
    case expense
    case income
    case transfer

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .expense: "Expense"
        case .income: "Income"
        case .transfer: "Transfer"
        }
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Transaction Type"
    }

    static var caseDisplayRepresentations: [TransactionType: DisplayRepresentation] {
        [.expense: "Expense", .income: "Income", .transfer: "Transfer"]
    }
}
