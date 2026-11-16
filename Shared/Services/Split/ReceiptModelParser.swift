//
//  ReceiptModelParser.swift
//  Swiftlet
//

import Foundation
import FoundationModels

@Generable
private struct ModelReceipt {
    @Guide(description: "Purchased line items only. Never totals, tax, service, payment or change lines.")
    var items: [ModelReceiptItem]
    @Guide(description: "Printed subtotal in whole rupiah, 0 if not printed")
    var subtotal: Int
    @Guide(description: "Service charge in whole rupiah, 0 if none")
    var service: Int
    @Guide(description: "Tax (PPN or PB1) in whole rupiah, 0 if none")
    var tax: Int
    @Guide(description: "Discount as a positive amount in whole rupiah, 0 if none")
    var discount: Int
    @Guide(description: "Printed grand total in whole rupiah, 0 if not printed")
    var total: Int
}

@Generable
private struct ModelReceiptItem {
    var name: String
    @Guide(description: "Units purchased, 1 if not shown")
    var quantity: Int
    @Guide(description: "Price of the whole line in whole rupiah with no separators")
    var linePrice: Int
}

enum ReceiptModelParser {
    private static let maxCharacters = 3500

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static func parse(lines: [String]) async -> ParsedReceipt? {
        guard isAvailable else { return nil }

        let text = String(lines.joined(separator: "\n").prefix(maxCharacters))
        let session = LanguageModelSession(instructions: """
        You read OCR text from an Indonesian restaurant or shop receipt and structure it.
        Copy every number exactly as printed, converting Indonesian formats such as 45.000 to 45000.
        Never calculate, correct or invent amounts. Use 0 for anything that is not printed.
        """)

        guard let result = try? await session.respond(to: text, generating: ModelReceipt.self).content else {
            return nil
        }

        let items = result.items.compactMap { item -> ParsedReceipt.Item? in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, item.linePrice > 0 else { return nil }
            return ParsedReceipt.Item(name: name, quantity: max(item.quantity, 1), price: item.linePrice)
        }

        return ParsedReceipt(
            items: items,
            subtotal: result.subtotal > 0 ? result.subtotal : nil,
            service: result.service > 0 ? result.service : nil,
            tax: result.tax > 0 ? result.tax : nil,
            discount: result.discount > 0 ? abs(result.discount) : nil,
            total: result.total > 0 ? result.total : nil
        )
    }
}
