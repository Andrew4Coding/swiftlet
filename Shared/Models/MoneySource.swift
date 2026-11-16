//
//  MoneySource.swift
//  Swiftlet
//

import AppIntents
import Foundation

enum MoneySource: String, Codable, CaseIterable, Identifiable, AppEnum {
    case grab
    case gopay
    case bca
    case bni
    case ovo
    case qris

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .grab: "Grab"
        case .gopay: "GoPay"
        case .bca: "BCA"
        case .bni: "BNI"
        case .ovo: "OVO"
        case .qris: "QRIS"
        }
    }

    /// Asset catalog image name, or `nil` for sources drawn with an SF Symbol instead.
    var imageName: String? {
        switch self {
        case .grab: "grab"
        case .gopay: "gopay"
        case .bca: "bca"
        case .bni: "bni"
        case .ovo, .qris: nil
        }
    }

    /// SF Symbol fallback used when the source has no logo in the asset catalog.
    var symbolName: String {
        switch self {
        case .qris: "qrcode"
        default: "creditcard.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .grab: "00B14F"
        case .gopay: "FFFFFF"
        case .bca: "0066AE"
        case .bni: "F37021"
        case .ovo: "4C3494"
        case .qris: "1E4C9A"
        }
    }

    var scope: CategoryScope {
        switch self {
        case .grab: .expense
        case .qris: .income
        case .gopay, .bca, .bni, .ovo: .both
        }
    }

    static func available(for type: TransactionType) -> [MoneySource] {
        allCases.filter { $0.scope.allows(type) }
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Money Source"
    }

    static var caseDisplayRepresentations: [MoneySource: DisplayRepresentation] {
        [.grab: "Grab",
         .gopay: "GoPay",
         .bca: "BCA",
         .bni: "BNI",
         .ovo: "OVO",
         .qris: "QRIS"]
    }
}
