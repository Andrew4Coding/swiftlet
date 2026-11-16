//
//  TransactionExportFormat.swift
//  Swiftlet
//

import UniformTypeIdentifiers

enum TransactionExportFormat: String, CaseIterable, Identifiable {
    case csv
    case json

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .csv: "CSV"
        case .json: "JSON"
        }
    }

    var contentType: UTType {
        switch self {
        case .csv: .commaSeparatedText
        case .json: .json
        }
    }
}
