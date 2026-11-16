import SwiftData
import SwiftUI

struct NewTransactionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let receiptData: Data?

    @State private var viewModel = AddTransactionViewModel()
    @FocusState private var focusedField: TransactionForm.Field?
    @Query(sort: \TransactionCategory.sortIndex) private var categories: [TransactionCategory]

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TransactionForm(viewModel: viewModel, focusedField: $focusedField)
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                if let message = viewModel.validationMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    if TransactionSaving.saveNew(viewModel, context: modelContext) {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.isValid)
            }
            .padding(14)
        }
        .frame(width: 460, height: 620)
        .navigationTitle("New Transaction")
        .task {
            viewModel.assignDefaultWallets(context: modelContext)
            focusedField = .amount
            if let receiptData {
                await ReceiptDetection.attach(receiptData, to: viewModel, categories: categories)
            }
        }
    }
}

enum TransactionSaving {
    @discardableResult
    static func saveNew(_ viewModel: AddTransactionViewModel, context: ModelContext) -> Bool {
        context.undoManager?.beginUndoGrouping()
        let saved = viewModel.save(context: context)
        context.undoManager?.endUndoGrouping()
        context.undoManager?.setActionName("Add Transaction")
        if saved {
            TodaySpendingSnapshotWriter.rebuild(using: context)
        }
        return saved
    }
}
