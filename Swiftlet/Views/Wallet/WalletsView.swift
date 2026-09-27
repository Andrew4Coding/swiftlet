//
//  WalletsView.swift
//  Swiftlet
//

import SwiftData
import SwiftUI

struct WalletsView: View {
    @Query(sort: [SortDescriptor(\Wallet.sortIndex), SortDescriptor(\Wallet.createdAt)]) private var wallets: [Wallet]
    @Environment(\.modelContext) private var modelContext

    @State private var editorTarget: WalletEditorTarget?
    @State private var showsArchived = false

    private var active: [Wallet] {
        wallets.filter { !$0.isArchived }
    }

    private var archived: [Wallet] {
        wallets.filter(\.isArchived)
    }

    private var total: Decimal {
        active.reduce(Decimal(0)) { $0 + $1.balance }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Balance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.rupiah(total))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
            }

            Section("Wallets") {
                if active.isEmpty {
                    Button("Add your first wallet", systemImage: "plus") { editorTarget = .new }
                }
                ForEach(active) { wallet in
                    row(for: wallet)
                }
                .onMove(perform: move)
            }

            if !archived.isEmpty {
                Section(isExpanded: $showsArchived) {
                    ForEach(archived) { wallet in
                        row(for: wallet)
                    }
                } header: {
                    Text("Archived")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Wallets")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New Wallet", systemImage: "plus") { editorTarget = .new }
            }
        }
        .sheet(item: $editorTarget) { target in
            WalletEditorView(wallet: target.wallet)
        }
    }

    private func row(for wallet: Wallet) -> some View {
        Button {
            editorTarget = .edit(wallet)
        } label: {
            HStack(spacing: 14) {
                WalletBadgeView(wallet: wallet, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(wallet.name)
                        .font(.body.weight(.medium))
                    Text("\(wallet.transactions?.count ?? 0) transactions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(CurrencyFormatter.rupiah(wallet.balance))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(wallet.balance < 0 ? AppTheme.expense : .primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            if isEmpty(wallet) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    modelContext.delete(wallet)
                    try? modelContext.save()
                }
            }
            Button(wallet.isArchived ? "Unarchive" : "Archive", systemImage: wallet.isArchived ? "tray.and.arrow.up" : "archivebox") {
                wallet.isArchived.toggle()
                try? modelContext.save()
            }
            .tint(.orange)
        }
    }

    /// Wallets with history can only be archived: deleting would orphan their transactions, and
    /// orphaned legacy transactions get re-linked to a recreated wallet by `WalletMigrator`.
    private func isEmpty(_ wallet: Wallet) -> Bool {
        (wallet.transactions ?? []).isEmpty && (wallet.incomingTransfers ?? []).isEmpty
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = active
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, wallet) in reordered.enumerated() where wallet.sortIndex != index {
            wallet.sortIndex = index
        }
        try? modelContext.save()
    }
}

enum WalletEditorTarget: Identifiable {
    case new
    case edit(Wallet)

    var id: String {
        switch self {
        case .new: "new"
        case let .edit(wallet): "\(wallet.persistentModelID.hashValue)"
        }
    }

    var wallet: Wallet? {
        if case let .edit(wallet) = self { wallet } else { nil }
    }
}

#Preview {
    NavigationStack {
        WalletsView()
    }
    .modelContainer(for: [Transaction.self, TransactionCategory.self, Wallet.self], inMemory: true)
}
