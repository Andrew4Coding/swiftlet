//
//  CategoryClassifier.swift
//  Swiftlet
//

import Foundation
import FoundationModels

@Generable
private struct CategoryChoice {
    @Guide(description: "The single best-matching category name, copied verbatim from the allowed list")
    var category: String
}

enum CategoryClassifier {
    static func classify(
        title: String,
        type: TransactionType,
        note: String = "",
        among candidates: [String]
    ) async -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !candidates.isEmpty else { return nil }
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let session = LanguageModelSession(instructions: """
        You categorize a personal-finance \(type.rawValue) transaction for an Indonesian user.
        Choose exactly one category, copying its name verbatim from this list:
        \(candidates.joined(separator: ", ")).
        If nothing fits well, choose "Other".
        """)

        let prompt = note.isEmpty ? "Transaction: \"\(trimmed)\"" : "Transaction: \"\(trimmed)\" (\(note))"

        guard let choice = try? await session.respond(to: prompt, generating: CategoryChoice.self).content else {
            return nil
        }
        return candidates.first { $0.caseInsensitiveCompare(choice.category) == .orderedSame }
    }
}
