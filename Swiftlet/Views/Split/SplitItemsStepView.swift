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
            Section {
                TextField("What was it for?", text: $viewModel.title)
                    .textInputAutocapitalization(.sentences)
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
                    HStack {
                        Text("Bill total").font(.body.weight(.semibold))
                        Spacer()
                        Text(viewModel.billTotal.rupiah)
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Review items")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            DSButton("Next", action: onNext)
                .disabled(viewModel.billTotal <= 0)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(.bar)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func itemRow(_ item: Binding<SplitBillViewModel.DraftItem>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Item name", text: item.name)
                .font(.body.weight(.medium))
            HStack {
                Stepper("Qty \(item.wrappedValue.quantity)", value: item.quantity, in: 1 ... 99)
                    .fixedSize()
                Spacer()
                Text("Rp").foregroundStyle(.secondary)
                TextField("0", text: item.priceText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(minWidth: 90, maxWidth: 130)
                    .accessibilityLabel("Price for \(item.wrappedValue.name.isEmpty ? "item" : item.wrappedValue.name)")
            }
            .font(.subheadline)
        }
        .padding(.vertical, 2)
    }

    private func amountField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("Rp").foregroundStyle(.secondary)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(minWidth: 90, maxWidth: 130)
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
