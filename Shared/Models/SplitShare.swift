//
//  SplitShare.swift
//  Swiftlet
//

import Foundation
import SwiftData

@Model
final class SplitShare {
    var key: String = UUID().uuidString
    var name: String = ""
    var amount: Int = 0
    var settledAmount: Int = 0
    var isMine: Bool = false
    var settledAt: Date?
    var sortIndex: Int = 0

    var person: SplitPerson?
    var bill: SplitBill?

    init(
        key: String = UUID().uuidString,
        name: String,
        amount: Int,
        isMine: Bool,
        sortIndex: Int,
        person: SplitPerson? = nil
    ) {
        self.key = key
        self.name = name
        self.amount = amount
        self.isMine = isMine
        self.sortIndex = sortIndex
        self.person = person
    }

    var outstanding: Int {
        isMine ? 0 : max(amount - settledAmount, 0)
    }

    var isSettled: Bool {
        isMine || outstanding == 0
    }

    func recordPayment(_ payment: Int, on date: Date = .now) {
        let applied = min(max(payment, 0), outstanding)
        guard applied > 0 else { return }
        settledAmount += applied
        settledAt = outstanding == 0 ? date : nil
    }

    func undoSettlement() {
        settledAmount = 0
        settledAt = nil
    }

    func reminderMessage(billTitle: String) -> String {
        "Hi \(name), your share of \(billTitle) is \(CurrencyFormatter.rupiah(Decimal(outstanding))). Thanks!"
    }
}
