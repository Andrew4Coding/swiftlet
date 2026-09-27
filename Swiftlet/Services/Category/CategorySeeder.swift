//
//  CategorySeeder.swift
//  Swiftlet
//

import Foundation
import SwiftData

enum CategorySeeder {
    static func seedIfNeeded(context: ModelContext) {
        mergeDuplicates(context: context)

        let existingNames = Set(
            ((try? context.fetch(FetchDescriptor<TransactionCategory>())) ?? [])
                .map { $0.name.lowercased() }
        )

        let startIndex = (((try? context.fetch(FetchDescriptor<TransactionCategory>())) ?? [])
            .map(\.sortIndex).max() ?? -1) + 1

        var didInsert = false
        for (offset, definition) in defaultDefinitions.enumerated()
            where !existingNames.contains(definition.name.lowercased())
        {
            let category = TransactionCategory(
                name: definition.name,
                iconType: .emoji,
                iconValue: definition.icon.emoji,
                appliesTo: definition.scope,
                isDefault: true,
                sortIndex: startIndex + offset,
                colorHex: definition.icon.colorHex
            )
            context.insert(category)
            didInsert = true
        }

        if didInsert || upgradeLegacyDefaults(context: context) {
            try? context.save()
        }
    }

    /// Default categories seeded before the emoji redesign still carry an SF Symbol and no
    /// colour; swap them to their emoji look. Only untouched defaults are upgraded — a symbol
    /// that no longer matches the original means the user customised it.
    private static func upgradeLegacyDefaults(context: ModelContext) -> Bool {
        guard let all = try? context.fetch(FetchDescriptor<TransactionCategory>()) else { return false }
        let definitions = Dictionary(uniqueKeysWithValues: defaultDefinitions.map { ($0.name.lowercased(), $0) })

        var didChange = false
        for category in all where category.isDefault && category.iconType == .system && category.colorHex.isEmpty {
            guard let definition = definitions[category.name.lowercased()],
                  category.iconValue == definition.icon.symbolName || category.iconValue == definition.legacySymbol
            else { continue }
            category.iconType = .emoji
            category.iconValue = definition.icon.emoji
            category.colorHex = definition.icon.colorHex
            didChange = true
        }
        return didChange
    }

    private static func mergeDuplicates(context: ModelContext) {
        guard let allCategories = try? context.fetch(FetchDescriptor<TransactionCategory>()) else { return }

        let groups = Dictionary(grouping: allCategories) { $0.name.lowercased() }

        var didDelete = false
        for group in groups.values where group.count > 1 {
            let sorted = group.sorted { $0.createdAt < $1.createdAt }
            guard let keeper = sorted.first else { continue }

            for duplicate in sorted.dropFirst() {
                for transaction in duplicate.transactions ?? [] {
                    transaction.category = keeper
                }
                context.delete(duplicate)
                didDelete = true
            }
        }

        if didDelete {
            try? context.save()
        }
    }

    private struct Definition {
        let name: String
        let icon: CategoryIconIntelligence.Icon
        let scope: CategoryScope
        var legacySymbol: String?
    }

    private static let defaultDefinitions: [Definition] = [
        Definition(name: "Food", icon: .food, scope: .expense),
        Definition(name: "Transport", icon: .transport, scope: .expense),
        Definition(name: "Shopping", icon: .shopping, scope: .expense),
        Definition(name: "Bills", icon: .bills, scope: .expense),
        Definition(name: "Entertainment", icon: .entertainment, scope: .expense),
        Definition(name: "Health", icon: .health, scope: .expense),
        Definition(name: "Salary", icon: .salary, scope: .income),
        Definition(name: "Reimburse", icon: .refund, scope: .income),
        Definition(name: "Gift", icon: .gift, scope: .income),
        Definition(name: "Other", icon: .other, scope: .both, legacySymbol: "questionmark.circle.fill"),
    ]
}
