import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct TransactionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    let savedFilter: SavedFilter?

    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: [SortDescriptor(\SavedFilter.sortIndex)]) private var savedFilters: [SavedFilter]

    @State private var selection = Set<PersistentIdentifier>()
    @State private var sortOrder = [KeyPathComparator(\Transaction.date, order: .reverse)]
    @State private var isInspectorPresented = true
    @State private var isNamingSmartView = false
    @State private var smartViewName = ""
    @State private var exportDocument: TransactionDocument?
    @State private var exportContentType: UTType = .commaSeparatedText
    @State private var exportFilename = "Transactions"
    @State private var isExporting = false

    private var visibleTransactions: [Transaction] {
        appState.transactionFilter
            .apply(to: allTransactions) { $0.filterRow }
            .sorted(using: sortOrder)
    }

    private var selectedTransactions: [Transaction] {
        allTransactions.filter { selection.contains($0.persistentModelID) }
    }

    private var title: String {
        savedFilter?.name ?? "Transactions"
    }

    private var hasUnsavedSmartViewChanges: Bool {
        guard let savedFilter else { return false }
        return savedFilter.filter != appState.transactionFilter
    }

    var body: some View {
        @Bindable var appState = appState
        let transactions = visibleTransactions

        VStack(spacing: 0) {
            TransactionFilterBar(filter: $appState.transactionFilter)
            Divider()
            TransactionTable(
                transactions: transactions,
                selection: $selection,
                sortOrder: $sortOrder
            )
            .overlay {
                if transactions.isEmpty {
                    emptyState
                }
            }
            Divider()
            TotalsFooter(transactions: transactions, selectedCount: selection.count)
        }
        .navigationTitle(title)
        .navigationSubtitle("\(transactions.count) shown")
        .searchable(text: $appState.transactionFilter.searchText, placement: .toolbar, prompt: "Search title, note, category")
        .inspector(isPresented: $isInspectorPresented) {
            TransactionInspector(transactions: selectedTransactions, onDelete: { delete(selectedTransactions) })
                .inspectorColumnWidth(min: 280, ideal: 320, max: 420)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.presentAdd()
                } label: {
                    Label("New Transaction", systemImage: "plus")
                }
                .help("New Transaction (⌘N)")
            }
            ToolbarItem {
                smartViewButton
            }
            ToolbarItem {
                Menu {
                    Button("Export as CSV…") { export(.csv) }
                    Button("Export as PDF…") { export(.pdf) }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export the rows shown")
            }
            ToolbarItem {
                Button {
                    isInspectorPresented.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
                .help("Show or hide the inspector (⌃⌘I)")
            }
        }
        .onDeleteCommand {
            delete(selectedTransactions)
        }
        .onPasteCommand(of: [.png, .jpeg, .tiff, .image]) { providers in
            guard let provider = providers.first else { return }
            _ = provider.loadDataRepresentation(for: .image) { data, _ in
                guard let data else { return }
                Task { @MainActor in appState.presentAdd(receipt: data) }
            }
        }
        .onChange(of: appState.exportRequest) { _, request in
            guard let request else { return }
            appState.exportRequest = nil
            export(request)
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: exportContentType,
            defaultFilename: exportFilename
        ) { result in
            if case let .failure(error) = result {
                appState.statusMessage = "Export failed: \(error.localizedDescription)"
            }
        }
        .alert("New Smart View", isPresented: $isNamingSmartView) {
            TextField("Name", text: $smartViewName)
            Button("Save") { saveSmartView() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pins the current search and filters to the sidebar.")
        }
    }

    @ViewBuilder
    private var smartViewButton: some View {
        if let savedFilter, hasUnsavedSmartViewChanges {
            Button {
                savedFilter.filter = appState.transactionFilter
                try? modelContext.save()
            } label: {
                Label("Update Smart View", systemImage: "pin.fill")
            }
            .help("Save these filters to \(savedFilter.name)")
        } else if savedFilter == nil {
            Button {
                smartViewName = suggestedSmartViewName
                isNamingSmartView = true
            } label: {
                Label("Save as Smart View", systemImage: "pin")
            }
            .help("Pin the current filters to the sidebar")
            .disabled(appState.transactionFilter.isEmpty)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if allTransactions.isEmpty {
            ContentUnavailableView {
                Label("No transactions yet", systemImage: "list.bullet.rectangle")
            } description: {
                Text("Add one with ⌘N, drop a receipt or a CSV here, or add from the menu bar.")
            } actions: {
                Button("New Transaction") { appState.presentAdd() }
            }
        } else {
            ContentUnavailableView {
                Label("No matches", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("No transactions match the current search and filters.")
            } actions: {
                Button("Clear Filters") { appState.transactionFilter = TransactionFilter() }
            }
        }
    }

    private var suggestedSmartViewName: String {
        let filter = appState.transactionFilter
        if let category = filter.categoryNames.first, filter.categoryNames.count == 1 {
            return "\(category) · \(filter.period.displayName)"
        }
        if !filter.searchText.isEmpty {
            return filter.searchText
        }
        return "Smart View \(savedFilters.count + 1)"
    }

    private func saveSmartView() {
        let name = smartViewName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let savedFilter = SavedFilter(
            name: name,
            filter: appState.transactionFilter,
            sortIndex: (savedFilters.map(\.sortIndex).max() ?? -1) + 1
        )
        modelContext.insert(savedFilter)
        try? modelContext.save()
        appState.select(savedFilter)
    }

    private func export(_ kind: AppState.ExportKind) {
        let rows = visibleTransactions
        exportFilename = title
        switch kind {
        case .csv:
            exportContentType = .commaSeparatedText
            exportDocument = TransactionDocument(data: TransactionIOService.export(rows, format: .csv))
        case .pdf:
            exportContentType = .pdf
            exportDocument = TransactionDocument(data: TransactionPDFRenderer.render(
                transactions: rows,
                title: title,
                timeRange: TransactionFilterDescription.timeRange(appState.transactionFilter)
            ))
        }
        isExporting = true
    }

    private func delete(_ transactions: [Transaction]) {
        guard !transactions.isEmpty else { return }
        BulkTransactionActions.delete(transactions, context: modelContext)
        selection.removeAll()
    }
}

private struct TotalsFooter: View {
    let transactions: [Transaction]
    let selectedCount: Int

    var body: some View {
        let summary = DashboardSummary(rows: transactions.map(\.filterRow))
        HStack(spacing: 18) {
            if selectedCount > 0 {
                Text("\(selectedCount) selected")
            }
            Spacer()
            Text("Income \(CurrencyFormatter.rupiah(Decimal(summary.income)))")
            Text("Expense \(CurrencyFormatter.rupiah(Decimal(summary.expense)))")
            Text("Net \(CurrencyFormatter.rupiah(Decimal(summary.net)))")
                .fontWeight(.semibold)
        }
        .font(.callout)
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
