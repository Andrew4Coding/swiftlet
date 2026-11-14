//
//  PaymentCategoryResolver.swift
//  Swiftlet
//

import Foundation

enum PaymentCategoryResolver {
    static func resolve(merchant: String, among categories: [TransactionCategory]) async -> TransactionCategory? {
        let candidates = categories.filter { $0.name.caseInsensitiveCompare("Other") != .orderedSame }
        let names = candidates.map(\.name)
        guard !names.isEmpty else { return nil }

        if let guess = TransactionCategoryModel.classify(title: merchant, among: names) {
            return candidates.first { $0.name == guess }
        }

        let note = "Merchant name read from a payment proof"
        if let guess = await CategoryClassifier.classify(title: merchant, type: .expense, note: note, among: names) {
            return candidates.first { $0.name == guess }
        }
        return nil
    }
}
