//
//  BankEmailImporter.swift
//  Swiftlet
//

import Foundation
import SwiftData

nonisolated enum BankEmailDedupe {
    static let nearDuplicateWindow: TimeInterval = 10 * 60

    static func key(for email: ParsedBankEmail, receivedAt: Date?) -> String? {
        let provider = email.provider.lowercased()
        if !email.reference.isEmpty {
            return "\(provider):\(email.reference.lowercased())"
        }
        guard let receivedAt else { return nil }
        let minute = Int(receivedAt.timeIntervalSince1970 / 60)
        return "\(provider):\(email.title.lowercased()):\(email.amount):\(minute)"
    }

    static func walletIndex(for hint: String, in names: [String]) -> Int? {
        let wanted = hint.trimmingCharacters(in: .whitespaces).lowercased()
        guard !wanted.isEmpty else { return nil }
        if let exact = names.firstIndex(where: { $0.lowercased() == wanted }) { return exact }
        return names.firstIndex { $0.lowercased().contains(wanted) }
    }
}

enum BankEmailImportResult {
    case added(title: String, amount: Int, wallet: String, usedDefaultWallet: Bool)
    case duplicate
    case unreadable
}

enum BankEmailImporter {
    @MainActor
    static func importEmail(
        text: String,
        receivedAt: Date?,
        context: ModelContext
    ) async -> BankEmailImportResult {
        guard let parsed = BankEmailParser.parse(text) else { return .unreadable }

        let key = BankEmailDedupe.key(for: parsed, receivedAt: receivedAt)
        if let key, existsTransaction(withReference: key, context: context) { return .duplicate }

        let wallets = WalletMigrator.activeWallets(context: context)
        let names = wallets.map(\.name)
        let source = BankEmailDedupe.walletIndex(for: parsed.walletHint, in: names).map { wallets[$0] }
        let wallet = source ?? WalletMigrator.ensureDefaultWallet(context: context)
        let destination = parsed.destinationHint
            .flatMap { BankEmailDedupe.walletIndex(for: $0, in: names) }
            .map { wallets[$0] }

        let date = receivedAt ?? .now
        if isNearDuplicate(parsed, wallet: wallet, date: date, context: context) { return .duplicate }

        let category: TransactionCategory? = parsed.type == .transfer
            ? nil
            : await TitleCategoryResolver.resolve(title: parsed.title, type: parsed.type, context: context)

        let transaction = Transaction(
            type: parsed.type,
            title: parsed.title,
            amount: Decimal(parsed.amount),
            source: .bca,
            date: date,
            description: "",
            category: category
        )
        transaction.wallet = wallet
        transaction.destinationWallet = parsed.type == .transfer ? destination : nil
        transaction.externalReference = key ?? ""
        context.insert(transaction)
        try? context.save()

        return .added(
            title: parsed.title,
            amount: parsed.amount,
            wallet: wallet.name,
            usedDefaultWallet: source == nil
        )
    }

    @MainActor
    private static func existsTransaction(withReference reference: String, context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.externalReference == reference })
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    @MainActor
    private static func isNearDuplicate(
        _ email: ParsedBankEmail,
        wallet: Wallet,
        date: Date,
        context: ModelContext
    ) -> Bool {
        let window = BankEmailDedupe.nearDuplicateWindow
        let lower = date.addingTimeInterval(-window)
        let upper = date.addingTimeInterval(window)
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.date >= lower && $0.date <= upper })
        let nearby = (try? context.fetch(descriptor)) ?? []
        let amount = Decimal(email.amount)
        return nearby.contains {
            $0.type == email.type && $0.amount == amount && $0.wallet?.persistentModelID == wallet.persistentModelID
        }
    }
}
