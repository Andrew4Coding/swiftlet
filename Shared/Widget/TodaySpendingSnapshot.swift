//
//  TodaySpendingSnapshot.swift
//  Swiftlet
//

import Foundation

/// Kind identifier shared between the app (which reloads timelines) and the widget extension.
enum SwiftletWidgetKind {
    static let todaySpending = "TodaySpendingWidget"
}

/// Today's expense-by-category breakdown, precomputed by the app and handed to the widget
/// extension through the App Group container. The widget never touches SwiftData directly.
struct TodaySpendingSnapshot: Codable {
    struct Slice: Codable, Identifiable, Hashable {
        var name: String
        var amount: Decimal
        var fraction: Double

        var id: String { name }
    }

    var generatedAt: Date
    var totalExpense: Decimal
    var slices: [Slice]

    static let empty = TodaySpendingSnapshot(generatedAt: .distantPast, totalExpense: 0, slices: [])

    static let appGroupID = "group.com.andrew4coding.swiftlet.sharedData"
    private static let fileName = "today-spending-snapshot.json"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    static func load() -> TodaySpendingSnapshot {
        guard
            let fileURL,
            let data = try? Data(contentsOf: fileURL),
            let snapshot = try? Self.decoder.decode(TodaySpendingSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    func save() {
        guard let fileURL = Self.fileURL, let data = try? Self.encoder.encode(self) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
