//
//  SplitModelTests.swift
//  SwiftletTests
//

import Foundation
import SwiftData
import Testing

@testable import Swiftlet

struct SplitModelTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Transaction.self, TransactionCategory.self, Wallet.self, RecurringTransaction.self,
            SplitBill.self, SplitItem.self, SplitShare.self, SplitPerson.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func makeSplit(in context: ModelContext, wallet: Wallet) -> SplitBill {
        let bill = SplitBill(title: "Dinner", total: 400_000)
        let me = SplitShare(name: "You", amount: 100_000, isMine: true, sortIndex: 0)
        let budi = SplitShare(name: "Budi", amount: 150_000, isMine: false, sortIndex: 1)
        let sari = SplitShare(name: "Sari", amount: 150_000, isMine: false, sortIndex: 2)
        let transaction = Transaction(
            type: .expense, title: "Dinner", amount: 100_000, source: .bca, date: .now, category: nil
        )
        transaction.wallet = wallet
        context.insert(bill)
        context.insert(transaction)
        [me, budi, sari].forEach { context.insert($0); $0.bill = bill }
        bill.transaction = transaction
        return bill
    }

    @Test func walletBalanceDropsByFullAmountPaidUntilSettled() throws {
        let context = try makeContext()
        let wallet = Wallet(name: "BCA", initialBalance: 1_000_000)
        context.insert(wallet)
        let bill = makeSplit(in: context, wallet: wallet)

        #expect(wallet.balance == 600_000)

        bill.othersShares[0].recordPayment(150_000)
        #expect(wallet.balance == 750_000)

        bill.othersShares[1].recordPayment(150_000)
        #expect(wallet.balance == 900_000)
        #expect(bill.isFullySettled)
    }

    @Test func partialPaymentReducesOutstanding() throws {
        let context = try makeContext()
        let wallet = Wallet(name: "BCA")
        context.insert(wallet)
        let share = makeSplit(in: context, wallet: wallet).othersShares[0]

        share.recordPayment(50_000)
        #expect(share.outstanding == 100_000)
        #expect(share.settledAt == nil)
    }

    @Test func paymentCannotExceedWhatIsOwed() throws {
        let context = try makeContext()
        let wallet = Wallet(name: "BCA")
        context.insert(wallet)
        let share = makeSplit(in: context, wallet: wallet).othersShares[0]

        share.recordPayment(1_000_000)
        #expect(share.settledAmount == 150_000)
        #expect(share.outstanding == 0)
        #expect(share.settledAt != nil)
    }

    @Test func negativePaymentIsIgnored() throws {
        let context = try makeContext()
        let wallet = Wallet(name: "BCA")
        context.insert(wallet)
        let share = makeSplit(in: context, wallet: wallet).othersShares[0]

        share.recordPayment(-5_000)
        #expect(share.settledAmount == 0)
    }

    @Test func myShareIsNeverOwed() throws {
        let context = try makeContext()
        let wallet = Wallet(name: "BCA")
        context.insert(wallet)
        let bill = makeSplit(in: context, wallet: wallet)

        #expect(bill.myShare == 100_000)
        #expect(bill.owedByOthers == 300_000)
        #expect(bill.outstanding == 300_000)
    }

    @Test func undoSettlementRestoresOutstanding() throws {
        let context = try makeContext()
        let wallet = Wallet(name: "BCA")
        context.insert(wallet)
        let share = makeSplit(in: context, wallet: wallet).othersShares[0]

        share.recordPayment(150_000)
        share.undoSettlement()
        #expect(share.outstanding == 150_000)
    }
}

extension SplitModelTests {
    @Test func reminderMessageNamesPersonAndOutstandingAmount() {
        let share = SplitShare(name: "Budi", amount: 150_000, isMine: false, sortIndex: 1)
        share.recordPayment(50_000)
        let message = share.reminderMessage(billTitle: "Dinner")
        #expect(message.contains("Budi"))
        #expect(message.contains("Dinner"))
        #expect(message.contains("100.000"))
    }
}
