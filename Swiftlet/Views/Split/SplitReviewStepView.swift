//
//  SplitReviewStepView.swift
//  Swiftlet
//

import SwiftUI

struct SplitReviewStepView: View {
    @Bindable var viewModel: SplitBillViewModel
    let wallets: [Wallet]
    let categories: [TransactionCategory]
    let onSave: () -> Void

    @State private var saveAttempts = 0

    var body: some View {
        List {
            if let data = viewModel.receiptImageData {
                Section {
                    ReceiptPreviewButton(imageData: data)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            Section {
                ForEach(Array(viewModel.participants.enumerated()), id: \.element.id) { index, participant in
                    AmountRow(title: participant.name, value: viewModel.split.shares[index].rupiah, isEmphasized: true)
                }
                AmountRow(title: "Bill total", value: viewModel.billTotal.rupiah, valueColor: .secondary)
            } header: {
                Text(viewModel.resolvedTitle)
            }

            Section {
                Picker("Paid from", selection: $viewModel.wallet) {
                    ForEach(wallets) { wallet in
                        Text(wallet.name).tag(Optional(wallet))
                    }
                }
                Picker("Category", selection: $viewModel.category) {
                    ForEach(categories) { category in
                        Text(category.name).tag(Optional(category))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                if let message = viewModel.validationMessage {
                    Text(message).dsTextStyle(.footnote, color: .warning)
                }
                DSButton("Save split") {
                    saveAttempts += 1
                    onSave()
                }
                .disabled(!viewModel.canSave)
                .sensoryFeedback(.success, trigger: saveAttempts)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.ds(.canvas))
        }
    }
}
