//
//  SplitCalculatorTests.swift
//  SwiftletTests
//

import Testing

@testable import Swiftlet

struct SplitCalculatorTests {
    @Test func equalSplitSumsExactlyAndDiffersByAtMostOne() {
        for total in [0, 1, 99_999, 100_000, 1_234_567] {
            for count in 1 ... 12 {
                let shares = SplitCalculator.equalSplit(total: total, count: count)
                #expect(shares.count == count)
                #expect(shares.reduce(0, +) == total)
                #expect((shares.max() ?? 0) - (shares.min() ?? 0) <= 1)
            }
        }
    }

    @Test func equalSplitOfOneHundredThousandByThree() {
        #expect(SplitCalculator.equalSplit(total: 100_000, count: 3) == [33_334, 33_333, 33_333])
    }

    @Test func equalSplitWithNoPeopleIsEmpty() {
        #expect(SplitCalculator.equalSplit(total: 100, count: 0).isEmpty)
    }

    @Test func allocateIsProportionalAndExact() {
        let shares = SplitCalculator.allocate(total: 21_000, weights: [100_000, 50_000, 60_000])
        #expect(shares.reduce(0, +) == 21_000)
        #expect(shares == [10_000, 5_000, 6_000])
    }

    @Test func allocateGivesLeftoverToLargestRemainders() {
        let shares = SplitCalculator.allocate(total: 10, weights: [1, 1, 1])
        #expect(shares == [4, 3, 3])
    }

    @Test func allocateWithZeroWeightsFallsBackToEqual() {
        #expect(SplitCalculator.allocate(total: 10, weights: [0, 0]) == [5, 5])
    }

    @Test func allocateNegativeTotalKeepsSum() {
        let shares = SplitCalculator.allocate(total: -10, weights: [1, 1, 1])
        #expect(shares.reduce(0, +) == -10)
    }

    @Test func itemizedSplitSharesExtrasByItemSubtotal() {
        let items = [
            SplitCalculator.Item(price: 100_000, assignees: [0]),
            SplitCalculator.Item(price: 50_000, assignees: [1]),
            SplitCalculator.Item(price: 60_000, assignees: [2]),
        ]
        let extras = SplitCalculator.Extras(service: 10_500, tax: 21_000)
        let result = SplitCalculator.itemizedSplit(items: items, extras: extras, participantCount: 3)

        #expect(result.unassigned == 0)
        #expect(result.total == 210_000 + 31_500)
        #expect(result.shares[0] > result.shares[2])
        #expect(result.shares[2] > result.shares[1])
    }

    @Test func itemSharedBetweenTwoPeopleSplitsEvenly() {
        let items = [SplitCalculator.Item(price: 90_000, assignees: [0, 1])]
        let result = SplitCalculator.itemizedSplit(items: items, extras: .init(), participantCount: 3)
        #expect(result.shares == [45_000, 45_000, 0])
    }

    @Test func itemSharedBetweenThreeKeepsEveryRupiah() {
        let items = [SplitCalculator.Item(price: 100_000, assignees: [0, 1, 2])]
        let result = SplitCalculator.itemizedSplit(items: items, extras: .init(), participantCount: 3)
        #expect(result.total == 100_000)
    }

    @Test func discountReducesShares() {
        let items = [
            SplitCalculator.Item(price: 60_000, assignees: [0]),
            SplitCalculator.Item(price: 40_000, assignees: [1]),
        ]
        let result = SplitCalculator.itemizedSplit(items: items, extras: .init(discount: 10_000), participantCount: 2)
        #expect(result.shares == [54_000, 36_000])
    }

    @Test func unassignedItemsAreReportedAndExcludedFromShares() {
        let items = [
            SplitCalculator.Item(price: 30_000, assignees: [0]),
            SplitCalculator.Item(price: 20_000, assignees: []),
        ]
        let result = SplitCalculator.itemizedSplit(items: items, extras: .init(), participantCount: 2)
        #expect(result.unassigned == 20_000)
        #expect(result.shares == [30_000, 0])
    }

    @Test func outOfRangeAssigneesAreIgnored() {
        let items = [SplitCalculator.Item(price: 10_000, assignees: [5])]
        let result = SplitCalculator.itemizedSplit(items: items, extras: .init(), participantCount: 2)
        #expect(result.unassigned == 10_000)
    }

    @Test func noParticipantsLeavesEverythingUnassigned() {
        let items = [SplitCalculator.Item(price: 10_000, assignees: [0])]
        let result = SplitCalculator.itemizedSplit(items: items, extras: .init(), participantCount: 0)
        #expect(result.shares.isEmpty)
        #expect(result.unassigned == 10_000)
    }
}
