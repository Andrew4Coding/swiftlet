import SwiftData
import SwiftUI

enum SidebarItem: Hashable {
    case home
    case transactions
    case wallets
    case splits
    case recurring
    case categories
    case smartView(PersistentIdentifier)

    static let sections: [SidebarItem] = [.home, .transactions, .wallets, .splits, .recurring, .categories]

    var title: String {
        switch self {
        case .home: "Home"
        case .transactions: "Transactions"
        case .wallets: "Wallets"
        case .splits: "Splits"
        case .recurring: "Recurring"
        case .categories: "Categories"
        case .smartView: "Smart View"
        }
    }

    var symbolName: String {
        switch self {
        case .home: "chart.bar.xaxis"
        case .transactions: "list.bullet.rectangle"
        case .wallets: "wallet.bifold"
        case .splits: "person.2"
        case .recurring: "arrow.triangle.2.circlepath"
        case .categories: "tag"
        case .smartView: "line.3.horizontal.decrease.circle"
        }
    }

    var keyboardShortcut: KeyEquivalent? {
        guard let index = Self.sections.firstIndex(of: self) else { return nil }
        return KeyEquivalent(Character(String(index + 1)))
    }
}
