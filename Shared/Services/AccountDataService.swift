//
//  AccountDataService.swift
//  Swiftlet
//

import Foundation
import SwiftData

enum AccountDataService {
    /// Deletes all user records locally (and, with iCloud, from the private CloudKit database), optionally re-seeding the default categories.
    static func eraseAllData(in context: ModelContext, restoreDefaultCategories: Bool) throws {
        try deleteAll(RecurringTransaction.self, in: context)
        try deleteAll(Transaction.self, in: context)
        try deleteAll(TransactionCategory.self, in: context)
        try deleteAll(Wallet.self, in: context)
        try context.save()

        if restoreDefaultCategories {
            CategorySeeder.seedIfNeeded(context: context)
        }
    }

    private static func deleteAll<T: PersistentModel>(_: T.Type, in context: ModelContext) throws {
        for object in try context.fetch(FetchDescriptor<T>()) {
            context.delete(object)
        }
    }
}
