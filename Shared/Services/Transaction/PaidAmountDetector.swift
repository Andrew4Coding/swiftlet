//
//  PaidAmountDetector.swift
//  Swiftlet
//

import Foundation

nonisolated enum PaidAmountDetector {
    static let maxAmount = 999_999_999_999

    static func validated(_ amount: Int) -> Int? {
        (1 ... maxAmount).contains(amount) ? amount : nil
    }

    static func appearsInText(_ amount: Int, lines: [String]) -> Bool {
        lines.contains { amounts(in: $0).contains(amount) }
    }

    static func amounts(in line: String) -> [Int] {
        line.matches(of: #/\d[\d.,]*/#).compactMap { parse(String($0.output)) }
    }

    static func parse(_ token: String) -> Int? {
        var text = token.trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
        if let grouped = text.wholeMatch(of: #/(\d{1,3}(?:[.,]\d{3})+)[.,]\d{1,2}/#) {
            text = String(grouped.output.1)
        } else if let decimal = text.wholeMatch(of: #/(\d+)[.,]\d{1,2}/#) {
            text = String(decimal.output.1)
        }
        let digits = text.filter(\.isNumber)
        return digits.isEmpty ? nil : Int(digits)
    }

    private static let totalLabels = [
        "total bayar", "total pembayaran", "total transaksi", "total dibayar", "total amount",
        "amount paid", "nominal", "jumlah", "total",
    ]
    private static let excludedWords = ["subtotal", "sub total", "admin", "fee", "biaya", "saldo", "balance", "kembali"]

    static func keywordAmount(lines: [String]) -> Int? {
        for label in totalLabels {
            for (index, line) in lines.enumerated() {
                let lowered = line.lowercased()
                guard lowered.contains(label), !excludedWords.contains(where: lowered.contains) else { continue }
                let inLine = amounts(in: line).filter { validated($0) != nil }
                if let amount = inLine.last {
                    return amount
                }
                if index + 1 < lines.count, let next = amounts(in: lines[index + 1]).first, validated(next) != nil {
                    return next
                }
            }
        }
        return nil
    }
}
