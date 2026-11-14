//
//  SplitTextTests.swift
//  SwiftletTests
//

import Testing

@testable import Swiftlet

struct SplitTextParserTests {
    @Test func parsesTwoPeopleWithQuantities() {
        let result = SplitTextParser.parse("Andrew beli 2 nasi goreng, Abe beli 3 es teh")
        #expect(result.claims == [
            .init(person: "Andrew", itemPhrase: "nasi goreng", quantity: 2),
            .init(person: "Abe", itemPhrase: "es teh", quantity: 3),
        ])
    }

    @Test(arguments: ["2 x", "2x", "x2", "2 biji", "2 buah", "2 pcs", "2 porsi", "2 gelas", "dua"])
    func quantityMarkers(marker: String) {
        let trailing = SplitTextParser.parse("Andrew beli es teh \(marker)")
        #expect(trailing.claims == [.init(person: "Andrew", itemPhrase: "es teh", quantity: 2)])
        let leading = SplitTextParser.parse("Andrew beli \(marker) es teh")
        #expect(leading.claims == [.init(person: "Andrew", itemPhrase: "es teh", quantity: 2)])
    }

    @Test func defaultQuantityIsOne() {
        let result = SplitTextParser.parse("Tegar pesan ayam bakar")
        #expect(result.claims == [.init(person: "Tegar", itemPhrase: "ayam bakar", quantity: 1)])
    }

    @Test func separatorsSplitItemsForTheSamePerson() {
        let result = SplitTextParser.parse("Andrew beli nasi goreng dan es teh\nAbe makan sate 2 & kerupuk; Tegar: bakso")
        #expect(result.claims.map(\.person) == ["Andrew", "Andrew", "Abe", "Abe", "Tegar"])
        #expect(result.claims.map(\.itemPhrase) == ["nasi goreng", "es teh", "sate", "kerupuk", "bakso"])
        #expect(result.claims[2].quantity == 2)
    }

    @Test func clauseWithoutVerbContinuesPreviousPerson() {
        let result = SplitTextParser.parse("Andrew beli nasi goreng, es teh 2, Abe beli sate")
        #expect(result.claims == [
            .init(person: "Andrew", itemPhrase: "nasi goreng", quantity: 1),
            .init(person: "Andrew", itemPhrase: "es teh", quantity: 2),
            .init(person: "Abe", itemPhrase: "sate", quantity: 1),
        ])
    }

    @Test func textBeforeAnyPersonIsUnparsed() {
        let result = SplitTextParser.parse("nasi goreng")
        #expect(result.claims.isEmpty)
        #expect(result.unparsed == ["nasi goreng"])
    }

    @Test func englishVerbs() {
        let result = SplitTextParser.parse("Sara ordered 2 pasta, Tom had a burger")
        #expect(result.claims.map(\.person) == ["Sara", "Tom"])
        #expect(result.claims[0].quantity == 2)
    }
}

struct SplitTextMatcherTests {
    private let items: [SplitTextMatcher.ItemRef] = [
        .init(name: "Nasi Goreng Spesial", quantity: 2),
        .init(name: "Es Teh Manis", quantity: 5),
        .init(name: "Es Jeruk", quantity: 1),
        .init(name: "Ayam Bakar", quantity: 1),
    ]

    @Test func matchesIgnoringCaseAndPartialNames() {
        let names = items.map(\.name)
        #expect(SplitTextMatcher.match("nasi goreng", in: names) == .matched(0))
        #expect(SplitTextMatcher.match("ES TEH", in: names) == .matched(1))
        #expect(SplitTextMatcher.match("es jeruk", in: names) == .matched(2))
    }

    @Test func toleratesSmallTypos() {
        let names = items.map(\.name)
        #expect(SplitTextMatcher.match("ayam bakr", in: names) == .matched(3))
    }

    @Test func unknownPhraseIsNotGuessed() {
        #expect(SplitTextMatcher.match("pizza", in: items.map(\.name)) == .none)
    }

    @Test func ambiguousPhraseReportsCandidates() {
        let names = ["Es Teh Manis", "Es Teh Tawar"]
        #expect(SplitTextMatcher.match("es teh", in: names) == .ambiguous([0, 1]))
    }

    @Test func planMergesAndFlagsOverClaims() {
        let parsed = SplitTextParser.parse("Andrew beli 2 es teh, Abe beli 4 es teh, Tegar beli pizza")
        let plan = SplitTextMatcher.plan(for: parsed, items: items)
        #expect(plan.assignments == [
            .init(person: "Andrew", itemIndex: 1, units: 2),
            .init(person: "Abe", itemIndex: 1, units: 4),
        ])
        #expect(plan.overClaims == [.init(itemIndex: 1, claimed: 6, available: 5)])
        #expect(plan.unmatched.map(\.phrase) == ["pizza"])
    }

    @Test func repeatedClaimsForSamePersonAddUp() {
        let parsed = SplitTextParser.parse("Andrew beli es teh, Andrew beli es teh 2")
        let plan = SplitTextMatcher.plan(for: parsed, items: items)
        #expect(plan.assignments == [.init(person: "Andrew", itemIndex: 1, units: 3)])
    }
}
