//
//  SwiftletShortcuts.swift
//  Swiftlet
//
//  Created by Andrew Devito Aryo on 03/09/26.
//

import AppIntents
import Foundation

struct SwiftletShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTransactionIntent(),
            phrases: [
                "Add a transaction in \(.applicationName)",
                "Add a transaction for \(.applicationName)",
                "Add new transaction for \(.applicationName)",
                "Add a new transaction for \(.applicationName)",
                "Log an expense in \(.applicationName)",
                "Quick add expense in \(.applicationName)",
                "Quick add a transaction in \(.applicationName)",
                "Log a quick expense in \(.applicationName)",
            ],
            shortTitle: "Quick Add",
            systemImageName: "bolt.fill"
        )

        AppShortcut(
            intent: TodayTransactionsIntent(),
            phrases: [
                "Show today's transactions in \(.applicationName)",
                "What did I spend today in \(.applicationName)",
            ],
            shortTitle: "Today's Transactions",
            systemImageName: "calendar"
        )

        AppShortcut(
            intent: ImportBankEmailIntent(),
            phrases: [
                "Import a bank email in \(.applicationName)",
                "Add a receipt email to \(.applicationName)",
            ],
            shortTitle: "Import Email",
            systemImageName: "envelope.badge"
        )
    }
}
