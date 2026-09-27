//
//  CategoryEditorViewModel.swift
//  Swiftlet
//

import Foundation
import Observation
import SwiftData

@Observable
final class CategoryEditorViewModel {
    var name: String = ""
    var scope: CategoryScope?
    var purpose: CategoryPurpose?
    var budgetText: String = ""

    /// Set once the user picks by hand; until then the emoji and colour follow the name.
    var pickedEmoji: String?
    var pickedColorHex: String?

    private(set) var suggestedIcon: CategoryIconIntelligence.Icon?
    private(set) var isSuggesting = false
    private var suggestionTask: Task<Void, Never>?

    private(set) var editingCategory: TransactionCategory?

    var isEditing: Bool {
        editingCategory != nil
    }

    init(defaultScope: CategoryScope) {
        scope = defaultScope
    }

    init(editing category: TransactionCategory) {
        editingCategory = category
        name = category.name
        scope = category.appliesTo
        purpose = category.purpose
        budgetText = CurrencyFormatter.plainAmount(category.monthlyBudget)
        pickedEmoji = category.iconType == .emoji ? category.iconValue : nil
        pickedColorHex = category.colorHex.isEmpty ? nil : category.colorHex
    }

    private var fallbackIcon: CategoryIconIntelligence.Icon {
        CategorySymbolResolver.icon(forName: name, scope: scope ?? .both)
    }

    var emoji: String {
        pickedEmoji ?? suggestedIcon?.emoji ?? fallbackIcon.emoji
    }

    var colorHex: String {
        pickedColorHex ?? suggestedIcon?.colorHex ?? fallbackIcon.colorHex
    }

    /// Purpose and budget only make sense for categories money is spent in.
    var allowsPurpose: Bool {
        scope != .income
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && scope != nil
    }

    /// Debounced; safe to call on every keystroke.
    @MainActor
    func requestSuggestion() {
        suggestionTask?.cancel()

        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let scope = scope ?? .both

        guard pickedEmoji == nil || pickedColorHex == nil,
              trimmed.count >= 2,
              CategoryIconIntelligence.isAvailable
        else {
            isSuggesting = false
            return
        }

        suggestionTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            self?.isSuggesting = true
            let icon = await CategoryIconIntelligence.suggestIcon(name: trimmed, scope: scope)
            guard !Task.isCancelled else { return }
            self?.suggestedIcon = icon
            self?.isSuggesting = false
        }
    }

    @discardableResult
    func save(context: ModelContext) -> TransactionCategory? {
        guard isValid, let scope else { return nil }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let category: TransactionCategory

        if let editingCategory {
            category = editingCategory
        } else {
            let existing = (try? context.fetch(FetchDescriptor<TransactionCategory>())) ?? []
            let nextIndex = (existing.map(\.sortIndex).max() ?? -1) + 1
            category = TransactionCategory(name: trimmedName, iconType: .emoji, iconValue: emoji, sortIndex: nextIndex)
            context.insert(category)
        }

        category.name = trimmedName
        category.iconType = .emoji
        category.iconValue = emoji
        category.colorHex = colorHex
        category.appliesTo = scope
        category.purpose = allowsPurpose ? purpose : nil
        category.monthlyBudget = allowsPurpose ? CurrencyFormatter.parse(budgetText) ?? 0 : 0

        try? context.save()
        return category
    }
}
