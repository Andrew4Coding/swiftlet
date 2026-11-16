//
//  StatBucket.swift
//  Swiftlet
//

import Foundation

/// A single aggregated point for the bar chart — not persisted, built on the fly by `StatsBucketing`.
struct StatBucket: Identifiable {
    let id = UUID()
    let label: String
    let date: Date
    let income: Decimal
    let expense: Decimal
}
