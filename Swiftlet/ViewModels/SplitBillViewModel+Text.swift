//
//  SplitBillViewModel+Text.swift
//  Swiftlet
//

import Foundation

extension SplitBillViewModel {
    struct TextLine: Identifiable, Equatable {
        let id = UUID()
        var itemID: UUID
        var itemName: String
        var units: Int
    }

    struct TextEntry: Identifiable, Equatable {
        let id = UUID()
        var name: String
        var participantID: UUID?
        var lines: [TextLine]

        var isNew: Bool { participantID == nil }
    }

    struct TextUnmatched: Identifiable, Equatable {
        let id = UUID()
        var person: String
        var phrase: String
        var candidateNames: [String]
        var suggestedItemID: UUID?
        var suggestedItemName: String?
    }

    struct TextOverClaim: Identifiable, Equatable {
        let id = UUID()
        var itemName: String
        var claimed: Int
        var available: Int
    }

    struct TextPreview: Equatable {
        var entries: [TextEntry]
        var unmatched: [TextUnmatched]
        var overClaims: [TextOverClaim]
        var unparsed: [String]

        var isEmpty: Bool { entries.isEmpty }
    }

    private static let selfAliases: Set<String> = ["saya", "aku", "gue", "gua", "gw", "me", "i", "im", "my", "mine", "myself", "you", "kamu"]

    func previewText(_ text: String) -> TextPreview {
        let parsed = SplitTextParser.parse(text)
        let refs = items.map { SplitTextMatcher.ItemRef(name: $0.name, quantity: $0.quantity) }
        let plan = SplitTextMatcher.plan(for: parsed, items: refs)

        var entries: [TextEntry] = []
        for assignment in plan.assignments {
            let item = items[assignment.itemIndex]
            let line = TextLine(itemID: item.id, itemName: displayName(of: item), units: assignment.units)
            let participantID = resolveParticipant(named: assignment.person)
            let name = participantID.flatMap { id in participants.first { $0.id == id }?.name }
                ?? assignment.person.capitalized

            if let index = entries.firstIndex(where: { entry in
                participantID != nil ? entry.participantID == participantID
                    : entry.name.caseInsensitiveCompare(name) == .orderedSame
            }) {
                entries[index].lines.append(line)
            } else {
                entries.append(TextEntry(name: name, participantID: participantID, lines: [line]))
            }
        }

        let unmatched = plan.unmatched.map { entry in
            TextUnmatched(
                person: entry.person,
                phrase: entry.phrase,
                candidateNames: entry.candidates.map { displayName(of: items[$0]) }
            )
        }
        let overClaims = plan.overClaims.map {
            TextOverClaim(itemName: displayName(of: items[$0.itemIndex]), claimed: $0.claimed, available: $0.available)
        }
        return TextPreview(entries: entries, unmatched: unmatched, overClaims: overClaims, unparsed: plan.unparsed)
    }

    func applyText(_ preview: TextPreview, knownPeople: [SplitPerson] = []) {
        for entry in preview.entries {
            var participantID = entry.participantID
            if participantID == nil {
                let known = knownPeople.first { $0.name.caseInsensitiveCompare(entry.name) == .orderedSame }
                addParticipant(name: entry.name, person: known)
                participantID = participants.first { $0.name.caseInsensitiveCompare(entry.name) == .orderedSame }?.id
            }
            guard let participantID else { continue }

            for line in entry.lines {
                guard let index = items.firstIndex(where: { $0.id == line.itemID }) else { continue }
                if items[index].assigneeUnits.isEmpty { items[index].assigneeIDs = [] }
                items[index].assigneeUnits[participantID] = nil
            }
        }

        for entry in preview.entries {
            guard let participantID = entry.participantID
                ?? participants.first(where: { $0.name.caseInsensitiveCompare(entry.name) == .orderedSame })?.id
            else { continue }

            for line in entry.lines {
                guard let index = items.firstIndex(where: { $0.id == line.itemID }) else { continue }
                items[index].assigneeUnits[participantID, default: 0] += line.units
                items[index].assigneeIDs.insert(participantID)
            }
        }
    }

    func resolveParticipant(named name: String) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let alias = trimmed.lowercased().filter { $0.isLetter }
        if Self.selfAliases.contains(alias), let me = participants.first(where: \.isMe) {
            return me.id
        }
        if let exact = participants.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return exact.id
        }
        guard trimmed.count >= 2 else { return nil }
        let prefixed = participants.filter { $0.name.lowercased().hasPrefix(trimmed.lowercased()) }
        return prefixed.count == 1 ? prefixed[0].id : nil
    }

    func addSuggestion(_ unmatched: TextUnmatched, to preview: inout TextPreview) {
        guard let itemID = unmatched.suggestedItemID,
              let item = items.first(where: { $0.id == itemID }) else { return }

        let participantID = resolveParticipant(named: unmatched.person)
        let name = participantID.flatMap { id in participants.first { $0.id == id }?.name }
            ?? unmatched.person.capitalized
        let line = TextLine(itemID: item.id, itemName: displayName(of: item), units: 1)

        if let index = preview.entries.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            preview.entries[index].lines.append(line)
        } else {
            preview.entries.append(TextEntry(name: name, participantID: participantID, lines: [line]))
        }
        preview.unmatched.removeAll { $0.id == unmatched.id }
    }

    func suggestMatches(for preview: TextPreview) async -> TextPreview {
        guard !preview.unmatched.isEmpty, SplitTextModelMatcher.isAvailable else { return preview }
        let names = items.map { displayName(of: $0) }
        let suggestions = await SplitTextModelMatcher.suggest(
            phrases: preview.unmatched.map(\.phrase),
            itemNames: names
        )

        var result = preview
        for index in result.unmatched.indices {
            guard let itemIndex = suggestions[result.unmatched[index].phrase], items.indices.contains(itemIndex) else { continue }
            result.unmatched[index].suggestedItemID = items[itemIndex].id
            result.unmatched[index].suggestedItemName = names[itemIndex]
        }
        return result
    }

    private func displayName(of item: DraftItem) -> String {
        let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Item" : trimmed
    }
}
