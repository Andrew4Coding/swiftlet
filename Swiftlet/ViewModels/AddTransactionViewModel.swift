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

    var isPresentingCustomCategoryEditor = false
    var newCategoryName: String = ""
    var newCategoryScope: CategoryScope = .expense

    /// Symbol the user picked by hand in the editor. When set, it wins over every automatic
    /// suggestion; `nil` means "let Apple Intelligence / the resolver choose".
    var manuallyPickedSymbol: String?

    /// Non-nil when the category editor sheet is editing an existing category rather than
    /// creating a new one.
    private(set) var editingCategory: TransactionCategory?

    var isEditingCategory: Bool {
        editingCategory != nil
    }

    /// Icon chosen by Apple Intelligence for the current name/description, when available.
    var aiSuggestedSymbol: String?
    var isSuggestingCategoryIcon = false
    private var iconSuggestionTask: Task<Void, Never>?

    /// Symbol the new/edited category will get — Apple Intelligence's pick when we have one,
    /// otherwise the keyword-based resolver. Never chosen by hand.
    var resolvedCategorySymbol: String {
        manuallyPickedSymbol
            ?? aiSuggestedSymbol
            ?? CategorySymbolResolver.symbol(forName: newCategoryName, scope: newCategoryScope)
    }

    /// Whether the icon is currently being chosen automatically rather than by hand.
    var isUsingAutomaticIcon: Bool {
        manuallyPickedSymbol == nil
    }

    var isAppleIntelligenceIconAvailable: Bool {
        CategoryIconIntelligence.isAvailable
    }

    /// Debounced request for an Apple Intelligence icon suggestion based on the current
    /// name/description/scope. Safe to call on every keystroke.
    @MainActor
    func requestIconSuggestion() {
        iconSuggestionTask?.cancel()

        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        let scope = newCategoryScope

        guard manuallyPickedSymbol == nil, name.count >= 2, CategoryIconIntelligence.isAvailable else {
            aiSuggestedSymbol = nil
            isSuggestingCategoryIcon = false
            return
        }

        iconSuggestionTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            self?.isSuggestingCategoryIcon = true
            let icon = await CategoryIconIntelligence.suggestIcon(
                name: name,
                scope: scope
            )
            guard !Task.isCancelled else { return }
            self?.aiSuggestedSymbol = icon.symbolName
            self?.isSuggestingCategoryIcon = false
        }
    }

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

    var isCustomCategoryValid: Bool {
        !newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty
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

    /// Resets the editor fields and opens the sheet in "create" mode.
    func beginCreatingCategory() {
        editingCategory = nil
        newCategoryName = ""
        newCategoryScope = type == .income ? .income : .expense
        manuallyPickedSymbol = nil
        iconSuggestionTask?.cancel()
        aiSuggestedSymbol = nil
        isSuggestingCategoryIcon = false
        isPresentingCustomCategoryEditor = true
    }

    /// Populates the editor fields from an existing category and opens the sheet in "edit" mode.
    func beginEditingCategory(_ category: TransactionCategory) {
        editingCategory = category
        newCategoryName = category.name
        newCategoryScope = category.appliesTo
        manuallyPickedSymbol = category.iconValue
        iconSuggestionTask?.cancel()
        aiSuggestedSymbol = nil
        isSuggestingCategoryIcon = false
        isPresentingCustomCategoryEditor = true
    }

    @discardableResult
    func saveCustomCategory(context: ModelContext) -> TransactionCategory? {
        guard isCustomCategoryValid else { return nil }

        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespaces)
        let symbolName = resolvedCategorySymbol

        let category: TransactionCategory
        if let editingCategory {
            editingCategory.name = trimmedName
            editingCategory.iconType = .system
            editingCategory.iconValue = symbolName
            editingCategory.appliesTo = newCategoryScope
            category = editingCategory
        } else {
            let existing = (try? context.fetch(FetchDescriptor<TransactionCategory>())) ?? []
            let nextIndex = (existing.map(\.sortIndex).max() ?? -1) + 1
            let created = TransactionCategory(
                name: trimmedName,
                iconType: .system,
                iconValue: symbolName,
                appliesTo: newCategoryScope,
                isDefault: false,
                sortIndex: nextIndex
            )
            context.insert(created)
            category = created
        }

        try? context.save()

        selectedCategory = category
        isPresentingCustomCategoryEditor = false

        return category
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
