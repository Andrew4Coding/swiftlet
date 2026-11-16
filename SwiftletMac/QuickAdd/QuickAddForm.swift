import SwiftData
import SwiftUI

struct QuickAddWindow: View {
    static let id = "quick-add"

    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        QuickAddForm(style: .window) {
            dismissWindow(id: Self.id)
        }
    }
}

struct QuickAddForm: View {
    enum Style {
        case window
        case menuBar
    }

    @Environment(\.modelContext) private var modelContext

    let style: Style
    var onSaved: (() -> Void)?

    @State private var viewModel = AddTransactionViewModel()
    @State private var justSaved = false
    @FocusState private var focusedField: TransactionForm.Field?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TransactionForm(viewModel: viewModel, showsReceipt: style == .window, focusedField: $focusedField)
            }
            .formStyle(.grouped)
            .scrollDisabled(style == .menuBar)

            HStack {
                if justSaved {
                    Label("Added", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.ds(.income))
                        .transition(.opacity)
                } else if let message = viewModel.validationMessage, !viewModel.amountText.isEmpty {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if style == .window {
                    Button("Cancel", role: .cancel) { onSaved?() }
                        .keyboardShortcut(.cancelAction)
                }
                Button("Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.isValid)
            }
            .font(.callout)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: style == .menuBar)
        .onAppear {
            viewModel.assignDefaultWallets(context: modelContext)
            focusedField = .amount
        }
    }

    private func save() {
        guard TransactionSaving.saveNew(viewModel, context: modelContext) else { return }
        let wallet = viewModel.wallet
        let destination = viewModel.destinationWallet
        let type = viewModel.type
        viewModel = AddTransactionViewModel()
        viewModel.type = type
        viewModel.wallet = wallet
        viewModel.destinationWallet = destination
        focusedField = .amount

        if style == .window {
            onSaved?()
            return
        }
        withAnimation { justSaved = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { justSaved = false }
        }
    }
}
