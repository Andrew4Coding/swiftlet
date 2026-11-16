//
//  EmojiCatalog.swift
//  Swiftlet
//

import Foundation

/// Emoji list built from Unicode scalar properties instead of a hand-maintained table, so new
/// OS emoji show up without code changes. Search matches against each emoji's Unicode name.
enum EmojiCatalog {
    struct Entry: Hashable, Identifiable {
        let emoji: String
        let searchName: String

        var id: String {
            emoji
        }
    }

    struct Section: Identifiable {
        let title: String
        let entries: [Entry]

        var id: String {
            title
        }
    }

    static let suggested: [String] = [
        "🍜", "☕️", "🛒", "🚗", "🧳", "🛍️", "🧾", "📱", "🌐", "🎮", "💊", "🏋️", "🎓", "🐾",
        "🏠", "👨‍👩‍👧", "💰", "🎁", "📈", "🐷", "💼", "💝", "🏛️", "⛽️", "🍔", "🍺", "🎬", "✈️",
        "🚌", "💡", "💧", "🔥", "🧴", "👕", "💇", "🩺", "🚑", "🎵", "📚", "🧸", "🆘", "💳",
    ]

    private static let ranges: [(title: String, range: ClosedRange<UInt32>)] = [
        ("Smileys & People", 0x1F600 ... 0x1F64F),
        ("Gestures & People", 0x1F90C ... 0x1F9FF),
        ("Animals, Food & Objects", 0x1F300 ... 0x1F5FF),
        ("Travel & Places", 0x1F680 ... 0x1F6FF),
        ("More Objects", 0x1FA70 ... 0x1FAFF),
        ("Symbols", 0x2600 ... 0x27BF),
    ]

    static let sections: [Section] = {
        let suggestedSection = Section(title: "Suggested", entries: suggested.map(entry(for:)))
        let generated = ranges.compactMap { title, range -> Section? in
            let entries = range.compactMap { value -> Entry? in
                guard let scalar = Unicode.Scalar(value), scalar.properties.isEmojiPresentation else { return nil }
                return entry(for: String(Character(scalar)))
            }
            return entries.isEmpty ? nil : Section(title: title, entries: entries)
        }
        return [suggestedSection] + generated
    }()

    static func search(_ query: String) -> [Entry] {
        let terms = query.lowercased().split(separator: " ").map(String.init)
        guard !terms.isEmpty else { return [] }

        var seen = Set<String>()
        return sections
            .flatMap(\.entries)
            .filter { entry in terms.allSatisfy(entry.searchName.contains) && seen.insert(entry.emoji).inserted }
    }

    private static func entry(for emoji: String) -> Entry {
        let name = emoji.applyingTransform(.toUnicodeName, reverse: false) ?? ""
        let cleaned = name
            .replacingOccurrences(of: "\\N{", with: " ")
            .replacingOccurrences(of: "}", with: " ")
            .lowercased()
        return Entry(emoji: emoji, searchName: cleaned)
    }
}
