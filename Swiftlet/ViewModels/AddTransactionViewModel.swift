//
//  AddTransactionViewModel.swift
//  Swiftlet
//

import Foundation
import Observation
import SwiftData

@Observable
final class AddTransactionViewModel {
    var type: TransactionType = .expense
    var title: String = ""
    var amountText: String = ""
    var source: MoneySource = .bca
    var date: Date = .now
    var descriptionText: String = ""
    var selectedCategory: TransactionCategory?
    var receiptImageData: Data?

    var errorMessage: String?

    /// Non-nil when this view model is editing an existing transaction rather than creating a new one.
    private(set) var editingTransaction: Transaction?

    var isEditing: Bool {
        editingTransaction != nil
    }

    init() {}

    init(editing transaction: Transaction) {
        editingTransaction = transaction
        type = transaction.type
        title = transaction.title
        amountText = NSDecimalNumber(decimal: transaction.amount).stringValue
        source = transaction.source
        date = transaction.date
        descriptionText = transaction.transactionDescription
        selectedCategory = transaction.category
        receiptImageData = transaction.receiptImageData
    }

    /// Categories applicable to the currently selected transaction type.
    func availableCategories(from allCategories: [TransactionCategory]) -> [TransactionCategory] {
        allCategories
            .filter { $0.appliesTo.allows(type) }
            .sorted { ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name) }
    }

    /// Clears a category and/or source that no longer applies after the type is switched.
    func typeDidChange() {
        if let selected = selectedCategory, !selected.appliesTo.allows(type) {
            selectedCategory = nil
        }
        if !source.scope.allows(type) {
            source = MoneySource.available(for: type).first ?? .bca
        }
    }

    var parsedAmount: Decimal? {
        CurrencyFormatter.parse(amountText)
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && (parsedAmount ?? 0) > 0
            && selectedCategory != nil
    }

    @discardableResult
    func save(context: ModelContext) -> Bool {
        guard let amount = parsedAmount, isValid else {
            errorMessage = "Please fill in a title, a valid amount, and choose a category."
            return false
        }

        if let editingTransaction {
            editingTransaction.type = type
            editingTransaction.title = title.trimmingCharacters(in: .whitespaces)
            editingTransaction.amount = amount
            editingTransaction.source = source
            editingTransaction.date = date
            editingTransaction.transactionDescription = descriptionText.trimmingCharacters(in: .whitespaces)
            editingTransaction.category = selectedCategory
            editingTransaction.receiptImageData = receiptImageData
        } else {
            let transaction = Transaction(
                type: type,
                title: title.trimmingCharacters(in: .whitespaces),
                amount: amount,
                source: source,
                date: date,
                description: descriptionText.trimmingCharacters(in: .whitespaces),
                category: selectedCategory,
                receiptImageData: receiptImageData
            )
            context.insert(transaction)
        }
        try? context.save()
        return true
    }

    /// Deletes a category. `Transaction.category` nullifies on delete, so existing
    /// transactions referencing it simply lose their category rather than being removed.
    func deleteCategory(_ category: TransactionCategory, context: ModelContext) {
        if selectedCategory?.persistentModelID == category.persistentModelID {
            selectedCategory = nil
        }
        context.delete(category)
        try? context.save()
    }

    func togglePin(_ category: TransactionCategory, context: ModelContext) {
        category.isPinned.toggle()
        try? context.save()
    }

    /// Persists a new top-to-bottom order for the given (visible) categories by rewriting their
    /// `sortIndex`. Categories not in the list keep their relative order after these.
    func reorderCategories(_ ordered: [TransactionCategory], context: ModelContext) {
        let visibleIDs = Set(ordered.map(\.persistentModelID))
        let others = ((try? context.fetch(FetchDescriptor<TransactionCategory>())) ?? [])
            .filter { !visibleIDs.contains($0.persistentModelID) }
            .sorted { $0.sortIndex < $1.sortIndex }

        for (index, category) in (ordered + others).enumerated() where category.sortIndex != index {
            category.sortIndex = index
        }
        try? context.save()
    }
}
