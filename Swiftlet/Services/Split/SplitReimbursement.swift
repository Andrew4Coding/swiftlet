//
//  SplitReimbursement.swift
//  Swiftlet
//

import Foundation
import SwiftData

enum SplitReimbursement {
    static let referencePrefix = "split-reimbursement:"
    private static let categoryName = "Reimburse"

    static func reference(for share: SplitShare) -> String {
        referencePrefix + share.key
    }

    static func record(_ share: SplitShare, bill: SplitBill, context: ModelContext) {
        let amount = share.outstanding
        guard amount > 0 else { return }
        share.recordPayment(amount)

        let categories = (try? context.fetch(FetchDescriptor<TransactionCategory>())) ?? []
        let transaction = Transaction(
            type: .income,
            title: "\(share.name) paid \(bill.title)",
            amount: Decimal(amount),
            source: .bca,
            date: .now,
            category: categories.first { $0.name.caseInsensitiveCompare(categoryName) == .orderedSame }
        )
        transaction.wallet = bill.transaction?.wallet
        transaction.externalReference = reference(for: share)
        context.insert(transaction)
    }

    static func undo(_ share: SplitShare, context: ModelContext) {
        let ref = reference(for: share)
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.externalReference == ref })
        for transaction in (try? context.fetch(descriptor)) ?? [] {
            context.delete(transaction)
        }
        share.undoSettlement()
    }
}
