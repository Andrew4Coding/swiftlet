import SwiftData
import SwiftUI

struct TransactionInspector: View {
    let transactions: [Transaction]
    let onDelete: () -> Void

    var body: some View {
        switch transactions.count {
        case 0:
            ContentUnavailableView(
                "No selection",
                systemImage: "sidebar.trailing",
                description: Text("Select a transaction to see and edit it. Select several to edit them together.")
            )
        case 1:
            TransactionEditor(transaction: transactions[0], onDelete: onDelete)
                .id(transactions[0].persistentModelID)
        default:
            BulkEditPanel(transactions: transactions, onDelete: onDelete)
        }
    }
}

private struct TransactionEditor: View {
    @Environment(\.modelContext) private var modelContext

    let transaction: Transaction
    let onDelete: () -> Void

    @State private var viewModel: AddTransactionViewModel
    @State private var isConfirmingDelete = false
    @FocusState private var focusedField: TransactionForm.Field?

    init(transaction: Transaction, onDelete: @escaping () -> Void) {
        self.transaction = transaction
        self.onDelete = onDelete
        _viewModel = State(initialValue: AddTransactionViewModel(editing: transaction))
    }

    var body: some View {
        Form {
            TransactionForm(viewModel: viewModel, focusedField: $focusedField)

            if let split = transaction.splitBill {
                Section("Split bill") {
                    LabeledContent("Bill", value: split.title)
                    LabeledContent("Owed to you", value: CurrencyFormatter.rupiah(Decimal(split.outstanding)))
                }
            }

            Section {
                HStack {
                    Button("Delete…", role: .destructive) { isConfirmingDelete = true }
                    Spacer()
                    Button("Revert") {
                        viewModel = AddTransactionViewModel(editing: transaction)
                    }
                    Button("Save") { save() }
                        .keyboardShortcut("s")
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.isValid)
                }
                if let message = viewModel.validationMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Delete this transaction?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("You can undo this with ⌘Z.")
        }
    }

    private func save() {
        modelContext.undoManager?.beginUndoGrouping()
        viewModel.save(context: modelContext)
        modelContext.undoManager?.endUndoGrouping()
        modelContext.undoManager?.setActionName("Edit Transaction")
    }
}

private struct BulkEditPanel: View {
    @Environment(\.modelContext) private var modelContext

    let transactions: [Transaction]
    let onDelete: () -> Void

    @Query(sort: \TransactionCategory.sortIndex) private var categories: [TransactionCategory]
    @Query(sort: [SortDescriptor(\Wallet.sortIndex), SortDescriptor(\Wallet.createdAt)]) private var wallets: [Wallet]

    @State private var isConfirmingDelete = false
    @State private var message: String?

    var body: some View {
        let summary = DashboardSummary(rows: transactions.map(\.filterRow))
        Form {
            Section("\(transactions.count) transactions selected") {
                LabeledContent("Expense", value: CurrencyFormatter.rupiah(Decimal(summary.expense)))
                LabeledContent("Income", value: CurrencyFormatter.rupiah(Decimal(summary.income)))
            }
            .monospacedDigit()

            Section("Change all") {
                Menu("Set Category") {
                    ForEach(categories) { category in
                        Button("\(category.iconValue)  \(category.name)") {
                            let count = BulkTransactionActions.setCategory(category, on: transactions, context: modelContext)
                            report(count, "moved to \(category.name)")
                        }
                    }
                }
                Menu("Move to Wallet") {
                    ForEach(wallets.filter { !$0.isArchived }) { wallet in
                        Button(wallet.name) {
                            let count = BulkTransactionActions.move(transactions, to: wallet, context: modelContext)
                            report(count, "moved to \(wallet.name)")
                        }
                    }
                }
                Button("Delete \(transactions.count) Transactions…", role: .destructive) {
                    isConfirmingDelete = true
                }
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Delete \(transactions.count) transactions?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("You can undo this with ⌘Z.")
        }
    }

    private func report(_ count: Int, _ action: String) {
        let skipped = transactions.count - count
        message = skipped > 0
            ? "\(count) \(action). \(skipped) skipped (transfers or a category that doesn't fit the type)."
            : "\(count) \(action). Undo with ⌘Z."
    }
}
