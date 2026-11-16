import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MacRootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager

    @Query(sort: [SortDescriptor(\SavedFilter.sortIndex), SortDescriptor(\SavedFilter.createdAt)])
    private var savedFilters: [SavedFilter]

    @State private var isDropTargeted = false

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 300)
        } detail: {
            detail
        }
        .sheet(isPresented: $appState.isPresentingAdd) {
            NewTransactionSheet(receiptData: appState.pendingReceiptData)
        }
        .fileImporter(
            isPresented: $appState.isImporting,
            allowedContentTypes: [.commaSeparatedText, .json]
        ) { result in
            if case let .success(url) = result {
                appState.importFile(at: url, context: modelContext)
            }
        }
        .alert(
            "Swiftlet",
            isPresented: Binding(
                get: { appState.statusMessage != nil },
                set: { if !$0 { appState.statusMessage = nil } }
            ),
            presenting: appState.statusMessage
        ) { _ in
            Button("OK") {}
        } message: { message in
            Text(message)
        }
        .onDrop(of: [.fileURL, .image], isTargeted: $isDropTargeted, perform: handleDrop)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.ds(.accent), lineWidth: 3)
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
        .importsItemProviders([.image]) { providers in
            loadImage(from: providers)
        }
        .onAppear {
            modelContext.undoManager = undoManager
        }
        .onChange(of: undoManager) { _, newValue in
            modelContext.undoManager = newValue
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch appState.sidebarSelection ?? .home {
        case .home:
            DashboardView()
        case .transactions:
            TransactionsView(savedFilter: nil)
        case let .smartView(id):
            if let savedFilter = savedFilters.first(where: { $0.persistentModelID == id }) {
                TransactionsView(savedFilter: savedFilter)
                    .id(id)
            } else {
                ContentUnavailableView("Smart view removed", systemImage: "line.3.horizontal.decrease.circle")
            }
        case .wallets:
            WalletsView()
        case .splits:
            SplitsView()
        case .recurring:
            RecurringView()
        case .categories:
            CategoriesView()
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        if loadImage(from: providers) {
            return true
        }
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in
                handleDroppedFile(url)
            }
        }
        return true
    }

    private func handleDroppedFile(_ url: URL) {
        let type = UTType(filenameExtension: url.pathExtension)
        if type?.conforms(to: .image) == true, let data = try? Data(contentsOf: url) {
            appState.presentAdd(receipt: data)
        } else if type?.conforms(to: .commaSeparatedText) == true || type?.conforms(to: .json) == true {
            appState.importFile(at: url, context: modelContext)
        } else {
            appState.statusMessage = "Drop a receipt image or a Swiftlet CSV export."
        }
    }

    @discardableResult
    private func loadImage(from providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
                && !$0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else { return false }
        _ = provider.loadDataRepresentation(for: .image) { data, _ in
            guard let data else { return }
            Task { @MainActor in
                appState.presentAdd(receipt: data)
            }
        }
        return true
    }
}
