//
//  Transaction+Display.swift
//  Swiftlet
//

import SwiftUI

extension TransactionType {
    var amountColor: Color {
        switch self {
        case .income: AppTheme.income
        case .expense: AppTheme.expense
        case .transfer: .secondary
        }
    }
}
