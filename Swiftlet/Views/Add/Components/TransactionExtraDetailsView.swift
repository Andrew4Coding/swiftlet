//
//  TransactionExtraDetailsView.swift
//  Swiftlet
//

import PhotosUI
import SwiftUI

/// Optional fields kept off the main keypad screen so adding a transaction stays amount-first.
struct TransactionExtraDetailsView: View {
    @Bindable var viewModel: AddTransactionViewModel
    @Binding var receiptPhotoItem: PhotosPickerItem?
    let titlePlaceholder: String
    let onTakePhoto: () -> Void
    let onViewReceipt: () -> Void

    var body: some View {
        Form {
            Section {
                TextField(titlePlaceholder, text: $viewModel.title)
                TextField("Note", text: $viewModel.descriptionText, axis: .vertical)
                    .lineLimit(2 ... 5)
            } header: {
                Text("Title & Note")
            } footer: {
                Text("Leave the title empty to use the category name.")
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
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
