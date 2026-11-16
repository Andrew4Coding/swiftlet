import SwiftData
import SwiftUI

struct TransactionTable: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    let transactions: [Transaction]
    @Binding var selection: Set<PersistentIdentifier>
    @Binding var sortOrder: [KeyPathComparator<Transaction>]

    @AppStorage("transactionTableColumns") private var columnData = Data()
    @Query(sort: \TransactionCategory.sortIndex) private var categories: [TransactionCategory]
    @Query(sort: [SortDescriptor(\Wallet.sortIndex), SortDescriptor(\Wallet.createdAt)]) private var wallets: [Wallet]

    private var columnCustomization: Binding<TableColumnCustomization<Transaction>> {
        Binding {
            (try? JSONDecoder().decode(TableColumnCustomization<Transaction>.self, from: columnData)) ?? TableColumnCustomization()
        } set: { newValue in
            columnData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var body: some View {
        Table(
            transactions,
            selection: $selection,
            sortOrder: $sortOrder,
            columnCustomization: columnCustomization
        ) {
            TableColumn("Date", value: \.date) { transaction in
                Text(transaction.date, format: .dateTime.day().month(.abbreviated).year())
                    .monospacedDigit()
            }
            .width(min: 90, ideal: 110)
            .customizationID("date")

            TableColumn("Title", value: \.title) { transaction in
                HStack(spacing: 8) {
                    CategoryBadgeView(category: transaction.category, size: 20)
                    Text(transaction.title)
                        .lineLimit(1)
                    if transaction.receiptImageData != nil {
                        Image(systemName: "paperclip")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Has receipt")
                    }
                }
            }
            .width(min: 140, ideal: 240)
            .customizationID("title")

            TableColumn("Category", value: \.categoryName) { transaction in
                Text(transaction.category?.name ?? "—")
                    .foregroundStyle(transaction.category == nil ? .secondary : .primary)
            }
            .width(min: 90, ideal: 130)
            .customizationID("category")

            TableColumn("Wallet", value: \.walletName) { transaction in
                Text(transaction.walletDescription)
                    .lineLimit(1)
            }
            .width(min: 90, ideal: 140)
            .customizationID("wallet")

            TableColumn("Type", value: \.typeRaw) { transaction in
                Text(transaction.type.displayName)
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 80)
            .customizationID("type")

            TableColumn("Note", value: \.transactionDescription) { transaction in
                Text(transaction.transactionDescription)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 80, ideal: 160)
            .customizationID("note")
            .defaultVisibility(.hidden)

            TableColumn("Amount", value: \.amount) { transaction in
                AmountText(transaction: transaction)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 140, ideal: 150)
            .alignment(.trailing)
            .customizationID("amount")
        }
        .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
            contextMenu(for: ids)
        } primaryAction: { ids in
            selection = ids
        }
    }

    @ViewBuilder
    private func contextMenu(for ids: Set<PersistentIdentifier>) -> some View {
        let targets = transactions.filter { ids.contains($0.persistentModelID) }
        if !targets.isEmpty {
            Menu("Category") {
                ForEach(categories) { category in
                    Button("\(category.iconValue) \(category.name)") {
                        BulkTransactionActions.setCategory(category, on: targets, context: modelContext)
                    }
                }
            }
            Menu("Move to Wallet") {
                ForEach(wallets.filter { !$0.isArchived }) { wallet in
                    Button(wallet.name) {
                        BulkTransactionActions.move(targets, to: wallet, context: modelContext)
                    }
                }
            }
            Divider()
            Button(targets.count == 1 ? "Delete Transaction" : "Delete \(targets.count) Transactions", role: .destructive) {
                BulkTransactionActions.delete(targets, context: modelContext)
                selection.subtract(ids)
            }
        }
    }
}

struct AmountText: View {
    let transaction: Transaction

    var body: some View {
        Text(transaction.signedAmountText)
            .monospacedDigit()
            .foregroundStyle(transaction.type.amountColor)
            .accessibilityLabel("\(transaction.type.displayName) \(CurrencyFormatter.rupiah(transaction.amount))")
    }
}
