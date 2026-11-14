//
//  PaidAmountDetector.swift
//  Swiftlet
//

import Foundation
import FoundationModels

@Generable
private struct ModelPaidAmount {
    @Guide(description: "True only if the text clearly shows the total amount the customer paid")
    var found: Bool
    @Guide(description: "The total amount paid in whole rupiah with no separators, 0 if not found")
    var amount: Int
}

nonisolated enum PaidAmountDetector {
    static let maxAmount = 999_999_999_999
    private static let maxCharacters = 3500

    static func detect(imageData: Data) async -> Int? {
        guard let lines = try? await ReceiptScanner.recognizeRows(in: imageData), !lines.isEmpty else {
            return nil
        }
        return await detect(lines: lines)
    }

    static func detect(lines: [String]) async -> Int? {
        if let modelAmount = await modelAmount(lines: lines),
           let valid = validated(modelAmount),
           appearsInText(valid, lines: lines)
        {
            return valid
        }
        return keywordAmount(lines: lines)
    }

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

    private static func modelAmount(lines: [String]) async -> Int? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let text = String(lines.joined(separator: "\n").prefix(maxCharacters))
        let session = LanguageModelSession(instructions: """
        You read OCR text from an Indonesian payment proof: a QRIS receipt, bank transfer, \
        or e-wallet confirmation. Return the final total amount the customer paid.
        Choose the grand total, never an admin fee, a balance, a change amount, or a reference number.
        Copy the number exactly as printed, converting formats such as 150.000 or Rp 150.000,00 to 150000.
        If no paid total is clearly printed, set found to false.
        """)

        guard let result = try? await session.respond(to: text, generating: ModelPaidAmount.self).content,
              result.found
        else { return nil }
        return result.amount
    }
}
