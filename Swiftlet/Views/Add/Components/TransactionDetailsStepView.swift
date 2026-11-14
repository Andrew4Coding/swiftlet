//
//  TransactionDetailsStepView.swift
//  Swiftlet
//

import PhotosUI
import SwiftUI

/// Second step of adding a transaction: everything optional, after the amount is settled.
struct TransactionDetailsStepView: View {
    @Bindable var viewModel: AddTransactionViewModel
    @Binding var receiptPhotoItem: PhotosPickerItem?
    let saveAttempts: Int
    let onTakePhoto: () -> Void
    let onViewReceipt: () -> Void
    let onSave: () -> Void

    private var titlePlaceholder: String {
        if viewModel.type == .transfer {
            return "Transfer to \(viewModel.destinationWallet?.name ?? "wallet")"
        }
        return viewModel.selectedCategory?.name ?? "Title"
    }

    var body: some View {
        Form {
            summarySection

            Section {
                TextField(titlePlaceholder, text: $viewModel.title)
                    .submitLabel(.next)
                TextField("Note", text: $viewModel.descriptionText, axis: .vertical)
                    .lineLimit(2 ... 5)
            } header: {
                Text("Title & Note")
            } footer: {
                Text("Optional. Leave the title empty to use \(titlePlaceholder).")
            }

            Section {
                DatePicker("Date", selection: $viewModel.date, displayedComponents: [.date, .hourAndMinute])
            }

            ReceiptPickerSection(
                imageData: $viewModel.receiptImageData,
                photoItem: $receiptPhotoItem,
                onTakePhoto: onTakePhoto,
                onViewReceipt: onViewReceipt
            )

            if let message = viewModel.errorMessage {
                Section {
                    Text(message).foregroundStyle(.ds(.expense))
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            DSButton(viewModel.isEditing ? "Save" : "Add Transaction", action: onSave)
                .sensoryFeedback(.error, trigger: saveAttempts)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summarySection: some View {
        Section {
            HStack(spacing: 12) {
                if viewModel.type == .transfer {
                    DSIconCircle(systemImage: "arrow.left.arrow.right", size: 40)
                } else {
                    CategoryBadgeView(category: viewModel.selectedCategory, size: 40)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(summaryLine)
                        .dsTextStyle(.footnote, color: .textSecondary)
                        .lineLimit(1)
                    DSAmountText(
                        text: CurrencyFormatter.rupiah(viewModel.parsedAmount ?? 0),
                        token: .title,
                        color: viewModel.type == .income ? .income : .textPrimary
                    )
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }

    private var summaryLine: String {
        let from = viewModel.wallet?.name ?? "Wallet"
        switch viewModel.type {
        case .transfer:
            return "\(from) → \(viewModel.destinationWallet?.name ?? "Wallet")"
        case .income:
            return "\(viewModel.selectedCategory?.name ?? "Income") · to \(from)"
        case .expense:
            return "\(viewModel.selectedCategory?.name ?? "Expense") · from \(from)"
        }
    }
}
