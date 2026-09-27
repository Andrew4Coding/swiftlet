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
    var wallet: Wallet?
    var destinationWallet: Wallet?
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
        wallet = transaction.wallet
        destinationWallet = transaction.destinationWallet
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

    /// Clears a category that no longer applies after the type is switched.
    func typeDidChange() {
        if type == .transfer {
            selectedCategory = nil
        } else if let selected = selectedCategory, !selected.appliesTo.allows(type) {
            selectedCategory = nil
        }
    }

    @MainActor
    func assignDefaultWallets(context: ModelContext) {
        if wallet == nil {
            wallet = WalletMigrator.ensureDefaultWallet(context: context)
        }
        if destinationWallet == nil {
            destinationWallet = WalletMigrator.activeWallets(context: context)
                .first { $0.persistentModelID != wallet?.persistentModelID }
        }
    }

    private var resolvedTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            return trimmed
        }
        if type == .transfer {
            return "Transfer to \(destinationWallet?.name ?? "wallet")"
        }
        return selectedCategory?.name ?? type.displayName
    }

    var validationMessage: String? {
        if (parsedAmount ?? 0) <= 0 {
            return "Enter an amount"
        }
        if wallet == nil {
            return "Choose a wallet"
        }
        switch type {
        case .transfer:
            guard let destinationWallet else { return "Choose where the money goes" }
            if destinationWallet.persistentModelID == wallet?.persistentModelID {
                return "Pick two different wallets"
            }
        case .expense, .income:
            if selectedCategory == nil {
                return "Choose a category"
            }
        }
        return nil
    }

    var parsedAmount: Decimal? {
        CurrencyFormatter.parse(amountText)
    }

    var isValid: Bool {
        validationMessage == nil
    }

    @discardableResult
    func save(context: ModelContext) -> Bool {
        guard let amount = parsedAmount, validationMessage == nil else {
            errorMessage = validationMessage
            return false
        }

        let transaction: Transaction
        if let editingTransaction {
            transaction = editingTransaction
        } else {
            transaction = Transaction(type: type, title: "", amount: amount, source: .bca, date: date, category: nil)
            context.insert(transaction)
        }

        transaction.type = type
        transaction.title = resolvedTitle
        transaction.amount = amount
        transaction.date = date
        transaction.transactionDescription = descriptionText.trimmingCharacters(in: .whitespaces)
        transaction.category = type == .transfer ? nil : selectedCategory
        transaction.wallet = wallet
        transaction.destinationWallet = type == .transfer ? destinationWallet : nil
        transaction.receiptImageData = receiptImageData

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
