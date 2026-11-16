//
//  SplitTextMatcher.swift
//  Swiftlet
//

import Foundation

nonisolated enum SplitTextMatcher {
    enum Match: Equatable {
        case matched(Int)
        case ambiguous([Int])
        case none
    }

    struct ItemRef: Equatable {
        var name: String
        var quantity: Int
    }

    struct Assignment: Equatable {
        var person: String
        var itemIndex: Int
        var units: Int
    }

    struct Unmatched: Equatable {
        var person: String
        var phrase: String
        var candidates: [Int]
    }

    struct OverClaim: Equatable {
        var itemIndex: Int
        var claimed: Int
        var available: Int
    }

    struct Plan: Equatable {
        var assignments: [Assignment] = []
        var unmatched: [Unmatched] = []
        var overClaims: [OverClaim] = []
        var unparsed: [String] = []

        var isEmpty: Bool { assignments.isEmpty }
    }

    private static let threshold = 0.7
    private static let tieMargin = 0.05

    static func plan(for parsed: SplitTextParser.Result, items: [ItemRef]) -> Plan {
        var plan = Plan(unparsed: parsed.unparsed)
        var order: [String] = []
        var units: [String: Int] = [:]
        var people: [String: String] = [:]

        for claim in parsed.claims {
            switch match(claim.itemPhrase, in: items.map(\.name)) {
            case let .matched(index):
                let key = "\(claim.person.lowercased())|\(index)"
                if units[key] == nil { order.append(key) }
                units[key, default: 0] += claim.quantity
                people[key] = claim.person
            case let .ambiguous(candidates):
                plan.unmatched.append(Unmatched(person: claim.person, phrase: claim.itemPhrase, candidates: candidates))
            case .none:
                plan.unmatched.append(Unmatched(person: claim.person, phrase: claim.itemPhrase, candidates: []))
            }
        }

        var claimed: [Int: Int] = [:]
        for key in order {
            guard let index = key.split(separator: "|").last.flatMap({ Int($0) }),
                  let person = people[key], let count = units[key] else { continue }
            plan.assignments.append(Assignment(person: person, itemIndex: index, units: count))
            claimed[index, default: 0] += count
        }

        for (index, total) in claimed.sorted(by: { $0.key < $1.key }) where total > items[index].quantity {
            plan.overClaims.append(OverClaim(itemIndex: index, claimed: total, available: items[index].quantity))
        }
        return plan
    }

    static func match(_ phrase: String, in names: [String]) -> Match {
        let phraseTokens = tokens(phrase)
        guard !phraseTokens.isEmpty else { return .none }

        var scored: [(index: Int, score: Double)] = []
        for (index, name) in names.enumerated() {
            let value = score(phraseTokens, tokens(name))
            if value >= threshold { scored.append((index, value)) }
        }
        scored.sort { $0.score == $1.score ? $0.index < $1.index : $0.score > $1.score }

        guard let best = scored.first else { return .none }
        let close = scored.filter { best.score - $0.score <= tieMargin }.map(\.index)
        return close.count == 1 ? .matched(best.index) : .ambiguous(close)
    }

    private static func tokens(_ text: String) -> [String] {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static func score(_ phrase: [String], _ item: [String]) -> Double {
        guard !item.isEmpty else { return 0 }
        return coverage(of: phrase, in: item) * 0.8 + coverage(of: item, in: phrase) * 0.2
    }

    private static func coverage(of source: [String], in target: [String]) -> Double {
        var total = 0.0
        for token in source {
            var best = 0.0
            for other in target { best = max(best, similarity(token, other)) }
            total += best
        }
        return total / Double(source.count)
    }

    private static func similarity(_ a: String, _ b: String) -> Double {
        if a == b { return 1 }
        let longest = max(a.count, b.count)
        guard longest >= 4 else { return 0 }
        let value = 1 - Double(distance(a, b)) / Double(longest)
        return value >= 0.7 ? value : 0
    }

    private static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var previous = Array(0 ... b.count)
        for (i, left) in a.enumerated() {
            var row = [i + 1]
            for (j, right) in b.enumerated() {
                row.append(min(previous[j + 1] + 1, row[j] + 1, previous[j] + (left == right ? 0 : 1)))
            }
            previous = row
        }
        return previous[b.count]
    }
}
