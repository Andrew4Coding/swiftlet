import Foundation
import SwiftData

@Model
final class SavedFilter {
    var name: String = ""
    var symbolName: String = "line.3.horizontal.decrease.circle"
    var filterData: Data = Data()
    var sortIndex: Int = 0
    var createdAt: Date = Date.now

    init(name: String, filter: TransactionFilter, sortIndex: Int = 0, createdAt: Date = .now) {
        self.name = name
        filterData = filter.encoded()
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }

    var filter: TransactionFilter {
        get { TransactionFilter.decoded(from: filterData) }
        set { filterData = newValue.encoded() }
    }
}
