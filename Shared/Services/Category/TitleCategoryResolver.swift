//
//  TitleCategoryResolver.swift
//  Swiftlet
//

import Foundation
import SwiftData

enum TitleCategoryResolver {
    /// Picks one of the user's real categories, restricted to those that apply to `type`.
    /// Asks the trained Core ML classifier first, then the on-device language model, then keyword-matches the title, then falls back to "Other".
    @MainActor
    static func resolve(title: String, type: TransactionType, context: ModelContext) async -> TransactionCategory? {
        let all = (try? context.fetch(FetchDescriptor<TransactionCategory>(sortBy: [SortDescriptor(\.name)]))) ?? []
        let eligible = all.filter { $0.appliesTo.allows(type) }
        guard !eligible.isEmpty else { return nil }

        let names = eligible.map(\.name)

        if let guess = TransactionCategoryModel.classify(title: title, among: names),
           let match = eligible.first(where: { $0.name == guess }) {
            return match
        }

        if let guess = await CategoryClassifier.classify(
            title: title,
            type: type,
            among: names
        ), let match = eligible.first(where: { $0.name == guess }) {
            return match
        }

        if let keyword = keywordCategoryName(in: title),
           let match = eligible.first(where: { $0.name.localizedCaseInsensitiveCompare(keyword) == .orderedSame })
        {
            return match
        }

        return eligible.first { $0.name.caseInsensitiveCompare("Other") == .orderedSame } ?? eligible.first
    }

    /// Maps a few common words to a default category name. Used for offline categorization.
    private static func keywordCategoryName(in text: String) -> String? {
        let lower = text.lowercased()
        let keywords: [(String, String)] = [
            ("lunch", "Food"), ("dinner", "Food"), ("makan", "Food"), ("coffee", "Food"), ("kopi", "Food"),
            ("grab", "Transport"), ("gojek", "Transport"), ("bensin", "Transport"), ("transport", "Transport"),
            ("belanja", "Shopping"), ("groceries", "Food"),
            ("bill", "Bills"), ("listrik", "Bills"),
            ("salary", "Salary"), ("gaji", "Salary"),
        ]
        return keywords.first { lower.contains($0.0) }?.1
    }
}
