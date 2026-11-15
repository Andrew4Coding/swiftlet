//
//  ImportBankEmailIntent.swift
//  Swiftlet
//

import AppIntents
import Foundation
import SwiftData

struct ImportBankEmailIntent: AppIntent {
    static let title: LocalizedStringResource = "Import Bank Email"
    static let description = IntentDescription(
        "Reads a bank or e-wallet receipt email and adds it as a transaction."
    )
    static let openAppWhenRun: Bool = false
    static let isDiscoverable: Bool = true

    @Parameter(title: "Email Text", description: "The body of the receipt email.")
    var emailText: String

    @Parameter(title: "Sender")
    var sender: String?

    @Parameter(title: "Received Date")
    var receivedDate: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Import \(\.$emailText) from \(\.$sender)") {
            \.$receivedDate
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = Persistance.container.mainContext
        let result = await BankEmailImporter.importEmail(
            text: emailText,
            receivedAt: receivedDate,
            context: context
        )

        switch result {
        case let .added(title, amount, wallet, usedDefaultWallet):
            let money = CurrencyFormatter.rupiah(Decimal(amount))
            if usedDefaultWallet {
                return .result(dialog: "Added \(money) for \(title) to \(wallet), your default wallet.")
            }
            return .result(dialog: "Added \(money) for \(title) to \(wallet).")
        case .duplicate:
            return .result(dialog: "That email was already added.")
        case .unreadable:
            throw BankEmailImportError.unreadable(sender: sender)
        }
    }
}

enum BankEmailImportError: Error, CustomLocalizedStringResourceConvertible {
    case unreadable(sender: String?)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .unreadable(sender):
            if let sender, !sender.isEmpty {
                return "Couldn't read this email from \(sender)."
            }
            return "Couldn't read this email."
        }
    }
}
