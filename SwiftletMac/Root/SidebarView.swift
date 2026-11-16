import SwiftData
import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\SavedFilter.sortIndex), SortDescriptor(\SavedFilter.createdAt)])
    private var savedFilters: [SavedFilter]

    @State private var renaming: SavedFilter?
    @State private var newName = ""

    var body: some View {
        @Bindable var appState = appState

        List(selection: $appState.sidebarSelection) {
            Section {
                ForEach(SidebarItem.sections, id: \.self) { item in
                    Label(item.title, systemImage: item.symbolName)
                        .tag(item)
                }
            }

            Section("Smart Views") {
                if savedFilters.isEmpty {
                    Text("Save a filter from Transactions to pin it here.")
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(.secondary)
                }
                ForEach(savedFilters) { savedFilter in
                    Label(savedFilter.name, systemImage: savedFilter.symbolName)
                        .tag(SidebarItem.smartView(savedFilter.persistentModelID))
                        .contextMenu {
                            Button("Rename…") {
                                newName = savedFilter.name
                                renaming = savedFilter
                            }
                            Button("Delete", role: .destructive) {
                                delete(savedFilter)
                            }
                        }
                }
                .onMove(perform: move)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            SyncStatusView()
                .padding(10)
        }
        .onChange(of: appState.sidebarSelection) { _, selection in
            guard case let .smartView(id) = selection,
                  let savedFilter = savedFilters.first(where: { $0.persistentModelID == id })
            else { return }
            appState.transactionFilter = savedFilter.filter
        }
        .alert("Rename Smart View", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            TextField("Name", text: $newName)
            Button("Rename") {
                let trimmed = newName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    renaming?.name = trimmed
                    try? modelContext.save()
                }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    private func delete(_ savedFilter: SavedFilter) {
        if appState.sidebarSelection == .smartView(savedFilter.persistentModelID) {
            appState.sidebarSelection = .transactions
        }
        modelContext.delete(savedFilter)
        try? modelContext.save()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = savedFilters
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, savedFilter) in ordered.enumerated() {
            savedFilter.sortIndex = index
        }
        try? modelContext.save()
    }
}

private struct SyncStatusView: View {
    @State private var isSignedIn = FileManager.default.ubiquityIdentityToken != nil

    var body: some View {
        Label(
            isSignedIn ? "Syncing with iCloud" : "iCloud unavailable, saved on this Mac",
            systemImage: isSignedIn ? "icloud" : "icloud.slash"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onReceive(NotificationCenter.default.publisher(for: .NSUbiquityIdentityDidChange)) { _ in
            isSignedIn = FileManager.default.ubiquityIdentityToken != nil
        }
    }
}
