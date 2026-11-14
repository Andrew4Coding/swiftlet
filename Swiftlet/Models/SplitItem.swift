//
//  SplitItem.swift
//  Swiftlet
//

import Foundation
import SwiftData

@Model
final class SplitItem {
    var name: String = ""
    var quantity: Int = 1
    var price: Int = 0
    var sortIndex: Int = 0
    var assigneeKeys: [String] = []

    var bill: SplitBill?

    init(name: String, quantity: Int = 1, price: Int, sortIndex: Int, assigneeKeys: [String] = []) {
        self.name = name
        self.quantity = quantity
        self.price = price
        self.sortIndex = sortIndex
        self.assigneeKeys = assigneeKeys
    }
}
