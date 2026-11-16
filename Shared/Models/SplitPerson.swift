//
//  SplitPerson.swift
//  Swiftlet
//

import Foundation
import SwiftData

@Model
final class SplitPerson {
    var name: String = ""
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \SplitShare.person)
    var shares: [SplitShare]? = []

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }

    var outstanding: Int {
        (shares ?? []).reduce(0) { $0 + $1.outstanding }
    }
}
