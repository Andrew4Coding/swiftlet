import Observation
import SwiftData
import SwiftUI

@Observable
final class AppState {
    enum ExportKind {
        case csv
        case pdf
    }

    var sidebarSelection: SidebarItem? = .home
    var transactionFilter = TransactionFilter()
    static let dashboardBaseline: TransactionFilter = {
        var filter = TransactionFilter()
        filter.period = .thisMonth
        return filter
    }()

    var dashboardFilter = AppState.dashboardBaseline

    var isPresentingAdd = false
    var pendingReceiptData: Data?
    var isImporting = false
    var exportRequest: ExportKind?
    var statusMessage: String?

    var openQuickAddWindow: (() -> Void)?

    func presentAdd(receipt: Data? = nil) {
        pendingReceiptData = receipt
        isPresentingAdd = true
    }

    func showTransactions(matching filter: TransactionFilter) {
        transactionFilter = filter
        sidebarSelection = .transactions
    }

    func select(_ savedFilter: SavedFilter) {
        transactionFilter = savedFilter.filter
        sidebarSelection = .smartView(savedFilter.persistentModelID)
    }

    func openQuickAdd() {
        NSApp.activate()
        openQuickAddWindow?()
    }

    @MainActor
    func importFile(at url: URL, context: ModelContext) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let data = try Data(contentsOf: url)
            let result = url.pathExtension.lowercased() == "json"
                ? try TransactionIOService.importJSON(data, into: context)
                : try TransactionIOService.importCSV(data, into: context)
            statusMessage = "Imported \(result.imported) transactions, skipped \(result.skipped) duplicates or invalid rows."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
