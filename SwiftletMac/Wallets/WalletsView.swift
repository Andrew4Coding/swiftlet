import SwiftData
import SwiftUI

struct WalletsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Wallet.sortIndex), SortDescriptor(\Wallet.createdAt)]) private var wallets: [Wallet]

    @State private var selection: PersistentIdentifier?
    @State private var editing: WalletEditorTarget?
    @State private var showsArchived = false

    private var shown: [Wallet] {
        wallets.filter { showsArchived || !$0.isArchived }
    }

    var body: some View {
        let total = wallets.filter { !$0.isArchived }.reduce(Decimal(0)) { $0 + $1.balance }
        Table(shown, selection: $selection) {
            TableColumn("Wallet") { wallet in
                HStack(spacing: 8) {
                    IconBadge(iconType: .system, iconValue: wallet.resolvedSymbolName, colorHex: wallet.colorHex, size: 22)
                    Text(wallet.name)
                    if wallet.isArchived {
                        Text("Archived")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            TableColumn("Transactions") { wallet in
                Text("\((wallet.transactions ?? []).count)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(ideal: 100)
            TableColumn("Balance") { wallet in
                Text(CurrencyFormatter.rupiah(wallet.balance))
                    .monospacedDigit()
                    .foregroundStyle(wallet.balance < 0 ? Color.ds(.expense) : .primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(ideal: 160)
        }
        .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
            if let wallet = wallets.first(where: { ids.contains($0.persistentModelID) }) {
                Button("Edit…") { editing = .edit(wallet) }
                Button("Show Transactions") { showTransactions(wallet) }
                Button(wallet.isArchived ? "Unarchive" : "Archive") {
                    wallet.isArchived.toggle()
                    try? modelContext.save()
                }
            }
        } primaryAction: { ids in
            if let wallet = wallets.first(where: { ids.contains($0.persistentModelID) }) {
                showTransactions(wallet)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Toggle("Show archived", isOn: $showsArchived)
                Spacer()
                Text("Total \(CurrencyFormatter.rupiah(total))")
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .navigationTitle("Wallets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editing = .new } label: { Label("New Wallet", systemImage: "plus") }
                    .help("New Wallet")
            }
        }
        .sheet(item: $editing) { target in
            WalletEditor(target: target)
        }
    }

    private func showTransactions(_ wallet: Wallet) {
        var filter = TransactionFilter()
        filter.walletNames = [wallet.name]
        appState.showTransactions(matching: filter)
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
}

private struct WalletEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var wallets: [Wallet]

    let target: WalletEditorTarget

    @State private var name = ""
    @State private var symbolName = Wallet.defaultSymbolName
    @State private var colorHex = AppTheme.palette[5]
    @State private var initialBalance = ""
    @State private var isArchived = false
    @State private var isConfirmingDelete = false

    private var wallet: Wallet? {
        if case let .edit(wallet) = target { wallet } else { nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Name", text: $name)
                TextField("Starting balance", text: $initialBalance, prompt: Text("Rp 0"))
                    .monospacedDigit()
                Picker("Icon", selection: $symbolName) {
                    ForEach(Wallet.symbolChoices, id: \.self) { symbol in
                        Label(symbol, systemImage: symbol).labelStyle(.iconOnly).tag(symbol)
                    }
                }
                ColorSwatchPicker(selection: $colorHex)
                if wallet != nil {
                    Toggle("Archived", isOn: $isArchived)
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                if wallet != nil {
                    Button("Delete…", role: .destructive) { isConfirmingDelete = true }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(wallet == nil ? "Add" : "Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(14)
        }
        .frame(width: 420)
        .onAppear(perform: load)
        .confirmationDialog("Delete \(wallet?.name ?? "wallet")?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                if let wallet {
                    modelContext.delete(wallet)
                    try? modelContext.save()
                }
                dismiss()
            }
        } message: {
            Text("Its transactions stay, without a wallet. Archive it instead to keep its history.")
        }
    }

    private func load() {
        guard let wallet else { return }
        name = wallet.name
        symbolName = wallet.resolvedSymbolName
        colorHex = wallet.colorHex
        initialBalance = CurrencyFormatter.plainAmount(wallet.initialBalance)
        isArchived = wallet.isArchived
    }

    private func save() {
        let target = wallet ?? {
            let created = Wallet(name: "", sortIndex: (wallets.map(\.sortIndex).max() ?? -1) + 1)
            modelContext.insert(created)
            return created
        }()
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.symbolName = symbolName
        target.colorHex = colorHex
        target.initialBalance = CurrencyFormatter.parse(initialBalance) ?? 0
        target.isArchived = isArchived
        try? modelContext.save()
        dismiss()
    }
}

struct ColorSwatchPicker: View {
    @Binding var selection: String

    var body: some View {
        LabeledContent("Colour") {
            HStack(spacing: 6) {
                ForEach(AppTheme.palette, id: \.self) { hex in
                    Button {
                        selection = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 20, height: 20)
                            .overlay {
                                if selection.caseInsensitiveCompare(hex) == .orderedSame {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(ContrastColor.foreground(onHex: hex))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Colour \(hex)")
                    .accessibilityAddTraits(selection == hex ? .isSelected : [])
                }
            }
        }
    }
}
