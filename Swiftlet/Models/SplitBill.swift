//
//  SplitBill.swift
//  Swiftlet
//

import Foundation
import SwiftData

@Model
final class SplitBill {
    var title: String = ""
    var total: Int = 0
    var service: Int = 0
    var tax: Int = 0
    var discount: Int = 0
    var date: Date = Date.now
    var createdAt: Date = Date.now

    @Relationship(inverse: \Transaction.splitBill)
    var transaction: Transaction?

    @Relationship(deleteRule: .cascade, inverse: \SplitItem.bill)
    var items: [SplitItem]? = []

    @Relationship(deleteRule: .cascade, inverse: \SplitShare.bill)
    var shares: [SplitShare]? = []

    init(
        title: String,
        total: Int,
        service: Int = 0,
        tax: Int = 0,
        discount: Int = 0,
        date: Date = .now,
        createdAt: Date = .now
    ) {
        self.title = title
        self.total = total
        self.service = service
        self.tax = tax
        self.discount = discount
        self.date = date
        self.createdAt = createdAt
    }

    var sortedShares: [SplitShare] {
        (shares ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var sortedItems: [SplitItem] {
        (items ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var othersShares: [SplitShare] {
        sortedShares.filter { !$0.isMine }
    }

    var myShare: Int {
        (shares ?? []).filter(\.isMine).reduce(0) { $0 + $1.amount }
    }

    var owedByOthers: Int {
        othersShares.reduce(0) { $0 + $1.amount }
    }

    var outstanding: Int {
        othersShares.reduce(0) { $0 + $1.outstanding }
    }

    var isFullySettled: Bool {
        outstanding == 0
    }
}
