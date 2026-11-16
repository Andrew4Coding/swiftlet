//
//  SplitTextModelMatcher.swift
//  Swiftlet
//

import Foundation
import FoundationModels

@Generable
private struct ModelMatches {
    var matches: [ModelMatch]
}

@Generable
private struct ModelMatch {
    @Guide(description: "The typed phrase, copied exactly")
    var phrase: String
    @Guide(description: "The receipt item name it refers to, copied exactly. Empty if none is clearly the same dish or drink.")
    var itemName: String
}

enum SplitTextModelMatcher {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static func suggest(phrases: [String], itemNames: [String]) async -> [String: Int] {
        guard isAvailable, !phrases.isEmpty, !itemNames.isEmpty else { return [:] }

        let session = LanguageModelSession(instructions: """
        You match short typed Indonesian or English food and drink phrases to receipt item names.
        Only match when the phrase clearly means that item, allowing for abbreviations and spelling mistakes.
        Never invent an item name. Leave itemName empty when unsure.
        """)
        let prompt = """
        Receipt items:
        \(itemNames.map { "- \($0)" }.joined(separator: "\n"))

        Phrases to match:
        \(phrases.map { "- \($0)" }.joined(separator: "\n"))
        """

        guard let result = try? await session.respond(to: prompt, generating: ModelMatches.self).content else {
            return [:]
        }

        var suggestions: [String: Int] = [:]
        for match in result.matches {
            guard phrases.contains(match.phrase),
                  let index = itemNames.firstIndex(where: { $0.caseInsensitiveCompare(match.itemName) == .orderedSame })
            else { continue }
            suggestions[match.phrase] = index
        }
        return suggestions
    }
}
