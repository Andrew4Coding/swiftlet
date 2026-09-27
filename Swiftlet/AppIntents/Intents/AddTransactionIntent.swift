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
    static let description = IntentDescription("Add an expense from a spoken phrase like \u{201C}20k for lunch\u{201D}.")
    static let openAppWhenRun: Bool = false
    static let isDiscoverable: Bool = true

    @Parameter(title: "What did you spend?", requestValueDialog: "What did you spend?")
    var rawPhrase: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = Persistance.container.mainContext
        let parsed = try await parse(rawPhrase)

        guard parsed.amount > 0 else {
            throw $rawPhrase.needsValueError("How much did you spend, and what for?")
        }

        let parsedType = TransactionType(rawValue: parsed.type) ?? .expense
        let type: TransactionType = parsedType == .transfer ? .expense : parsedType
        let money = Decimal(parsed.amount)
        let title = [parsed.name, parsed.note]
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }?
            .trimmingCharacters(in: .whitespaces) ?? "Transaction"

        let category = await resolveCategory(
            title: title,
            note: parsed.note,
            type: type,
            phrase: rawPhrase,
            context: context
        )
        let categoryLabel = category?.name ?? "Uncategorized"

        try await requestConfirmation(
            dialog: "Add \(CurrencyFormatter.rupiah(money)) for \(title)?"
        )

        let tx = Transaction(
            type: type,
            title: title,
            amount: money,
            source: .bca,
            date: .now,
            description: parsed.note,
            category: category
        )
        tx.wallet = WalletMigrator.ensureDefaultWallet(context: context)
        context.insert(tx)
        try context.save()

        return .result(dialog: "Added \(CurrencyFormatter.rupiah(money)) for \(categoryLabel).")
    }

    private func parse(_ text: String) async throws -> ParsedTransaction {
        do {
            return try await TransactionParser.parse(text)
        } catch is TransactionParser.NeedsFallback {
            return Self.fallbackParse(text)
        }
    }

    /// Picks one of the user's real categories, restricted to those that apply to `type`.
    /// Asks the on-device model first, then keyword-matches the phrase, then falls back to "Other".
    @MainActor
    private func resolveCategory(
        title: String,
        note: String,
        type: TransactionType,
        phrase: String,
        context: ModelContext
    ) async -> TransactionCategory? {
        let all = (try? context.fetch(FetchDescriptor<TransactionCategory>(sortBy: [SortDescriptor(\.name)]))) ?? []
        let eligible = all.filter { $0.appliesTo.allows(type) }
        guard !eligible.isEmpty else { return nil }

        if let guess = await CategoryClassifier.classify(
            title: title,
            type: type,
            note: note,
            among: eligible.map(\.name)
        ), let match = eligible.first(where: { $0.name == guess }) {
            return match
        }

        if let keyword = Self.keywordCategoryName(in: phrase),
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

    /// Deterministic parser used when the on-device model is unavailable.
    static func fallbackParse(_ text: String) -> ParsedTransaction {
        let lower = text.lowercased()
        var amount: Double = 0
        var name = ""

        if let match = text.firstMatch(of: /([0-9][0-9.,]*)\s*(k|rb|ribu|jt|juta|m)?/.ignoresCase()) {
            let digits = Double(match.1.replacing(",", with: "").replacing(".", with: "")) ?? 0
            switch match.2?.lowercased() {
            case "k", "rb", "ribu": amount = digits * 1000
            case "jt", "juta", "m": amount = digits * 1_000_000
            default: amount = digits
            }

            name = text.replacingCharacters(in: match.range, with: " ")
                .replacing(/\b(for|buat|bayar|beli|untuk)\b/.ignoresCase(), with: " ")
                .replacing(/\s+/, with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let incomeWords = ["salary", "gaji", "income", "bonus", "refund", "reimburse", "gift"]
        let type = incomeWords.contains { lower.contains($0) } ? "income" : "expense"

        return ParsedTransaction(type: type, amount: amount, name: name, note: "")
    }
}
