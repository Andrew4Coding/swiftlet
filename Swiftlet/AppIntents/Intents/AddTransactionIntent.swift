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

        let category = await TitleCategoryResolver.resolve(
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
}
