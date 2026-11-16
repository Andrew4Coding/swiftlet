//
//  TransactionCategory+Ordering.swift
//  Swiftlet
//

import Foundation
import SwiftData

extension TransactionCategory {
    static func reorder(_ ordered: [TransactionCategory], context: ModelContext) {
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
