import Foundation
import SwiftData

nonisolated struct ChatChart: Sendable, Equatable {
    var title: String
    var points: [Point]

    struct Point: Sendable, Equatable {
        var label: String
        var value: Int
        var valueText: String
    }
}

nonisolated struct ChatTable: Sendable, Equatable {
    var title: String?
    var columns: [Column]
    var rows: [Row]

    struct Column: Sendable, Equatable {
        var title: String
        var isTrailing = false
        var isBold = false
        var isFlexible = false
    }

    struct Row: Sendable, Equatable {
        var cells: [String]
        var transactionID: PersistentIdentifier? = nil
    }

    var plainText: String {
        let header = columns.map(\.title).joined(separator: "\t")
        let body = rows.map { $0.cells.joined(separator: "\t") }
        return ([title, header].compactMap { $0 } + body).joined(separator: "\n")
    }
}

nonisolated enum ChatBlock: Sendable, Equatable {
    case chart(ChatChart)
    case table(ChatTable)
    case image(Data)

    var copyText: String? {
        switch self {
        case let .chart(chart): ([chart.title] + chart.points.map { "\($0.label)\t\($0.valueText)" }).joined(separator: "\n")
        case let .table(table): table.plainText
        case .image: nil
        }
    }
}
