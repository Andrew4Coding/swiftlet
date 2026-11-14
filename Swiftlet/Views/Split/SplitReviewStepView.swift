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
            Section {
                ForEach(Array(viewModel.participants.enumerated()), id: \.element.id) { index, participant in
                    HStack {
                        Text(participant.name)
                        Spacer()
                        Text((viewModel.split.shares[index]).rupiah)
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                    }
                }
                HStack {
                    Text("Bill total").foregroundStyle(.secondary)
                    Spacer()
                    Text(viewModel.billTotal.rupiah).monospacedDigit().foregroundStyle(.secondary)
                }
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
            } footer: {
                Text("Only your share, \(viewModel.myShare.rupiah), counts as spending. The other \((viewModel.billTotal - viewModel.myShare).rupiah) stays owed to you until each person pays.")
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
            .background(.bar)
        }
    }
}
