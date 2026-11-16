//
//  ReceiptParser.swift
//  Swiftlet
//

import Foundation

nonisolated struct ParsedReceipt: Equatable {
    struct Item: Equatable {
        var name: String
        var quantity: Int
        var price: Int
    }

    var items: [Item] = []
    var subtotal: Int?
    var service: Int?
    var tax: Int?
    var discount: Int?
    var total: Int?

    var itemsTotal: Int { items.reduce(0) { $0 + $1.price } }
}

nonisolated enum ReceiptMismatch: Equatable {
    case itemsDifferFromSubtotal(Int)
    case totalDiffers(Int)
}

nonisolated enum ReceiptMath {
    static func mismatches(
        itemsTotal: Int,
        subtotal: Int?,
        service: Int,
        tax: Int,
        discount: Int,
        total: Int?
    ) -> [ReceiptMismatch] {
        var found: [ReceiptMismatch] = []
        if let subtotal, subtotal != itemsTotal {
            found.append(.itemsDifferFromSubtotal(itemsTotal - subtotal))
        }
        if let total {
            let computed = (subtotal ?? itemsTotal) + service + tax - discount
            if computed != total {
                found.append(.totalDiffers(computed - total))
            }
        }
        return found
    }

    static func mismatches(in receipt: ParsedReceipt) -> [ReceiptMismatch] {
        mismatches(
            itemsTotal: receipt.itemsTotal,
            subtotal: receipt.subtotal,
            service: receipt.service ?? 0,
            tax: receipt.tax ?? 0,
            discount: receipt.discount ?? 0,
            total: receipt.total
        )
    }
}

nonisolated enum ReceiptParser {
    static func parseAmount(_ raw: String) -> Int? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let isNegative = text.hasPrefix("-") || (text.hasPrefix("(") && text.hasSuffix(")"))
        text = String(text.filter { $0.isNumber || $0 == "." || $0 == "," })
        guard !text.isEmpty else { return nil }

        let digits: String
        if let match = text.wholeMatch(of: #/\d{1,3}(\.\d{3})+(,\d{1,2})?/#) {
            digits = String(match.output.0.split(separator: ",")[0]).replacingOccurrences(of: ".", with: "")
        } else if let match = text.wholeMatch(of: #/\d{1,3}(,\d{3})+(\.\d{1,2})?/#) {
            digits = String(match.output.0.split(separator: ".").first ?? "").replacingOccurrences(of: ",", with: "")
        } else if text.wholeMatch(of: #/\d+[.,]\d{1,2}/#) != nil {
            digits = String(text.prefix { $0.isNumber })
        } else if text.wholeMatch(of: #/\d+/#) != nil {
            digits = text
        } else {
            return nil
        }

        guard let value = Int(digits) else { return nil }
        return isNegative ? -value : value
    }

    static func parse(lines rawLines: [String]) -> ParsedReceipt {
        let lines = rawLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var receipt = ParsedReceipt()
        var itemsClosed = false
        var index = 0

        while index < lines.count {
            var line = Line(lines[index])
            index += 1

            if line.isDateOrTime { continue }

            if line.moneyTokens.isEmpty, line.hasLetters, index < lines.count {
                let next = Line(lines[index])
                if !next.moneyTokens.isEmpty, !next.hasLetters, !next.isDateOrTime {
                    line = Line("\(line.raw) \(next.raw)")
                    index += 1
                }
            }

            guard let amount = line.lastAmount else { continue }

            switch line.kind {
            case .total:
                receipt.total = amount
                itemsClosed = true
            case .subtotal:
                receipt.subtotal = amount
                itemsClosed = true
            case .service:
                receipt.service = (receipt.service ?? 0) + abs(amount)
            case .tax:
                receipt.tax = (receipt.tax ?? 0) + abs(amount)
            case .discount:
                receipt.discount = (receipt.discount ?? 0) + abs(amount)
            case .ignored:
                continue
            case .item:
                guard !itemsClosed, line.hasLetters else { continue }
                if amount < 0 {
                    receipt.discount = (receipt.discount ?? 0) + abs(amount)
                    continue
                }
                if let item = line.makeItem() {
                    receipt.items.append(item)
                }
            }
        }

        return receipt
    }
}

private nonisolated struct Line {
    enum Kind { case total, subtotal, service, tax, discount, ignored, item }

    let raw: String
    let moneyTokens: [(text: String, amount: Int)]
    let label: String

    init(_ raw: String) {
        self.raw = raw
        var tokens: [(String, Int)] = []
        var remaining = raw
        for match in raw.matches(of: #/-?\(?\d[\d.,]*\d\)?|\d/#) {
            let text = String(match.output)
            guard Self.looksLikeMoney(text), let amount = ReceiptParser.parseAmount(text) else { continue }
            tokens.append((text, amount))
        }
        for token in tokens {
            if let range = remaining.range(of: token.0) {
                remaining.replaceSubrange(range, with: " ")
            }
        }
        moneyTokens = tokens
        label = remaining
            .replacingOccurrences(of: #"(?i)\brp\.?"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " :.-@*_=|/\\"))
    }

    var hasLetters: Bool { label.contains { $0.isLetter } }
    var lastAmount: Int? { moneyTokens.last?.amount }

    var isDateOrTime: Bool {
        raw.contains(#/\d{1,2}[\/:.\-]\d{1,2}[\/:.\-]\d{2,4}/#) || raw.contains(#/\b\d{1,2}:\d{2}\b/#)
    }

    var kind: Kind {
        let text = label.lowercased()
        let compact = text.replacingOccurrences(of: " ", with: "")

        if compact.contains("subtotal") || compact.contains("sub-total") { return .subtotal }
        if text.contains("grand total") || compact.contains("totalbayar") || compact.contains("totaltagihan")
            || compact.contains("totalpembayaran") || compact.contains("amountdue") || compact.contains("totalharga")
        {
            return .total
        }
        if compact == "total" || (compact.hasPrefix("total") && !compact.contains("item") && !compact.contains("qty")) {
            return .total
        }
        if Self.contains(text, any: ["service", "servis", "svc", "srv", "s.charge"]) { return .service }
        if Self.contains(text, any: ["tax", "ppn", "pb1", "pb 1", "pajak", "vat"]) { return .tax }
        if Self.contains(text, any: ["disc", "diskon", "potongan", "promo", "voucher", "hemat"]) { return .discount }
        if Self.contains(text, any: Self.ignoredWords) { return .ignored }
        return .item
    }

    func makeItem() -> ParsedReceipt.Item? {
        var name = label
        var quantity = 1

        if let match = name.wholeMatch(of: #/(\d{1,2})\s*[xX]?\s+(.+)/#) {
            quantity = Int(match.output.1) ?? 1
            name = String(match.output.2)
        } else if moneyTokens.count > 1, let match = name.wholeMatch(of: #/(.+?)\s+(\d{1,2})\s*[xX]?/#) {
            quantity = Int(match.output.2) ?? 1
            name = String(match.output.1)
        }

        name = name
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " :.-@*_=|/\\xX"))
        guard name.contains(where: \.isLetter), let price = lastAmount, price > 0 else { return nil }

        return ParsedReceipt.Item(name: name, quantity: max(quantity, 1), price: price)
    }

    private static func looksLikeMoney(_ text: String) -> Bool {
        let bare = text.filter { $0.isNumber || $0 == "." || $0 == "," }
        if bare.count < 4 { return false }
        if bare.wholeMatch(of: #/0\d+/#) != nil { return false }
        let hasGrouping = bare.contains(#/[.,]\d{3}(?!\d)/#)
        let digitCount = bare.filter(\.isNumber).count
        return hasGrouping || digitCount >= 4
    }

    private static func contains(_ text: String, any words: [String]) -> Bool {
        words.contains { word in
            text.range(of: #"\b"# + NSRegularExpression.escapedPattern(for: word), options: .regularExpression) != nil
        }
    }

    private static let ignoredWords = [
        "cash", "tunai", "change", "kembali", "bayar", "debit", "kredit", "credit", "qris", "visa",
        "master", "card", "gopay", "ovo", "dana", "shopee", "saldo", "payment", "kasir", "cashier",
        "meja", "telp", "phone", "npwp", "invoice", "order no", "bill no", "guest", "pax",
    ]
}
