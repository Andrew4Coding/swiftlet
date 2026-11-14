//
//  PaymentProofReader.swift
//  Swiftlet
//

import Foundation
import FoundationModels

@Generable
struct ModelPaymentProof {
    @Guide(description: "True only if the text clearly shows the total amount the customer paid")
    var found: Bool
    @Guide(description: "The total amount paid in whole rupiah with no separators, 0 if not found")
    var amount: Int
    @Guide(description: "Name of the merchant or recipient who was paid, empty if not shown")
    var merchant: String
}

nonisolated enum PaymentProofReader {
    struct Result: Equatable {
        var amount: Int?
        var merchant: String?
    }

    private static let maxCharacters = 3500

    static func read(imageData: Data) async -> Result {
        guard let lines = try? await recognizeRows(in: imageData), !lines.isEmpty else {
            return Result()
        }
        return await read(lines: lines)
    }

    static func read(
        lines: [String],
        model: ([String]) async -> ModelPaymentProof? = modelProof
    ) async -> Result {
        var result = Result(
            amount: PaidAmountDetector.keywordAmount(lines: lines),
            merchant: keywordMerchant(lines: lines)
        )
        guard result.amount == nil || result.merchant == nil else { return result }

        if let proof = await model(lines) {
            if result.amount == nil, let amount = PaidAmountDetector.validated(proof.amount),
               proof.found, PaidAmountDetector.appearsInText(amount, lines: lines)
            {
                result.amount = amount
            }
            if result.merchant == nil, let merchant = acceptedMerchant(proof.merchant, lines: lines) {
                result.merchant = merchant
            }
        }
        return result
    }

    static func recognizeRows(in imageData: Data) async throws -> [String] {
        try await ReceiptScanner.recognizeRows(in: imageData).map(foldLookalikes)
    }

    private static let lookalikes: [Character: Character] = Dictionary(uniqueKeysWithValues: [
        ("а", "a"),
        ("е", "e"),
        ("о", "o"),
        ("р", "p"),
        ("с", "c"),
        ("х", "x"),
        ("у", "y"),
        ("і", "i"),
        ("ј", "j"),
        ("А", "A"),
        ("В", "B"),
        ("Е", "E"),
        ("К", "K"),
        ("М", "M"),
        ("Н", "H"),
        ("О", "O"),
        ("Р", "P"),
        ("С", "C"),
        ("Т", "T"),
        ("Х", "X"),
        ("І", "I"),
        ("Ј", "J"),
    ].map { (Character($0.0), Character($0.1)) })

    static func foldLookalikes(_ text: String) -> String {
        String(text.map { lookalikes[$0] ?? $0 })
    }

    private static let merchantLabels = [
        "nama merchant", "merchant name", "nama penerima", "dibayar ke", "paid to",
        "merchant", "penerima", "kepada", "tujuan", "toko",
    ]

    static func keywordMerchant(lines: [String]) -> String? {
        for label in merchantLabels {
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.lowercased().hasPrefix(label) else { continue }
                let rest = trimmed.dropFirst(label.count)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ": \t"))
                if isName(rest) { return rest }
                if index + 1 < lines.count {
                    let next = lines[index + 1].trimmingCharacters(in: .whitespaces)
                    if isName(next) { return next }
                }
            }
        }
        return nil
    }

    static func acceptedMerchant(_ candidate: String, lines: [String]) -> String? {
        let name = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isName(name) else { return nil }
        let needle = squash(name)
        return lines.contains { squash($0).contains(needle) } ? name : nil
    }

    private static func isName(_ text: String) -> Bool {
        text.filter(\.isLetter).count >= 2 && text.filter(\.isNumber).count < text.filter(\.isLetter).count
    }

    private static func squash(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func modelProof(lines: [String]) async -> ModelPaymentProof? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let text = String(lines.joined(separator: "\n").prefix(maxCharacters))
        let session = LanguageModelSession(instructions: """
        You read OCR text from an Indonesian payment proof: a QRIS receipt, bank transfer, \
        or e-wallet confirmation.
        Return the final total the customer paid, never an admin fee, balance, change amount or reference number.
        Copy numbers exactly as printed, converting formats such as 150.000 or Rp 150.000,00 to 150000.
        Also return the merchant or recipient name exactly as printed.
        """)
        return try? await session.respond(to: text, generating: ModelPaymentProof.self).content
    }
}
