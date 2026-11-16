//
//  SplitTextParser.swift
//  Swiftlet
//

import Foundation

nonisolated enum SplitTextParser {
    struct Claim: Equatable {
        var person: String
        var itemPhrase: String
        var quantity: Int
    }

    struct Result: Equatable {
        var claims: [Claim] = []
        var unparsed: [String] = []
    }

    private static let verbs: Set<String> = [
        "beli", "membeli", "pesan", "memesan", "makan", "minum", "order", "ordered", "ambil", "mengambil",
        "had", "bought", "ate", "drank", "takes", "took", "got",
    ]

    private static let itemSeparators: Set<String> = ["dan", "&", "sama", "and", "+", "plus"]

    private static let unitWords: Set<String> = [
        "x", "×", "biji", "buah", "pcs", "pc", "porsi", "gelas", "piring", "mangkok", "botol", "cup", "bh",
        "ekor", "potong", "slice", "portion", "glass", "units", "unit", "pieces", "piece",
    ]

    private static let numberWords: [String: Int] = [
        "satu": 1, "dua": 2, "tiga": 3, "empat": 4, "lima": 5, "enam": 6, "tujuh": 7, "delapan": 8,
        "sembilan": 9, "sepuluh": 10,
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8,
        "nine": 9, "ten": 10,
    ]

    static func parse(_ text: String) -> Result {
        var result = Result()
        var currentPerson: String?

        let clauses = text
            .components(separatedBy: CharacterSet(charactersIn: "\n;,"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for clause in clauses {
            let tokens = clause.split(whereSeparator: \.isWhitespace).map(String.init)
            var itemTokens = tokens

            if let split = personSplit(tokens) {
                currentPerson = split.person
                itemTokens = split.rest
            }

            guard let person = currentPerson else {
                result.unparsed.append(clause)
                continue
            }

            let phrases = splitItems(itemTokens)
            if phrases.isEmpty {
                if itemTokens.count == tokens.count { result.unparsed.append(clause) }
                continue
            }
            for phrase in phrases {
                if let claim = claim(person: person, tokens: phrase) {
                    result.claims.append(claim)
                } else {
                    result.unparsed.append(phrase.joined(separator: " "))
                }
            }
        }
        return result
    }

    private static func personSplit(_ tokens: [String]) -> (person: String, rest: [String])? {
        for (index, token) in tokens.enumerated() {
            let lowered = token.lowercased()
            if let colon = token.firstIndex(of: ":") {
                let head = String(token[..<colon])
                let tail = String(token[token.index(after: colon)...])
                let name = (tokens[..<index].map { $0 } + (head.isEmpty ? [] : [head])).joined(separator: " ")
                guard !name.isEmpty else { return nil }
                return (name, (tail.isEmpty ? [] : [tail]) + Array(tokens[(index + 1)...]))
            }
            if verbs.contains(lowered) {
                guard index > 0 else { return nil }
                return (tokens[..<index].joined(separator: " "), Array(tokens[(index + 1)...]))
            }
        }
        return nil
    }

    private static func splitItems(_ tokens: [String]) -> [[String]] {
        var phrases: [[String]] = []
        var current: [String] = []
        for token in tokens {
            if itemSeparators.contains(token.lowercased()) {
                if !current.isEmpty { phrases.append(current) }
                current = []
            } else {
                current.append(token)
            }
        }
        if !current.isEmpty { phrases.append(current) }
        return phrases
    }

    private static func claim(person: String, tokens: [String]) -> Claim? {
        var quantity: Int?
        var name: [String] = []

        for token in tokens {
            let lowered = token.lowercased()
            if quantity == nil, let value = quantityValue(lowered) {
                quantity = value
            } else if unitWords.contains(lowered) {
                continue
            } else {
                name.append(token)
            }
        }

        if quantity == nil {
            name = tokens
        }

        let phrase = name.joined(separator: " ")
        guard !phrase.isEmpty else { return nil }
        return Claim(person: person, itemPhrase: phrase, quantity: max(quantity ?? 1, 1))
    }

    private static func quantityValue(_ token: String) -> Int? {
        if let value = Int(token), value > 0 { return value }
        if let word = numberWords[token] { return word }
        for marker in ["x", "×"] {
            if token.hasSuffix(marker), let value = Int(token.dropLast(marker.count)), value > 0 { return value }
            if token.hasPrefix(marker), let value = Int(token.dropFirst(marker.count)), value > 0 { return value }
        }
        return nil
    }
}
