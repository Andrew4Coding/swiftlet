//
//  SplitItemsStepView.swift
//  Swiftlet
//

import SwiftUI

struct SplitItemsStepView: View {
    @Bindable var viewModel: SplitBillViewModel
    let onNext: () -> Void

    var body: some View {
        List {
            if let data = viewModel.receiptImageData {
                Section {
                    ReceiptPreviewButton(imageData: data)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } footer: {
                    Text("Check each item against the receipt. Tap the photo to enlarge it.")
                }
            }

            Section {
                TextField("What was it for?", text: $viewModel.title)
                    .textInputAutocapitalization(.sentences)
                    .accessibilityLabel("Bill name")
                DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
            }

            if !viewModel.mismatches.isEmpty {
                Section {
                    ForEach(Array(viewModel.mismatches.enumerated()), id: \.offset) { _, mismatch in
                        Label(message(for: mismatch), systemImage: "exclamationmark.triangle.fill")
                            .dsTextStyle(.subheadline, color: .warning)
                    }
                } header: {
                    Text("Check the numbers")
                } footer: {
                    Text("Fix any item the scan misread. You can still continue.")
                }
            }

            Section {
                ForEach($viewModel.items) { $item in
                    itemRow($item)
                }
                .onDelete { viewModel.removeItems(at: $0) }

                Button("Add item", systemImage: "plus") { viewModel.addItem() }
            } header: {
                Text("Items")
            } footer: {
                if viewModel.items.isEmpty {
                    Text("Add the items to split by what each person had, or just enter the total below.")
                }
            }

            if viewModel.items.isEmpty {
                Section("Total") {
                    amountField("Total", text: $viewModel.manualTotalText)
                }
            } else {
                Section("Extras") {
                    amountField("Service charge", text: $viewModel.serviceText)
                    amountField("Tax", text: $viewModel.taxText)
                    amountField("Discount", text: $viewModel.discountText)
                }

                Section {
                    AmountRow(title: "Bill total", value: viewModel.billTotal.rupiah, isEmphasized: true)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Items")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                if viewModel.billTotal <= 0 {
                    Text("Enter the bill total or add an item to continue")
                        .dsTextStyle(.footnote, color: .textSecondary)
                }
                DSButton("Next", action: onNext)
                    .disabled(viewModel.billTotal <= 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.ds(.canvas))
        }
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
    }

    private func itemRow(_ item: Binding<SplitBillViewModel.DraftItem>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Item name", text: item.name)
                .font(.body.weight(.medium))
            ViewThatFits(in: .horizontal) {
                HStack {
                    quantityStepper(item)
                    Spacer()
                    priceField(item)
                }
                VStack(alignment: .leading, spacing: 8) {
                    quantityStepper(item)
                    HStack {
                        Spacer()
                        priceField(item)
                    }
                }
            }
            .font(.subheadline)
        }
        .padding(.vertical, 2)
    }

    private func quantityStepper(_ item: Binding<SplitBillViewModel.DraftItem>) -> some View {
        Stepper("Qty \(item.wrappedValue.quantity)", value: item.quantity, in: 1 ... 99)
            .fixedSize()
    }

    private func priceField(_ item: Binding<SplitBillViewModel.DraftItem>) -> some View {
        HStack {
            Text("Rp").foregroundStyle(.secondary)
            AmountField(digits: item.priceText)
                .frame(minWidth: 90, maxWidth: 140)
                .accessibilityLabel("Price for \(item.wrappedValue.name.isEmpty ? "item" : item.wrappedValue.name)")
        }
    }

    private func amountField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("Rp").foregroundStyle(.secondary)
            AmountField(digits: text)
                .frame(minWidth: 90, maxWidth: 140)
                .accessibilityLabel(title)
        }
    }

    private func message(for mismatch: ReceiptMismatch) -> String {
        switch mismatch {
        case let .itemsDifferFromSubtotal(difference):
            "Items add up to \(viewModel.itemsTotal.rupiah), but the receipt subtotal is \((viewModel.printedSubtotal ?? 0).rupiah) (\(abs(difference).rupiah) \(difference < 0 ? "short" : "over"))."
        case let .totalDiffers(difference):
            "Subtotal, service, tax and discount come to \(((viewModel.printedTotal ?? 0) + difference).rupiah), but the receipt total is \((viewModel.printedTotal ?? 0).rupiah)."
        }
    }
}
