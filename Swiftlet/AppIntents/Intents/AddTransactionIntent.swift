//
//  AddTransactionIntent.swift
//  Swiftlet
//
//  Created by Andrew Devito Aryo on 08/09/26.
//

import AppIntents
import Foundation
import SwiftData

struct AddTransactionIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Add Transaction"
    static let description = IntentDescription("Add a transaction by saying the amount, then what it was for.")
    static let openAppWhenRun: Bool = false
    static let isDiscoverable: Bool = true

    @Parameter(title: "Amount", requestValueDialog: "How much did you spend?")
    var amount: Int

    @Parameter(title: "Title", requestValueDialog: "What was it for?")
    var title: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            throw $amount.needsValueError("How much did you spend?")
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw $title.needsValueError("What was it for?")
        }

        let context = Persistance.container.mainContext
        let type = Self.inferType(from: trimmedTitle)
        let money = Decimal(amount)

        let category = await resolveCategory(
            title: trimmedTitle,
            type: type,
            context: context
        )
        let categoryLabel = category?.name ?? "Uncategorized"

        try await requestConfirmation(
            dialog: "Add \(CurrencyFormatter.rupiah(money)) for \(trimmedTitle)?"
        )

        let tx = Transaction(
            type: type,
            title: trimmedTitle,
            amount: money,
            source: .bca,
            date: .now,
            description: "",
            category: category
        )
        tx.wallet = WalletMigrator.ensureDefaultWallet(context: context)
        context.insert(tx)
        try context.save()

        return .result(dialog: "Added \(CurrencyFormatter.rupiah(money)) for \(categoryLabel).")
    }

    private static func inferType(from title: String) -> TransactionType {
        let lower = title.lowercased()
        let incomeWords = ["salary", "gaji", "income", "bonus", "refund", "reimburse", "gift"]
        return incomeWords.contains { lower.contains($0) } ? .income : .expense
    }

    /// Picks one of the user's real categories, restricted to those that apply to `type`.
    /// Asks the trained Core ML classifier first, then the on-device language model, then keyword-matches the title, then falls back to "Other".
    @MainActor
    private func resolveCategory(
        title: String,
        type: TransactionType,
        context: ModelContext
    ) async -> TransactionCategory? {
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

        if let keyword = Self.keywordCategoryName(in: title),
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
