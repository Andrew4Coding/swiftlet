//
//  MenuBarPersistence.swift
//  SwiftletMenuBar
//

import Foundation
import SwiftData

/// Same schema and CloudKit container as the iPhone app's `Persistance`, so a transaction added
/// here shows up there (and vice versa) after iCloud syncs — no app group needed, since this runs
/// on a different device. Category seeding is intentionally skipped: it depends on
/// `FoundationModels`/`CategorySeeder`, which this lightweight target doesn't link.
enum MenuBarPersistence {
    static let container: ModelContainer = {
        let schema = Schema([
            Transaction.self,
            TransactionCategory.self,
            Wallet.self,
            RecurringTransaction.self,
        ])

        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.andrew4coding.swiftlet.Swiftlet")
        )

        return try! ModelContainer(for: schema, configurations: [config])
    }()
}
