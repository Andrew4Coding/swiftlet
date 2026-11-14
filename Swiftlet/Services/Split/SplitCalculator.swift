//
//  SplitCalculator.swift
//  Swiftlet
//

import Foundation

nonisolated enum SplitCalculator {
    struct Item: Equatable {
        var price: Int
        var assignees: [Int]
        var quantity: Int = 1
        var units: [Int: Int] = [:]
    }

    struct Extras: Equatable {
        var service: Int = 0
        var tax: Int = 0
        var discount: Int = 0

        var net: Int { service + tax - discount }
    }

    struct Result: Equatable {
        var shares: [Int]
        var unassigned: Int

        var total: Int { shares.reduce(0, +) }
    }

    static func equalSplit(total: Int, count: Int) -> [Int] {
        guard count > 0 else { return [] }
        let base = total / count
        let remainder = total - base * count
        return (0 ..< count).map { base + ($0 < remainder ? 1 : 0) }
    }

    static func allocate(total: Int, weights: [Int]) -> [Int] {
        guard !weights.isEmpty else { return [] }
        let weightSum = weights.reduce(0, +)
        guard weightSum > 0 else { return equalSplit(total: total, count: weights.count) }

        let sign = total < 0 ? -1 : 1
        let magnitude = abs(total)
        var shares = weights.map { magnitude * $0 / weightSum }
        let remainders = weights.map { magnitude * $0 % weightSum }
        let leftover = magnitude - shares.reduce(0, +)

        let order = weights.indices.sorted {
            remainders[$0] == remainders[$1] ? $0 < $1 : remainders[$0] > remainders[$1]
        }
        for index in order.prefix(leftover) {
            shares[index] += 1
        }
        return shares.map { $0 * sign }
    }

    static func itemizedSplit(items: [Item], extras: Extras, participantCount: Int) -> Result {
        guard participantCount > 0 else { return Result(shares: [], unassigned: items.reduce(0) { $0 + $1.price }) }

        var subtotals = Array(repeating: 0, count: participantCount)
        var unassigned = 0

        for item in items {
            let assignees = Array(Set(item.assignees.filter { $0 >= 0 && $0 < participantCount })).sorted()
            guard !assignees.isEmpty else {
                unassigned += item.price
                continue
            }
            if item.units.isEmpty {
                for (offset, share) in equalSplit(total: item.price, count: assignees.count).enumerated() {
                    subtotals[assignees[offset]] += share
                }
                continue
            }

            let weights = assignees.map { max(item.units[$0] ?? 0, 0) }
            let leftover = max(item.quantity - weights.reduce(0, +), 0)
            let parts = allocate(total: item.price, weights: weights + [leftover])
            for (offset, index) in assignees.enumerated() {
                subtotals[index] += parts[offset]
            }
            unassigned += parts[assignees.count]
        }

        let assignedTotal = subtotals.reduce(0, +)
        guard assignedTotal > 0 else {
            return Result(shares: subtotals, unassigned: unassigned)
        }

        let extraShares = allocate(total: extras.net, weights: subtotals)
        let shares = zip(subtotals, extraShares).map { $0 + $1 }
        return Result(shares: shares, unassigned: unassigned)
    }
}
